import { type QueryFilter, Schema, type Types } from 'mongoose';
import { z } from 'zod';
import { dateRangeShape, objectIdString, pagingShape } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { detectMimeType } from '../files/storage/file-signature';
import { definePermissions, PLATFORM_ONLY } from '../rbac/permissions/permission-definition';

export const BANNER_MODEL = 'Banner';

/** What happens when a customer taps the banner. */
export const BANNER_LINK_TYPES = ['NONE', 'OFFER', 'ROUTE_SEARCH', 'SCREEN', 'URL'] as const;
export type BannerLinkType = (typeof BANNER_LINK_TYPES)[number];

/** Where in the customer app the banner is shown. */
export const BANNER_PLACEMENTS = ['HOME_TOP', 'OFFERS'] as const;
export type BannerPlacement = (typeof BANNER_PLACEMENTS)[number];

/** `ALL` shows the banner whatever the customer's language; otherwise only in that language. */
export const BANNER_LANGUAGES = ['ALL', 'en', 'hi', 'te', 'kn', 'ta', 'ml', 'mr', 'bn'] as const;
export type BannerLanguage = (typeof BANNER_LANGUAGES)[number];

/**
 * Not stored: worked out from `isActive` and the dates at the moment of reading, so a banner
 * goes live and expires on time without a background job.
 */
export const BANNER_STATUSES = ['LIVE', 'SCHEDULED', 'EXPIRED', 'INACTIVE'] as const;
export type BannerStatus = (typeof BANNER_STATUSES)[number];

/** `mobile` is the main image, used everywhere; `desktop` is an optional wider one. */
export const BANNER_IMAGE_VARIANTS = ['mobile', 'desktop'] as const;
export type BannerImageVariant = (typeof BANNER_IMAGE_VARIANTS)[number];

export const BANNER_PERMISSIONS = definePermissions('banners', {
  manage: {
    name: 'Manage banners',
    description:
      'Open the banners page; add, edit, enable/disable, upload images, export and import banners.',
    grantableTo: PLATFORM_ONLY,
  },
  delete: {
    name: 'Delete banners',
    description: 'Permanently delete banners.',
    grantableTo: PLATFORM_ONLY,
    sensitive: true,
  },
});

/** A promotional banner shown at the top of the customer app, managed by platform staff. */
export interface Banner {
  title: string;
  subtitle: string;
  /** Label of the call-to-action button; empty means no button. */
  buttonText: string;
  linkType: BannerLinkType;
  /**
   * Target of the tap, by link type: OFFER an offer id or code, ROUTE_SEARCH
   * `fromCityId:toCityId`, SCREEN an app route name, URL an https address, NONE empty.
   */
  linkValue: string;
  placement: BannerPlacement;
  language: BannerLanguage;
  /** Key in file storage of an uploaded image (`banners/<uuid>.<ext>`). */
  imageKey: string | null;
  imageMimeType: string | null;
  /** Changes with every upload, so image addresses change and caches never serve an old one. */
  imageUpdatedAt: Date | null;
  /** An image hosted elsewhere (CSV import). Replaced by an upload. */
  externalImageUrl: string | null;
  /** Optional wider image for tablets and desktops; same rules as the main (mobile) image. */
  desktopImageKey: string | null;
  desktopImageMimeType: string | null;
  desktopImageUpdatedAt: Date | null;
  externalDesktopImageUrl: string | null;
  startsAt: Date | null;
  endsAt: Date | null;
  sortOrder: number;
  isActive: boolean;
  createdAt?: Date;
  updatedAt?: Date;
}

export type StoredBanner = Banner & { _id: Types.ObjectId };

/** `banners`. */
export const bannerSchema = new Schema<Banner>(
  {
    title: { type: String, required: true, trim: true, minlength: 2, maxlength: 80 },
    subtitle: { type: String, trim: true, maxlength: 160, default: '' },
    buttonText: { type: String, trim: true, maxlength: 24, default: '' },
    linkType: { type: String, enum: BANNER_LINK_TYPES, required: true, default: 'NONE' },
    linkValue: { type: String, trim: true, maxlength: 300, default: '' },
    placement: { type: String, enum: BANNER_PLACEMENTS, required: true, default: 'HOME_TOP' },
    language: { type: String, enum: BANNER_LANGUAGES, required: true, default: 'ALL' },
    imageKey: { type: String, default: null },
    imageMimeType: { type: String, default: null },
    imageUpdatedAt: { type: Date, default: null },
    externalImageUrl: { type: String, maxlength: 500, default: null },
    desktopImageKey: { type: String, default: null },
    desktopImageMimeType: { type: String, default: null },
    desktopImageUpdatedAt: { type: Date, default: null },
    externalDesktopImageUrl: { type: String, maxlength: 500, default: null },
    startsAt: { type: Date, default: null },
    endsAt: { type: Date, default: null },
    sortOrder: { type: Number, required: true, min: 0, max: 100_000, default: 0 },
    isActive: { type: Boolean, required: true, default: true },
  },
  { collection: 'banners', timestamps: true, versionKey: false },
);

