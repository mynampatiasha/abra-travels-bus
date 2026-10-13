import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model, Types } from 'mongoose';
import {
  type BerthType,
  BERTH_TYPES,
  BUS_TYPE_MODEL,
  type BusType,
} from '../modules/bus-types/schemas/bus-type.schema';
import {
  BUS_MODEL,
  type Bus,
  type BusStatus,
  BUS_STATUSES,
} from '../modules/buses/schemas/bus.schema';
import { CITY_MODEL, type City } from '../modules/cities/schemas/city.schema';
import { LOCATION_MODEL, type Location } from '../modules/locations/schemas/location.schema';
import {
  OPERATOR_MODEL,
  type Operator,
  type OperatorStatus,
  OPERATOR_STATUSES,
} from '../modules/operators/schemas/operator.schema';

// ===== 1. THE DEMO FIXTURE ==========================================================
// `backend/seed/demo-data.json` was taken from the demos' shared store (the same sample data
// every demo shows). The mapping below turns it into real documents.

export interface DemoData {
  source: string;
  cities: Array<{
    id: string;
    name: string;
    state: string;
    active: boolean;
    popular: boolean;
    te?: string;
    hi?: string;
  }>;
  places: Array<{
    id: string;
    city: string;
    name: string;
    address: string;
    landmark?: string;
    lat?: string;
    lng?: string;
    phone?: string;
    type: string;
    active: boolean;
  }>;
  busTypes: Array<{
    id: string;
    name: string;
    key: string;
    ac: boolean;
    berth: string;
    active: boolean;
  }>;
  operators: Array<{
    id: string;
    name: string;
    owner?: string;
    email?: string;
    phone?: string;
    city?: string;
    status: string;
  }>;
  buses: Array<{
    id: string;
    operatorId: string;
    reg: string;
    name: string;
    type: string;
    seats: number;
    status: string;
  }>;
}

export const SEED_SETS = ['catalogue', 'companies'] as const;
export type SeedSet = (typeof SEED_SETS)[number];

export interface SeedCount {
  created: number;
  existing: number;
  skipped: number;
}

export type SeedReport = Record<string, SeedCount>;

const empty = (): SeedCount => ({ created: 0, existing: 0, skipped: 0 });

// ===== 2. MAPPING (pure, so it can be tested without a database) ====================

export function slugOf(name: string): string {
  return name
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80);
}

/** The demo writes Telangana-style numbers as strings, some empty: a point only when both are numbers. */
export function pointOf(
  lat: string | undefined,
  lng: string | undefined,
): { type: 'Point'; coordinates: [number, number] } | undefined {
  const latitude = Number(lat);
  const longitude = Number(lng);
  if (!lat || !lng || !Number.isFinite(latitude) || !Number.isFinite(longitude)) return undefined;
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180) return undefined;
  return { type: 'Point', coordinates: [longitude, latitude] };
}

export function cityOf(demo: DemoData['cities'][number], sortOrder: number): City {
  const translations: Record<string, string> = {};
  if (demo.te) translations.te = demo.te;
  if (demo.hi) translations.hi = demo.hi;
  return {
    name: demo.name,
    slug: slugOf(demo.name),
    state: demo.state,
    countryCode: 'IN',
    ...(Object.keys(translations).length > 0 ? { translations } : {}),
    isPopular: demo.popular,
    sortOrder,
    isActive: demo.active,
  };
}

export function busTypeOf(demo: DemoData['busTypes'][number]): BusType | undefined {
  const berthType = demo.berth as BerthType;
  if (!/^[A-Z][A-Z0-9_]*$/.test(demo.key) || !BERTH_TYPES.includes(berthType)) return undefined;
  return { key: demo.key, name: demo.name, isAc: demo.ac, berthType, isActive: demo.active };
}

export function locationOf(demo: DemoData['places'][number], cityId: Types.ObjectId): Location {
  const location = pointOf(demo.lat, demo.lng);
  return {
    cityId,
    name: demo.name,
    address: demo.address,
    ...(demo.landmark ? { landmark: demo.landmark } : {}),
    ...(location ? { location } : {}),
    ...(demo.phone ? { contactPhone: demo.phone.slice(0, 20) } : {}),
    isActive: demo.active,
  };
}

export function operatorOf(demo: DemoData['operators'][number]): Operator | undefined {
  const status = demo.status as OperatorStatus;
  if (!OPERATOR_STATUSES.includes(status)) return undefined;
  return { companyName: demo.name, status };
}

export function busOf(
  demo: DemoData['buses'][number],
  operatorId: Types.ObjectId,
  busTypeId: Types.ObjectId,
): Bus | undefined {
  const status = demo.status as BusStatus;
  if (!BUS_STATUSES.includes(status) || !demo.reg) return undefined;
  return {
    operatorId,
    registrationNumber: demo.reg.toUpperCase(),
    name: demo.name,
    busTypeId,
    amenities: [],
    seatCapacity: demo.seats,
    status,
  };
}

// ===== 3. THE SEEDER ================================================================

