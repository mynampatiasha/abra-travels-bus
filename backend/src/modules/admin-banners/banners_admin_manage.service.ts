import { randomUUID } from 'node:crypto';
import { Inject, Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { FILE_STORAGE, type FileStorage } from '../files/storage/file-storage';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import {
  type Banner,
  BANNER_MODEL,
  IMAGE_EXTENSIONS,
  IMAGE_FIELDS,
  type BannerImageVariant,
  type BannerView,
  type StoredBanner,
} from './admin-banners.model';
import { bannerViewOf } from './admin-banners.service';

/** The banners of one placement in the order the customer app shows them. */
export interface BannerOrderEntry {
  id: string;
  sortOrder: number;
}

/** Gap between sort orders after a reorder, so a banner can be slotted in later by hand. */
const ORDER_STEP = 10;

/** `(copy)` is added to the title; the title stays within its 80 characters. */
export function copyTitleOf(title: string): string {
  const suffix = ' (copy)';
  return `${title.slice(0, 80 - suffix.length)}${suffix}`;
}

/**
 * The banners in the working list of one placement, as a new order after moving `id` one place:
 * `up` shows it earlier. Returns null when it cannot move (already first or last, or unknown).
 */
export function movedOrder(
  ids: readonly string[],
  id: string,
  direction: 'up' | 'down',
): string[] | null {
  const from = ids.indexOf(id);
  const to = direction === 'up' ? from - 1 : from + 1;
  if (from < 0 || to < 0 || to >= ids.length) return null;
  const next = [...ids];
  next.splice(from, 1);
  next.splice(to, 0, id);
  return next;
}

/**
 * Banner actions beyond create / edit / publish: duplicate, archive and put back, and move up or
 * down. Every change is audited with the banner's state before and after.
 */
@Injectable()
export class BannersManageService {
  constructor(
    @InjectModel(BANNER_MODEL) private readonly banners: Model<Banner>,
    private readonly changes: AuditedChangeRunner,
    @Inject(FILE_STORAGE) private readonly storage: FileStorage,
  ) {}

  /** A draft copy of a banner, with its own copy of the stored images. */
  async duplicate(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<BannerView> {
    const source = await this.require(id);
    const copiedKeys: string[] = [];
    try {
      const images = await this.copyImages(source, copiedKeys);
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
                title: copyTitleOf(source.title),
                subtitle: source.subtitle,
                buttonText: source.buttonText,
                linkType: source.linkType,
                linkValue: source.linkValue,
                placement: source.placement,
                language: source.language,
                externalImageUrl: source.externalImageUrl,
                externalDesktopImageUrl: source.externalDesktopImageUrl,
                startsAt: source.startsAt,
                endsAt: source.endsAt,
                sortOrder: source.sortOrder,
                isActive: false,
                archivedAt: null,
                ...images,
              },
            ],
            { session },
          );
          if (!banner) throw new Error('Banner was not created');
          return banner.toObject();
        },
        describe: (record) => ({ ...bannerViewOf(record), duplicatedFrom: id }),
      });
      return bannerViewOf(created);
    } catch (error) {
      for (const key of copiedKeys) await this.removeQuietly(key);
      throw error;
    }
  }

  /** Puts a banner away: never shown, out of the working list, kept for the record. */
  archive(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
    reason?: string,
  ): Promise<BannerView> {
    return this.setArchived(actor, id, true, client, reason);
  }

  /** Brings an archived banner back as a draft (it is not published again by itself). */
  unarchive(
    actor: AuthenticatedUserActor,
    id: string,
    client: ClientRequestInfo,
  ): Promise<BannerView> {
    return this.setArchived(actor, id, false, client);
  }

  /**
   * Moves a banner one place earlier or later among the banners of its placement that are not
   * archived. Sort orders are rewritten with a step of 10; only banners whose value changes are
   * written, all in one transaction with one audit entry.
   */
  async move(
    actor: AuthenticatedUserActor,
    id: string,
    direction: 'up' | 'down',
    client: ClientRequestInfo,
  ): Promise<BannerOrderEntry[]> {
    const moved = await this.require(id);
    const ordered = await this.workingList(moved.placement);
    const ids = ordered.map((banner) => banner._id.toHexString());
    const next = movedOrder(ids, id, direction);
    if (!next) return ordered.map(orderEntryOf);

    const sortOrderOf = new Map(
      ordered.map((banner) => [banner._id.toHexString(), banner.sortOrder]),
    );
    const writes = next.flatMap((bannerId, index) => {
      const sortOrder = (index + 1) * ORDER_STEP;
      return sortOrderOf.get(bannerId) === sortOrder
        ? []
        : [
            {
              updateOne: {
                filter: { _id: new Types.ObjectId(bannerId) },
                update: { $set: { sortOrder } },
              },
            },
          ];
    });

    await this.changes.run({
      actor,
      client,
      action: 'banner.updated',
      entityType: 'banner',
      before: { placement: moved.placement, order: ids },
      apply: async (session) => {
        if (writes.length > 0) await this.banners.bulkWrite(writes, { session });
        return moved;
      },
      describe: () => ({ placement: moved.placement, order: next, moved: id, direction }),
    });
    return (await this.workingList(moved.placement)).map(orderEntryOf);
  }

  private async setArchived(
    actor: AuthenticatedUserActor,
    id: string,
    archived: boolean,
    client: ClientRequestInfo,
    reason?: string,
  ): Promise<BannerView> {
    const before = await this.require(id);
    if (Boolean(before.archivedAt) === archived) return bannerViewOf(before);
    const set: Partial<Banner> = archived
      ? { archivedAt: new Date(), isActive: false }
      : { archivedAt: null };
    const updated = await this.changes.run({
      actor,
      client,
      action: 'banner.status-changed',
      entityType: 'banner',
      before: { ...bannerViewOf(before) },
      reason,
      apply: async (session) => {
        const saved = await this.banners
          .findOneAndUpdate(
            { _id: before._id },
            { $set: set },
            { returnDocument: 'after', session },
          )
          .lean<StoredBanner>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Banner not found');
        return saved;
      },
      describe: (record) => ({ ...bannerViewOf(record), archived }),
    });
    return bannerViewOf(updated);
  }

  /** Not archived, not deleted, in the order the customer app shows them. */
  private workingList(placement: Banner['placement']): Promise<StoredBanner[]> {
    return this.banners
      .find({ placement, archivedAt: null })
      .sort({ sortOrder: 1, createdAt: -1, _id: -1 })
      .lean<StoredBanner[]>()
      .exec();
  }

  private async require(id: string): Promise<StoredBanner> {
    const banner = Types.ObjectId.isValid(id)
      ? await this.banners.findById(id).lean<StoredBanner>().exec()
      : null;
    if (!banner) throw new ApiException('RESOURCE_NOT_FOUND', 'Banner not found');
    return banner;
  }

  /** Copies every stored image to a key of its own; `copiedKeys` lets the caller clean up. */
  private async copyImages(source: StoredBanner, copiedKeys: string[]): Promise<Partial<Banner>> {
    const copied: Partial<Banner> = {};
    for (const variant of ['mobile', 'desktop'] as const satisfies readonly BannerImageVariant[]) {
      const fields = IMAGE_FIELDS[variant];
      const key = source[fields.key];
      const mimeType = source[fields.mimeType];
      if (!key || !mimeType) continue;
      const extension = IMAGE_EXTENSIONS[mimeType as keyof typeof IMAGE_EXTENSIONS];
      const newKey = `banners/${randomUUID()}.${extension ?? 'bin'}`;
      const chunks: Buffer[] = [];
      const stream = (await this.storage.open(key)) as AsyncIterable<Buffer>;
      for await (const chunk of stream) chunks.push(chunk);
      await this.storage.put(newKey, Buffer.concat(chunks), mimeType);
      copiedKeys.push(newKey);
      Object.assign(copied, {
        [fields.key]: newKey,
        [fields.mimeType]: mimeType,
        [fields.updatedAt]: new Date(),
      });
    }
    return copied;
  }

  private async removeQuietly(key: string): Promise<void> {
    try {
      await this.storage.remove(key);
    } catch {
      // only an orphaned file is left
    }
  }
}

function orderEntryOf(banner: StoredBanner): BannerOrderEntry {
  return { id: banner._id.toHexString(), sortOrder: banner.sortOrder };
}