bannerSchema.index({ placement: 1, isActive: 1, sortOrder: 1 });
bannerSchema.index({ startsAt: 1, endsAt: 1 });
bannerSchema.index({ createdAt: -1 });

/** The status of a banner at `now`. */
export function bannerStatusOf(
  banner: Pick<Banner, 'isActive' | 'startsAt' | 'endsAt'>,
  now: Date = new Date(),
): BannerStatus {
  if (!banner.isActive) return 'INACTIVE';
  if (banner.startsAt && banner.startsAt > now) return 'SCHEDULED';
  if (banner.endsAt && banner.endsAt < now) return 'EXPIRED';
  return 'LIVE';
}

export function isHttpsUrl(value: string): boolean {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && url.hostname.length > 0;
  } catch {
    return false;
  }
}

const OBJECT_ID = /^[0-9a-f]{24}$/i;

/**
 * Problems with the link and the dates of a banner, checked together because each depends on
 * another field. Used on creation (by the DTO) and on an edit (by the service, on the merged
 * result), so a partial update cannot leave an inconsistent banner.
 */
export function bannerRuleIssues(banner: {
  linkType: BannerLinkType;
  linkValue: string;
  startsAt: Date | null;
  endsAt: Date | null;
}): Array<{ path: string; message: string }> {
  const issues: Array<{ path: string; message: string }> = [];
  const value = banner.linkValue;
  const link = (message: string) => issues.push({ path: 'linkValue', message });
  switch (banner.linkType) {
    case 'NONE':
      if (value !== '') link('must be empty when the banner links nowhere');
      break;
    case 'OFFER':
      if (!/^[A-Za-z0-9_-]{1,64}$/.test(value)) link('must be an offer id or code');
      break;
    case 'ROUTE_SEARCH': {
      const [from, to, extra] = value.split(':');
      if (extra !== undefined || !from || !to || !OBJECT_ID.test(from) || !OBJECT_ID.test(to)) {
        link('must be "fromCityId:toCityId"');
      } else if (from.toLowerCase() === to.toLowerCase()) {
        link('the two cities must be different');
      }
      break;
    }
    case 'SCREEN':
      if (!/^\/?[A-Za-z][A-Za-z0-9_\-/]{0,99}$/.test(value)) link('must be an app screen name');
      break;
    case 'URL':
      if (!isHttpsUrl(value)) link('must be an https:// address');
      break;
  }
  if (banner.startsAt && banner.endsAt && banner.endsAt <= banner.startsAt) {
    issues.push({ path: 'endsAt', message: 'must be after startsAt' });
  }
  return issues;
}

const isoDate = z.iso
  .datetime({ offset: true })
  .transform((value) => new Date(value))
  .nullable();
const httpsUrl = z
  .string()
  .trim()
  .max(500)
  .refine(isHttpsUrl, { message: 'must be an https:// address' })
  .nullable();

/** Optional text: `null` clears it (stored as an empty string). */
function clearableText(max: number) {
  return z
    .string()
    .trim()
    .max(max)
    .nullable()
    .transform((value) => value ?? '');
}

const fields = {
  title: z.string().trim().min(2).max(80),
  subtitle: clearableText(160),
  buttonText: clearableText(24),
  linkType: z.enum(BANNER_LINK_TYPES),
  linkValue: clearableText(300),
  placement: z.enum(BANNER_PLACEMENTS),
  language: z.enum(BANNER_LANGUAGES),
  externalImageUrl: httpsUrl,
  externalDesktopImageUrl: httpsUrl,
  startsAt: isoDate,
  endsAt: isoDate,
  sortOrder: z.number().int().min(0).max(100_000),
  isActive: z.boolean(),
};

export class CreateBannerDto extends createZodDto(
  z
    .object({
      title: fields.title,
      subtitle: fields.subtitle.default(''),
      buttonText: fields.buttonText.default(''),
      linkType: fields.linkType.default('NONE'),
      linkValue: fields.linkValue.default(''),
      placement: fields.placement.default('HOME_TOP'),
      language: fields.language.default('ALL'),
      externalImageUrl: fields.externalImageUrl.default(null),
      externalDesktopImageUrl: fields.externalDesktopImageUrl.default(null),
      startsAt: fields.startsAt.default(null),
      endsAt: fields.endsAt.default(null),
      sortOrder: fields.sortOrder.default(0),
      isActive: fields.isActive.default(true),
    })
    .superRefine((banner, context) => {
      for (const issue of bannerRuleIssues(banner)) {
        context.addIssue({ code: 'custom', path: [issue.path], message: issue.message });
      }
    }),
) {}

/** Only the fields sent change; link and dates are checked again on the merged banner. */
export class UpdateBannerDto extends createZodDto(
  z.object({
    title: fields.title.optional(),
    subtitle: fields.subtitle.optional(),
    buttonText: fields.buttonText.optional(),
    linkType: fields.linkType.optional(),
    linkValue: fields.linkValue.optional(),
    placement: fields.placement.optional(),
    language: fields.language.optional(),
    externalImageUrl: fields.externalImageUrl.optional(),
    externalDesktopImageUrl: fields.externalDesktopImageUrl.optional(),
    startsAt: fields.startsAt.optional(),
    endsAt: fields.endsAt.optional(),
    sortOrder: fields.sortOrder.optional(),
    isActive: fields.isActive.optional(),
  }),
) {}