/**
 * Loads the demo's sample data into MongoDB, for development and demos only. It never changes a
 * record that already exists (matched by its natural key: city slug, bus type key, place name in
 * its city, company name, bus registration), so it is safe to run again and never overwrites
 * something an administrator edited. `dryRun` counts what would happen and writes nothing.
 */
@Injectable()
export class SeedDemoDataService {
  constructor(
    @InjectModel(CITY_MODEL) private readonly cities: Model<City>,
    @InjectModel(LOCATION_MODEL) private readonly locations: Model<Location>,
    @InjectModel(BUS_TYPE_MODEL) private readonly busTypes: Model<BusType>,
    @InjectModel(OPERATOR_MODEL) private readonly operators: Model<Operator>,
    @InjectModel(BUS_MODEL) private readonly buses: Model<Bus>,
  ) {}

  async run(
    data: DemoData,
    options: { sets: readonly SeedSet[]; dryRun: boolean },
  ): Promise<SeedReport> {
    const report: SeedReport = {};
    if (options.sets.includes('catalogue')) await this.catalogue(data, options.dryRun, report);
    if (options.sets.includes('companies')) await this.companies(data, options.dryRun, report);
    return report;
  }

  private async catalogue(data: DemoData, dryRun: boolean, report: SeedReport): Promise<void> {
    const cityReport = (report.cities = empty());
    const cityIds = new Map<string, Types.ObjectId>();
    let order = 0;
    for (const demo of data.cities) {
      order += 1;
      const wanted = cityOf(demo, order);
      const found = await this.cities
        .findOne({ slug: wanted.slug })
        .lean<City & { _id: Types.ObjectId }>()
        .exec();
      if (found) {
        cityReport.existing += 1;
        cityIds.set(demo.name, found._id);
      } else if (dryRun) {
        cityReport.created += 1;
      } else {
        const created = await this.cities.create(wanted);
        cityReport.created += 1;
        cityIds.set(demo.name, created._id);
      }
    }

    const typeReport = (report.busTypes = empty());
    for (const demo of data.busTypes) {
      const wanted = busTypeOf(demo);
      if (!wanted) {
        typeReport.skipped += 1;
        continue;
      }
      if (await this.busTypes.exists({ key: wanted.key })) typeReport.existing += 1;
      else {
        if (!dryRun) await this.busTypes.create(wanted);
        typeReport.created += 1;
      }
    }

    const placeReport = (report.places = empty());
    for (const demo of data.places) {
      const cityId = cityIds.get(demo.city);
      if (!cityId) {
        // Only possible in a dry run on an empty database, or a place whose city is not in the fixture
        if (dryRun && data.cities.some((city) => city.name === demo.city)) placeReport.created += 1;
        else placeReport.skipped += 1;
        continue;
      }
      if (await this.locations.exists({ cityId, name: demo.name })) placeReport.existing += 1;
      else {
        if (!dryRun) await this.locations.create(locationOf(demo, cityId));
        placeReport.created += 1;
      }
    }
  }

  private async companies(data: DemoData, dryRun: boolean, report: SeedReport): Promise<void> {
    const operatorReport = (report.operators = empty());
    const operatorIds = new Map<string, Types.ObjectId>();
    for (const demo of data.operators) {
      const wanted = operatorOf(demo);
      if (!wanted) {
        operatorReport.skipped += 1;
        continue;
      }
      const found = await this.operators
        .findOne({ companyName: wanted.companyName })
        .lean<Operator & { _id: Types.ObjectId }>()
        .exec();
      if (found) {
        operatorReport.existing += 1;
        operatorIds.set(demo.id, found._id);
      } else if (dryRun) {
        operatorReport.created += 1;
      } else {
        const created = await this.operators.create(wanted);
        operatorReport.created += 1;
        operatorIds.set(demo.id, created._id);
      }
    }

    const busReport = (report.buses = empty());
    const typeIds = new Map<string, Types.ObjectId>();
    for (const type of await this.busTypes
      .find()
      .lean<Array<BusType & { _id: Types.ObjectId }>>()
      .exec()) {
      typeIds.set(type.name, type._id);
    }
    for (const demo of data.buses) {
      const operatorId = operatorIds.get(demo.operatorId);
      const busTypeId = typeIds.get(demo.type);
      if (!operatorId || !busTypeId) {
        // A dry run on an empty database cannot know the ids yet, and counts the bus as new
        if (
          dryRun &&
          data.operators.some((operator) => operator.id === demo.operatorId) &&
          data.busTypes.some((type) => type.name === demo.type)
        ) {
          busReport.created += 1;
        } else {
          busReport.skipped += 1;
        }
        continue;
      }
      const wanted = busOf(demo, operatorId, busTypeId);
      if (!wanted) {
        busReport.skipped += 1;
        continue;
      }
      if (await this.buses.exists({ registrationNumber: wanted.registrationNumber }))
        busReport.existing += 1;
      else {
        if (!dryRun) await this.buses.create(wanted);
        busReport.created += 1;
      }
    }
  }
}
