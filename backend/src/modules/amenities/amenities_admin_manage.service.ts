import { Injectable, Logger, type OnApplicationBootstrap } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { isDuplicateKeyError } from '../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import { type AmenityListQueryDto } from './amenities_admin_manage';

export const AMENITY_MODEL = 'Amenity';

/** Upper-case letters, digits and underscores; the key a bus refers to an amenity by. */
export const AMENITY_KEY_PATTERN = /^[A-Z][A-Z0-9_]{1,39}$/;

/**
 * The amenities the platform began with (what buses could have before the list was managed), so
 * buses already stored keep working. Names are what staff and customers read.
 */
export const STARTER_AMENITIES: ReadonlyArray<{ key: string; name: string }> = [
  { key: 'WIFI', name: 'Wi-Fi' },
  { key: 'CHARGING_POINT', name: 'Charging point' },
  { key: 'BLANKET', name: 'Blanket' },
  { key: 'PILLOW', name: 'Pillow' },
  { key: 'WATER_BOTTLE', name: 'Water bottle' },
  { key: 'READING_LIGHT', name: 'Reading light' },
  { key: 'CCTV', name: 'CCTV' },
  { key: 'GPS_TRACKING', name: 'GPS tracking' },
  { key: 'TOILET', name: 'Toilet' },
  { key: 'ENTERTAINMENT', name: 'Entertainment' },
  { key: 'SNACKS', name: 'Snacks' },
  { key: 'EMERGENCY_EXIT', name: 'Emergency exit' },
  { key: 'FIRST_AID', name: 'First aid' },
];

export interface Amenity {
  key: string;
  name: string;
  isActive: boolean;
  /** Order in lists: lower first. */
  sortOrder: number;
  createdAt?: Date;
  updatedAt?: Date;
}

export type StoredAmenity = Amenity & { _id: Types.ObjectId };

/** An amenity as staff see it. */
export interface AmenityView {
  id: string;
  key: string;
  name: string;
  isActive: boolean;
}

/** What operators and bus forms need: the active ones, by key. */
export interface AmenityChoice {
  key: string;
  name: string;
}

export function amenityViewOf(amenity: StoredAmenity): AmenityView {
  return {
    id: amenity._id.toHexString(),
    key: amenity.key,
    name: amenity.name,
    isActive: amenity.isActive,
  };
}

/**
 * The key of an amenity made from its name: "Charging point" is CHARGING_POINT. Letters and digits
 * of the English alphabet only; null when the name has too few of them to make a key.
 */
export function amenityKeyOf(name: string): string | null {
  const key = name
    .normalize('NFKD')
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 40);
  return AMENITY_KEY_PATTERN.test(key) ? key : null;
}

/**
 * What a bus offers on board, as a list staff manage: add an amenity, switch one off. Buses refer
 * to an amenity by its key; an amenity that is switched off cannot be given to a bus any more,
 * but buses that already have it keep it.
 */
@Injectable()
export class AmenitiesService implements OnApplicationBootstrap {
  private readonly logger = new Logger(AmenitiesService.name);

  constructor(
    @InjectModel(AMENITY_MODEL) private readonly amenities: Model<Amenity>,
    private readonly changes: AuditedChangeRunner,
  ) {}

  /** Fills an empty list with the starter amenities the platform began with. */
  async onApplicationBootstrap(): Promise<void> {
    if ((await this.amenities.estimatedDocumentCount().exec()) > 0) return;
    let added = 0;
    for (const [index, starter] of STARTER_AMENITIES.entries()) {
      try {
        await this.amenities.create({ ...starter, isActive: true, sortOrder: (index + 1) * 10 });
        added += 1;
      } catch (error) {
        if (!isDuplicateKeyError(error)) throw error;
      }
    }
    this.logger.log({ added }, 'Starter amenities added');
  }