export class BannerListQueryDto extends createZodDto(
  z.object({
    /** Part of the title or subtitle. */
    search: z.string().trim().min(1).max(80).optional(),
    status: z.enum(BANNER_STATUSES).optional(),
    placement: z.enum(BANNER_PLACEMENTS).optional(),
    language: z.enum(BANNER_LANGUAGES).optional(),
    /** Days the banner was created, YYYY-MM-DD, both included. */
    ...dateRangeShape,
    ...pagingShape,
  }),
) {}

export class PublicBannerQueryDto extends createZodDto(
  z.object({ placement: z.enum(BANNER_PLACEMENTS).default('HOME_TOP') }),
) {}

const variant = z.enum(BANNER_IMAGE_VARIANTS).default('mobile');

/** Which image an upload or removal is about. */
export class BannerImageVariantQueryDto extends createZodDto(z.object({ variant })) {}

/** Public image address: the variant, and the version that only busts caches. */
export class PublicBannerImageQueryDto extends createZodDto(
  z.object({ variant, v: z.string().max(32).optional() }),
) {}

export class BannerIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

export const IMAGE_EXTENSIONS = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
} as const;
type BannerImageType = keyof typeof IMAGE_EXTENSIONS;

/** JPG and PNG as the files module detects them, plus WebP (RIFF....WEBP). */
export function detectImageType(data: Buffer): BannerImageType | undefined {
  if (
    data.length >= 12 &&
    data.subarray(0, 4).toString('latin1') === 'RIFF' &&
    data.subarray(8, 12).toString('latin1') === 'WEBP'
  ) {
    return 'image/webp';
  }
  const detected = detectMimeType(data);
  return detected === 'image/jpeg' || detected === 'image/png' ? detected : undefined;
}

/** Where each image variant is kept on the banner. */
export const IMAGE_FIELDS = {
  mobile: {
    key: 'imageKey',
    mimeType: 'imageMimeType',
    updatedAt: 'imageUpdatedAt',
    external: 'externalImageUrl',
  },
  desktop: {
    key: 'desktopImageKey',
    mimeType: 'desktopImageMimeType',
    updatedAt: 'desktopImageUpdatedAt',
    external: 'externalDesktopImageUrl',
  },
} as const satisfies Record<BannerImageVariant, Record<string, keyof Banner>>;

/**
 * The image to show: a hosted address as given, or the path of the stored image relative to the
 * API base (`/api/v1/`). The version changes with each upload so caches never show an old one.
 */
export function bannerImageUrlOf(
  banner: StoredBanner,
  variant: BannerImageVariant = 'mobile',
): string | null {
  const fields = IMAGE_FIELDS[variant];
  const external = banner[fields.external];
  if (external) return external;
  if (!banner[fields.key]) return null;
  const version = banner[fields.updatedAt]?.getTime() ?? 0;
  const path = `banners/${banner._id.toHexString()}/image`;
  return variant === 'mobile' ? `${path}?v=${version}` : `${path}?variant=${variant}&v=${version}`;
}

/** Stored image keys of a banner, for removal. */
export function storedKeysOf(banner: StoredBanner): string[] {
  return [banner.imageKey, banner.desktopImageKey].filter((key): key is string => Boolean(key));
}

/** The MongoDB condition matching banners that have `status` at `now` (see bannerStatusOf). */
export function statusCondition(status: BannerStatus, now: Date): QueryFilter<Banner> {
  const started = { $or: [{ startsAt: null }, { startsAt: { $lte: now } }] };
  switch (status) {
    case 'INACTIVE':
      return { isActive: false };
    case 'SCHEDULED':
      return { isActive: true, startsAt: { $gt: now } };
    case 'EXPIRED':
      return { isActive: true, endsAt: { $lt: now }, ...started };
    case 'LIVE':
      return {
        isActive: true,
        $and: [started, { $or: [{ endsAt: null }, { endsAt: { $gte: now } }] }],
      };
  }
}

export interface BannerView {
  id: string;
  title: string;
  subtitle: string;
  buttonText: string;
  linkType: string;
  linkValue: string;
  placement: string;
  language: string;
  startsAt: string | null;
  endsAt: string | null;
  sortOrder: number;
  isActive: boolean;
  status: BannerStatus;
  imageUrl: string | null;
  externalImageUrl: string | null;
  desktopImageUrl: string | null;
  externalDesktopImageUrl: string | null;
  createdAt: string | null;
  updatedAt: string | null;
}

/** What the customer app receives: only what it needs to draw and follow the banner. */
export interface PublicBannerView {
  id: string;
  title: string;
  subtitle: string;
  buttonText: string;
  linkType: string;
  linkValue: string;
  imageUrl: string | null;
  desktopImageUrl: string | null;
}
