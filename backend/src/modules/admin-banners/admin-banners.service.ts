import { randomUUID } from 'node:crypto';
import { type Readable } from 'node:stream';
import { Inject, Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type QueryFilter, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { dayRange, escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { FILE_STORAGE, type FileStorage } from '../files/storage/file-storage';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import {
  type Banner,
  BANNER_MODEL,
  BANNER_LANGUAGES,
  type BannerImageVariant,
  type BannerLanguage,
  type BannerListQueryDto,
  type BannerPlacement,
  bannerImageUrlOf,
  type BannerView,
  bannerRuleIssues,
  bannerStatusOf,
  type CreateBannerDto,
  type PublicBannerView,
  detectImageType,
  IMAGE_EXTENSIONS,
  IMAGE_FIELDS,
  statusCondition,
  storedKeysOf,
  type StoredBanner,
  type UpdateBannerDto,
} from './admin-banners.model';

/** Largest image accepted (also the multipart limit of the upload endpoint). */
export const BANNER_IMAGE_MAX_BYTES = 3 * 1024 * 1024;

/** Most banners the customer app is given for one placement. */
const PUBLIC_LIMIT = 10;

export function bannerViewOf(banner: StoredBanner, now: Date = new Date()): BannerView {
  return {
    id: banner._id.toHexString(),
    title: banner.title,
    subtitle: banner.subtitle,
    buttonText: banner.buttonText,
    linkType: banner.linkType,
    linkValue: banner.linkValue,
    placement: banner.placement,
    language: banner.language,
    startsAt: banner.startsAt?.toISOString() ?? null,
    endsAt: banner.endsAt?.toISOString() ?? null,
    sortOrder: banner.sortOrder,
    isActive: banner.isActive,
    status: bannerStatusOf(banner, now),
    imageUrl: bannerImageUrlOf(banner),
    externalImageUrl: banner.externalImageUrl,
    desktopImageUrl: bannerImageUrlOf(banner, 'desktop'),
    externalDesktopImageUrl: banner.externalDesktopImageUrl ?? null,
    createdAt: banner.createdAt?.toISOString() ?? null,
    updatedAt: banner.updatedAt?.toISOString() ?? null,
  };
}

function publicBannerViewOf(banner: StoredBanner): PublicBannerView {
  return {
    id: banner._id.toHexString(),
    title: banner.title,
    subtitle: banner.subtitle,
    buttonText: banner.buttonText,
    linkType: banner.linkType,
    linkValue: banner.linkValue,
    imageUrl: bannerImageUrlOf(banner),
    desktopImageUrl: bannerImageUrlOf(banner, 'desktop'),
  };
}

const EDITABLE_FIELDS = [
  'title',
  'subtitle',
  'buttonText',
  'linkType',
  'linkValue',
  'placement',
  'language',
  'externalImageUrl',
  'externalDesktopImageUrl',
  'startsAt',
  'endsAt',
  'sortOrder',
  'isActive',
] as const;

/** The uploaded file as the multipart parser hands it over. */
export interface IncomingBannerImage {
  size: number;
  buffer: Buffer;
}

/**
 * Banners shown at the top of the customer app. Platform staff manage them (with their images);
 * customers read the live ones. Whether a banner is live is decided by its dates when it is read.
 */
@Injectable()
export class AdminBannersService {
  constructor(
    @InjectModel(BANNER_MODEL) private readonly banners: Model<Banner>,
    private readonly changes: AuditedChangeRunner,
    @Inject(FILE_STORAGE) private readonly storage: FileStorage,
  ) {}

  async list(query: BannerListQueryDto): Promise<PaginatedResult<BannerView>> {
    const now = new Date();
    const conditions: QueryFilter<Banner>[] = [];
    if (query.search) {
      const pattern = new RegExp(escapeRegExp(query.search), 'i');
      conditions.push({ $or: [{ title: pattern }, { subtitle: pattern }] });
    }
    if (query.status) conditions.push(statusCondition(query.status, now));
    if (query.placement) conditions.push({ placement: query.placement });
    if (query.language) conditions.push({ language: query.language });
    const created = dayRange(query);
    if (created) conditions.push({ createdAt: created });
    const match: QueryFilter<Banner> = conditions.length > 0 ? { $and: conditions } : {};

    const [items, total] = await Promise.all([
      this.banners
        .find(match)
        .sort({ placement: 1, sortOrder: 1, createdAt: -1, _id: -1 })
        .skip(skipOf(query))
        .limit(query.pageSize)
        .lean<StoredBanner[]>()
        .exec(),
      this.banners.countDocuments(match).exec(),
    ]);
    return new PaginatedResult(
      items.map((banner) => bannerViewOf(banner, now)),
      query.page,
      query.pageSize,
      total,
    );
  }

  async get(id: string): Promise<BannerView> {
    return bannerViewOf(await this.require(id));
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateBannerDto,
    client: ClientRequestInfo,
  ): Promise<BannerView> {
    const created = await this.changes.run({
      actor,
      client,
      action: 'banner.created',
      entityType: 'banner',
      before: {},
      apply: async (session) => {
        const [banner] = await this.banners.create(
          [
            {
              ...input,
              imageKey: null,
              imageMimeType: null,
              imageUpdatedAt: null,
              desktopImageKey: null,
              desktopImageMimeType: null,
              desktopImageUpdatedAt: null,
            },
          ],
          { session },
        );
        if (!banner) throw new Error('Banner was not created');
        return banner.toObject();
      },
      describe: (record) => ({ ...bannerViewOf(record) }),
    });
    return bannerViewOf(created);
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    change: UpdateBannerDto,
    client: ClientRequestInfo,
  ): Promise<BannerView> {
    const before = await this.require(id);
    const set: Partial<Banner> = {};
    for (const field of EDITABLE_FIELDS) {
      if (change[field] !== undefined) Object.assign(set, { [field]: change[field] });
    }
    if (Object.keys(set).length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }
    // Switching to "links nowhere" clears the old target instead of refusing the change
    if (set.linkType === 'NONE' && set.linkValue === undefined) set.linkValue = '';

    const merged = { ...before, ...set };
    const issues = bannerRuleIssues(merged);
    if (issues.length > 0) {
      throw new ApiException('VALIDATION_FAILED', 'Request validation failed', {
        location: 'body',
        issues: issues.map((issue) => ({ ...issue, code: 'custom' })),
      });
    }
    const onlyStatus = Object.keys(set).length === 1 && set.isActive !== undefined;
    return this.save(
      actor,
      before,
      set,
      onlyStatus ? 'banner.status-changed' : 'banner.updated',
      client,
    );
  }

  setActive(
    actor: AuthenticatedUserActor,
    id: string,
    active: boolean,
    client: ClientRequestInfo,
    reason?: string,
  ): Promise<BannerView> {
    return this.require(id).then((before) =>
      this.save(actor, before, { isActive: active }, 'banner.status-changed', client, reason),
    );
  }

  /**
   * Stores a new image and points the banner at it. The previous image is removed only once the
   * banner refers to the new one; if saving the banner fails, the new image is removed instead.
   */
  async uploadImage(
    actor: AuthenticatedUserActor,
    id: string,
    variant: BannerImageVariant,
    file: IncomingBannerImage | undefined,
    client: ClientRequestInfo,
  ): Promise<BannerView> {
    if (!file) {
      throw new ApiException('VALIDATION_FAILED', 'Attach the image in the "file" field.');
    }
    if (file.size === 0) throw new ApiException('VALIDATION_FAILED', 'The file is empty.');
    if (file.size > BANNER_IMAGE_MAX_BYTES) {
      throw new ApiException('PAYLOAD_TOO_LARGE', 'Banner images can be at most 3 MB.');
    }
    const mimeType = detectImageType(file.buffer);
    if (!mimeType) {
      throw new ApiException('UNSUPPORTED_MEDIA_TYPE', 'Banner images must be JPG, PNG or WebP.');
    }
    const before = await this.require(id);

    const fields = IMAGE_FIELDS[variant];
    const imageKey = `banners/${randomUUID()}.${IMAGE_EXTENSIONS[mimeType]}`;
    await this.storage.put(imageKey, file.buffer, mimeType);
    let saved: BannerView;
    try {
      saved = await this.save(
        actor,
        before,
        {
          [fields.key]: imageKey,
          [fields.mimeType]: mimeType,
          [fields.updatedAt]: new Date(),
          [fields.external]: null,
        },
        'banner.image-changed',
        client,
        undefined,
        { imageVariant: variant },
      );
    } catch (error) {
      await this.storage.remove(imageKey);
      throw error;
    }
    const previousKey = before[fields.key];
    if (previousKey) await this.removeQuietly(previousKey);
    return saved;
  }

  /**
   * Removes the stored image of one variant (an external address is kept). Removing an image the
   * banner does not have changes nothing.
   */
  async removeImage(
    actor: AuthenticatedUserActor,
    id: string,
    variant: BannerImageVariant,
    client: ClientRequestInfo,
  ): Promise<BannerView> {
    const before = await this.require(id);
    const fields = IMAGE_FIELDS[variant];
    const storedKey = before[fields.key];
    if (!storedKey) return bannerViewOf(before);
    const saved = await this.save(
      actor,
      before,
      { [fields.key]: null, [fields.mimeType]: null, [fields.updatedAt]: null },
      'banner.image-changed',
      client,
      undefined,
      { imageVariant: variant, imageRemoved: true },
    );
    await this.removeQuietly(storedKey);
    return saved;
  }

  async remove(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<void> {
    const before = await this.require(id);
    await this.changes.run({
      actor,
      client,
      action: 'banner.deleted',
      entityType: 'banner',
      before: { ...bannerViewOf(before) },
      apply: async (session: ClientSession) => {
        const deleted = await this.banners
          .findOneAndDelete({ _id: before._id }, { session })
          .lean<StoredBanner>()
          .exec();
        if (!deleted) throw new ApiException('RESOURCE_NOT_FOUND', 'Banner not found');
        return deleted;
      },
      describe: () => ({}),
    });
    for (const key of storedKeysOf(before)) await this.removeQuietly(key);
  }

  /** Live banners of a placement in the customer's language (or for every language). */
  async live(
    placement: BannerPlacement,
    language: string | undefined,
  ): Promise<PublicBannerView[]> {
    const languages: BannerLanguage[] = ['ALL'];
    const chosen = BANNER_LANGUAGES.find((known) => known === language);
    if (chosen && chosen !== 'ALL') languages.push(chosen);
    const items = await this.banners
      .find({
        placement,
        language: { $in: languages },
        ...statusCondition('LIVE', new Date()),
      })
      .sort({ sortOrder: 1, createdAt: -1, _id: -1 })
      .limit(PUBLIC_LIMIT)
      .lean<StoredBanner[]>()
      .exec();
    return items.map(publicBannerViewOf);
  }

  /** The stored image of an existing banner, whatever its status (staff preview them). */
  async openImage(
    id: string,
    variant: BannerImageVariant,
  ): Promise<{ content: Readable; mimeType: string }> {
    const banner = await this.find(id);
    const fields = IMAGE_FIELDS[variant];
    const key = banner?.[fields.key];
    if (!banner || !key) throw new ApiException('RESOURCE_NOT_FOUND', 'Banner image not found');
    try {
      return {
        content: await this.storage.open(key),
        mimeType: banner[fields.mimeType] ?? 'application/octet-stream',
      };
    } catch {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Banner image not found');
    }
  }

  private find(id: string): Promise<StoredBanner | null> {
    if (!Types.ObjectId.isValid(id)) return Promise.resolve(null);
    return this.banners.findById(id).lean<StoredBanner>().exec();
  }

  private async require(id: string): Promise<StoredBanner> {
    const banner = await this.find(id);
    if (!banner) throw new ApiException('RESOURCE_NOT_FOUND', 'Banner not found');
    return banner;
  }

  private async save(
    actor: AuthenticatedUserActor,
    before: StoredBanner,
    set: Partial<Banner>,
    action: 'banner.updated' | 'banner.status-changed' | 'banner.image-changed',
    client: ClientRequestInfo,
    reason?: string,
    auditDetails: Record<string, unknown> = {},
  ): Promise<BannerView> {
    const updated = await this.changes.run({
      actor,
      client,
      action,
      entityType: 'banner',
      before: { ...bannerViewOf(before) },
      reason,
      apply: async (session) => {
        const saved = await this.banners
          .findOneAndUpdate(
            { _id: before._id },
            { $set: set },
            { returnDocument: 'after', session, runValidators: true },
          )
          .lean<StoredBanner>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Banner not found');
        return saved;
      },
      describe: (record) => ({ ...bannerViewOf(record), ...auditDetails }),
    });
    return bannerViewOf(updated);
  }

  /** The record no longer points at the key; a failed removal only leaves an orphaned file. */
  private async removeQuietly(key: string): Promise<void> {
    try {
      await this.storage.remove(key);
    } catch {
      // nothing refers to the bytes any more
    }
  }
}