  async list(query: AmenityListQueryDto): Promise<PaginatedResult<AmenityView>> {
    const match = query.active === undefined ? {} : { isActive: query.active };
    const [items, total] = await Promise.all([
      this.amenities
        .find(match)
        .sort({ sortOrder: 1, name: 1, _id: 1 })
        .skip(skipOf(query))
        .limit(query.pageSize)
        .lean<StoredAmenity[]>()
        .exec(),
      this.amenities.countDocuments(match).exec(),
    ]);
    return new PaginatedResult(items.map(amenityViewOf), query.page, query.pageSize, total);
  }

  /** The amenities a bus can be given. */
  async choices(): Promise<AmenityChoice[]> {
    const active = await this.amenities
      .find({ isActive: true })
      .sort({ sortOrder: 1, name: 1, _id: 1 })
      .lean<StoredAmenity[]>()
      .exec();
    return active.map((amenity) => ({ key: amenity.key, name: amenity.name }));
  }

  async create(
    actor: AuthenticatedUserActor,
    name: string,
    client: ClientRequestInfo,
  ): Promise<AmenityView> {
    const key = amenityKeyOf(name);
    if (!key) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'The name needs at least two letters or digits (A to Z, 0 to 9).',
      );
    }
    const last = await this.amenities
      .findOne()
      .sort({ sortOrder: -1 })
      .lean<StoredAmenity>()
      .exec();
    try {
      const created = await this.changes.run({
        actor,
        client,
        action: 'catalogue.created',
        entityType: 'amenity',
        before: {},
        apply: async (session) => {
          const [amenity] = await this.amenities.create(
            [{ key, name, isActive: true, sortOrder: (last?.sortOrder ?? 0) + 10 }],
            { session },
          );
          if (!amenity) throw new Error('Amenity was not created');
          return amenity.toObject();
        },
        describe: (record) => ({ ...amenityViewOf(record) }),
      });
      return amenityViewOf(created);
    } catch (error) {
      if (isDuplicateKeyError(error)) {
        throw new ApiException('ALREADY_REGISTERED', 'An amenity with this name already exists.');
      }
      throw error;
    }
  }

  async setActive(
    actor: AuthenticatedUserActor,
    id: string,
    active: boolean,
    client: ClientRequestInfo,
  ): Promise<AmenityView> {
    const before = await this.require(id);
    if (before.isActive === active) return amenityViewOf(before);
    const updated = await this.changes.run({
      actor,
      client,
      action: 'catalogue.status-changed',
      entityType: 'amenity',
      before: { isActive: before.isActive },
      apply: async (session) => {
        const saved = await this.amenities
          .findOneAndUpdate(
            { _id: before._id },
            { $set: { isActive: active } },
            { returnDocument: 'after', session },
          )
          .lean<StoredAmenity>()
          .exec();
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Amenity not found');
        return saved;
      },
      describe: (record) => ({ key: record.key, isActive: record.isActive }),
    });
    return amenityViewOf(updated);
  }

  /**
   * Refuses an amenity that does not exist or is switched off. Amenities the bus has already
   * ([kept]) stay allowed, so editing a bus does not fail over something that was switched off later.
   */
  async assertUsable(keys: readonly string[], kept: readonly string[] = []): Promise<void> {
    const wanted = keys.filter((key) => !kept.includes(key));
    if (wanted.length === 0) return;
    const usable = await this.amenities
      .find({ key: { $in: wanted }, isActive: true })
      .lean<StoredAmenity[]>()
      .exec();
    const found = new Set(usable.map((amenity) => amenity.key));
    const missing = wanted.filter((key) => !found.has(key));
    if (missing.length > 0) {
      throw new ApiException('VALIDATION_FAILED', 'Request validation failed', {
        location: 'body',
        issues: [
          {
            path: 'amenities',
            code: 'custom',
            message: `not available: ${missing.join(', ')}`,
          },
        ],
      });
    }
  }

  private async require(id: string): Promise<StoredAmenity> {
    const found = Types.ObjectId.isValid(id)
      ? await this.amenities.findById(id).lean<StoredAmenity>().exec()
      : null;
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'Amenity not found');
    return found;
  }
}
