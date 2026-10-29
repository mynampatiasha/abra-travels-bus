import { InjectModel } from '@nestjs/mongoose';
import { type Model } from 'mongoose';
import { type ScopeFields } from '../../database/data-scope.policy';
import { ScopedRepository, type StoredDocument } from '../../database/scoped-repository.base';
import { Injectable } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Connection, Types } from 'mongoose';

export const SEAT_LAYOUT_MODEL = 'SeatLayout';

export const SEAT_TYPES = ['SEAT', 'SLEEPER'] as const;
export type SeatType = (typeof SEAT_TYPES)[number];

export const SEAT_CATEGORIES = ['STANDARD', 'PREMIUM'] as const;
export type SeatCategory = (typeof SEAT_CATEGORIES)[number];

export interface SeatItem {
  seatNumber: string;
  deck: number; // 1 = lower, 2 = upper
  row: number;
  col: number;
  type: SeatType;
  category: SeatCategory;
  isLadies: boolean;
  isBlocked: boolean;
}

export interface SeatLayout {
  busId: Types.ObjectId;
  operatorId: Types.ObjectId;
  version: number;
  name: string;
  layoutType: string;
  decks: number;
  map: string[];
  upperDeckMap?: string[];
  seats: SeatItem[];
  totalSeats: number;
  ladiesSeatsCount: number;
  createdAt?: Date;
  updatedAt?: Date;
}
import { ApiException } from '../../common/errors/api-exception';
import { rejectDuplicates } from '../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AmenitiesService } from '../amenities/amenities_admin_manage.service';
import { BusTypeRepository } from '../bus-types/repositories/bus-type.repository';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import {
  type BusListQueryDto,
  type ChangeBusStatusDto,
  type CreateBusDto,
  type SaveSeatLayoutDto,
  type UpdateBusDto,
} from './dto/bus.dto';
import { BusRepository, type StoredBus } from './repositories/bus.repository';

import { type Bus, type BusStatus } from './schemas/bus.schema';



export interface ClientBusKpis {
  totalBuses: number;
  activeCount: number;
  pendingCount: number;
  maintenanceCount: number;
  expiringIn30DaysCount: number;
}

export interface ClientBusView {
  id: string;
  registrationNumber: string;
  name: string;
  busTypeId: string;
  busTypeName?: string;
  make?: string;
  /** Ready-made name for lists, e.g. "Volvo AC Sleeper"; without a make, the bus type name. */
  displayName: string;
  amenities: string[];
  seatCapacity: number;
  seatLayoutType: string;
  activeSeatLayoutVersionId: string | null;
  insuranceExpiryDate: string | null;
  status: BusStatus;
  statusReason?: string;
  createdAt?: string;
}

export interface ClientSeatLayoutView {
  id: string;
  busId: string;
  version: number;
  name: string;
  layoutType: string;
  decks: number;
  map: string[];
  upperDeckMap?: string[];
  seats: SeatItem[];
  totalSeats: number;
  ladiesSeatsCount: number;
}

// ===== SEAT LAYOUT REPOSITORY & BUILDER LOGIC =====


export type StoredSeatLayout = StoredDocument<SeatLayout>;

@Injectable()
export class SeatLayoutRepository extends ScopedRepository<SeatLayout> {
  protected readonly scopeFields: ScopeFields = { operator: 'operatorId' };

  constructor(@InjectModel(SEAT_LAYOUT_MODEL) model: Model<SeatLayout>) {
    super(model);
  }

  async findLatestForBus(busId: string): Promise<StoredSeatLayout | null> {
    const list = await this.findMany(
      { busId: new Types.ObjectId(busId) },
      { sort: { version: -1 }, limit: 1 },
    );
    return list[0] ?? null;
  }

  async findByBusAndVersion(busId: string, version: number): Promise<StoredSeatLayout | null> {
    return this.findOne({ busId: new Types.ObjectId(busId), version });
  }
}

export interface ParsedLayout {
  seats: SeatItem[];
  totalSeats: number;
  ladiesSeatsCount: number;
  berthCount: number;
}

export function defaultSeatMap(layoutType: string, seatCapacity = 40): string[] {
  const isSleeper = /sleeper/i.test(layoutType);
  const rowPattern = isSleeper ? 'SS_S' : 'SS_SS';
  const seatsPerRow = isSleeper ? 3 : 4;
  const rowCount = Math.max(1, Math.ceil(seatCapacity / seatsPerRow));
  return Array.from({ length: rowCount }, () => rowPattern);
}

export function parseSeatMapToSeats(
  lowerMap: string[],
  upperMap?: string[],
): ParsedLayout {
  const seats: SeatItem[] = [];
  let seatNumberSeq = 1;
  let ladiesCount = 0;
  let berthCount = 0;
  const hasUpper = Array.isArray(upperMap) && upperMap.length > 0;

  function processDeck(deckNumber: number, map: string[], prefix: string) {
    for (let r = 0; r < map.length; r++) {
      const rowStr = map[r] ?? '';
      for (let c = 0; c < rowStr.length; c++) {
        const char = rowStr[c] ?? '';
        if (char === '_' || char === '.') continue;

        const isSleeper = char === 'B';
        const isLadies = char === 'L';
        const isBlocked = char === 'X';

        const type: SeatType = isSleeper ? 'SLEEPER' : 'SEAT';
        const category: SeatCategory = isSleeper ? 'PREMIUM' : 'STANDARD';

        const seatLabel = hasUpper
          ? `${prefix}${seatNumberSeq}`
          : `${seatNumberSeq}`;
        seatNumberSeq++;

        if (isLadies) ladiesCount++;
        if (isSleeper) berthCount++;

        seats.push({
          seatNumber: seatLabel,
          deck: deckNumber,
          row: r,
          col: c,
          type,
          category,
          isLadies,
          isBlocked,
        });
      }
    }
  }

  processDeck(1, lowerMap, 'L');
  if (hasUpper && upperMap) {
    seatNumberSeq = 1;
    processDeck(2, upperMap, 'U');
  }

  return {
    seats,
    totalSeats: seats.length,
    ladiesSeatsCount: ladiesCount,
    berthCount,
  };
}


@Injectable()
export class BusesClientManageService {
  constructor(
    private readonly buses: BusRepository,
    private readonly layouts: SeatLayoutRepository,
    private readonly busTypes: BusTypeRepository,
    private readonly amenities: AmenitiesService,
    private readonly changes: AuditedChangeRunner,
    @InjectConnection() private readonly connection: Connection,
  ) {}

  async list(
    actor: AuthenticatedUserActor,
    query: BusListQueryDto,
  ): Promise<PaginatedResult<ClientBusView>> {
    const operatorId = this.requireOperatorId(actor);
    const filter: Record<string, unknown> = { operatorId };

    if (query.status) {
      filter.status = query.status;
    }
    if (query.query) {
      const rx = new RegExp(escapeRegExp(query.query), 'i');
      filter.$or = [{ registrationNumber: rx }, { name: rx }];
    }

    const [items, total] = await Promise.all([
      this.buses.findMany(filter, {
        sort: { createdAt: -1, _id: -1 },
        skip: skipOf(query),
        limit: query.pageSize,
      }),
      this.buses.count(filter),
    ]);

    const views = await this.populateViews(items);
    return new PaginatedResult(views, query.page, query.pageSize, total);
  }

  async kpis(actor: AuthenticatedUserActor): Promise<ClientBusKpis> {
    const operatorId = this.requireOperatorId(actor);
    const allOperatorBuses = await this.buses.findMany({ operatorId });

    const now = new Date();
    const in30Days = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    return {
      totalBuses: allOperatorBuses.length,
      activeCount: allOperatorBuses.filter((b) => b.status === 'ACTIVE').length,
      pendingCount: allOperatorBuses.filter((b) => b.status === 'PENDING_APPROVAL').length,
      maintenanceCount: allOperatorBuses.filter((b) => b.status === 'MAINTENANCE').length,
      expiringIn30DaysCount: allOperatorBuses.filter(
        (b) => b.insuranceExpiryDate && b.insuranceExpiryDate <= in30Days && b.insuranceExpiryDate >= now,
      ).length,
    };
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<ClientBusView> {
    const bus = await this.buses.getById(id);
    this.assertOwnsBus(actor, bus);
    const views = await this.populateViews([bus]);
    const view = views[0];
    if (!view) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Bus not found.');
    }
    return view;
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateBusDto,
    client: ClientRequestInfo,
  ): Promise<ClientBusView> {
    const operatorId = this.requireOperatorId(actor);
    const busTypeId = await this.activeBusType(input.busTypeId);
    await this.amenities.assertUsable(input.amenities);

    const seatCapacity = input.seatCapacity ?? 40;
    const seatLayoutType = input.seatLayoutType ?? '2+2 Seater';
    const insExp = input.insuranceExpiryDate ? new Date(input.insuranceExpiryDate) : undefined;

    const created = await rejectDuplicates(
      'A bus with this registration number already exists.',
      () =>
        this.changes.run({
          actor,
          client,
          action: 'catalogue.created',
          entityType: 'bus',
          before: {},
          apply: async (session) => {
            const bus = await this.buses.insertOne(
              {
                operatorId,
                registrationNumber: input.registrationNumber,
                name: input.name,
                busTypeId,
                ...(input.make ? { make: input.make } : {}),
                amenities: input.amenities,
                seatCapacity,
                seatLayoutType,
                insuranceExpiryDate: insExp,
                status: 'PENDING_APPROVAL',
              },
              { session },
            );

            // Generate initial default layout
            const map = defaultSeatMap(seatLayoutType, seatCapacity);
            const parsed = parseSeatMapToSeats(map);
            const layoutModel = this.connection.model<SeatLayout>(SEAT_LAYOUT_MODEL);
            const createdLayouts: Array<{ _id: Types.ObjectId }> = await layoutModel.create(
              [
                {
                  busId: bus._id,
                  operatorId,
                  version: 1,
                  name: seatLayoutType,
                  layoutType: seatLayoutType,
                  decks: 1,
                  map,
                  seats: parsed.seats,
                  totalSeats: parsed.totalSeats,
                  ladiesSeatsCount: parsed.ladiesSeatsCount,
                },
              ],
              { session },
            );
            const layout = createdLayouts[0]!;

            await this.buses.updateOne(
              { _id: bus._id },
              { $set: { activeSeatLayoutVersionId: layout._id } },
              { session },
            );

            bus.activeSeatLayoutVersionId = layout._id;
            return bus;
          },
          describe: (record) => ({ id: record._id.toHexString(), reg: record.registrationNumber }),
          operatorIdOf: (record) => record.operatorId,
        }),
    );

    return this.get(actor, created._id.toHexString());
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateBusDto,
    client: ClientRequestInfo,
  ): Promise<ClientBusView> {
    const before = await this.buses.getById(id);
    this.assertOwnsBus(actor, before);

    const set: Partial<Bus> = {};
    if (input.name !== undefined) set.name = input.name;
    if (input.make !== undefined) set.make = input.make;
    if (input.amenities !== undefined) {
      await this.amenities.assertUsable(input.amenities, before.amenities);
      set.amenities = input.amenities;
    }
    if (input.seatCapacity !== undefined) set.seatCapacity = input.seatCapacity;
    if (input.seatLayoutType !== undefined) set.seatLayoutType = input.seatLayoutType;
    if (input.insuranceExpiryDate !== undefined) {
      set.insuranceExpiryDate = new Date(input.insuranceExpiryDate);
    }

    if (Object.keys(set).length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }

    await this.changes.run({
      actor,
      client,
      action: 'catalogue.updated',
      entityType: 'bus',
      before: { name: before.name },
      apply: async (session) => {
        await this.buses.updateOne({ _id: before._id }, { $set: set }, { session });
        return { _id: before._id };
      },
      describe: () => ({ id: before._id.toHexString(), reg: before.registrationNumber }),
      operatorIdOf: () => before.operatorId,
    });

    return this.get(actor, id);
  }

  async changeStatus(
    actor: AuthenticatedUserActor,
    id: string,
    input: ChangeBusStatusDto,
    client: ClientRequestInfo,
  ): Promise<ClientBusView> {
    const before = await this.buses.getById(id);
    this.assertOwnsBus(actor, before);

    if (before.status === input.status) return this.get(actor, id);

    if (before.status === 'PENDING_APPROVAL') {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'This bus is waiting for approval by Abra. You cannot change its status.',
      );
    }

    if (input.status === 'MAINTENANCE') {
      const activeTripsCount = await this.connection.collection('trips').countDocuments({
        busId: before._id,
        status: { $in: ['SCHEDULED', 'BOARDING', 'IN_TRANSIT'] },
      });
      if (activeTripsCount > 0) {
        throw new ApiException(
          'VALIDATION_FAILED',
          `${activeTripsCount} upcoming trip(s) use this bus. Move them to another bus first.`,
        );
      }
    }

    await this.changes.run({
      actor,
      client,
      action: 'catalogue.status-changed',
      entityType: 'bus',
      reason: input.reason,
      before: { status: before.status },
      apply: async (session) => {
        await this.buses.updateOne(
          { _id: before._id },
          { $set: { status: input.status, statusReason: input.reason } },
          { session },
        );
        return { _id: before._id };
      },
      describe: () => ({ id: before._id.toHexString(), status: input.status }),
      operatorIdOf: () => before.operatorId,
    });

    return this.get(actor, id);
  }

  // ===== SEAT LAYOUT METHODS =====

  async getLayoutForBus(
    actor: AuthenticatedUserActor,
    busId: string,
  ): Promise<ClientSeatLayoutView> {
    const bus = await this.buses.getById(busId);
    this.assertOwnsBus(actor, bus);

    const layout = bus.activeSeatLayoutVersionId
      ? await this.layouts.findById(bus.activeSeatLayoutVersionId.toHexString())
      : await this.layouts.findLatestForBus(busId);

    if (!layout) {
      const defaultMap = defaultSeatMap(bus.seatLayoutType ?? '2+2 Seater', bus.seatCapacity ?? 40);
      const parsed = parseSeatMapToSeats(defaultMap);
      return {
        id: 'preview',
        busId,
        version: 1,
        name: bus.seatLayoutType ?? '2+2 Seater',
        layoutType: bus.seatLayoutType ?? '2+2 Seater',
        decks: 1,
        map: defaultMap,
        seats: parsed.seats,
        totalSeats: parsed.totalSeats,
        ladiesSeatsCount: parsed.ladiesSeatsCount,
      };
    }

    return this.seatLayoutViewOf(layout);
  }

  async saveLayout(
    actor: AuthenticatedUserActor,
    busId: string,
    input: SaveSeatLayoutDto,
    client: ClientRequestInfo,
  ): Promise<ClientSeatLayoutView> {
    const bus = await this.buses.getById(busId);
    this.assertOwnsBus(actor, bus);

    const parsed = parseSeatMapToSeats(input.map, input.upperDeckMap);
    if (parsed.totalSeats === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Layout must contain at least 1 seat.');
    }

    const latest = await this.layouts.findLatestForBus(busId);
    const nextVersion = (latest?.version ?? 0) + 1;

    await this.changes.run({
      actor,
      client,
      action: 'catalogue.updated',
      entityType: 'bus',
      before: {
        busId,
        activeLayoutVersion: latest?.version ?? 0,
        seatCapacity: bus.seatCapacity,
      },
      apply: async (session) => {
        const layoutModel = this.connection.model<SeatLayout>(SEAT_LAYOUT_MODEL);
        const createdLayouts = await layoutModel.create(
          [
            {
              busId: bus._id,
              operatorId: bus.operatorId,
              version: nextVersion,
              name: input.name,
              layoutType: input.layoutType,
              decks: input.decks,
              map: input.map,
              upperDeckMap: input.upperDeckMap,
              seats: parsed.seats,
              totalSeats: parsed.totalSeats,
              ladiesSeatsCount: parsed.ladiesSeatsCount,
            },
          ],
          { session },
        );
        const newLayout = createdLayouts[0]!;

        await this.buses.updateOne(
          { _id: bus._id },
          {
            $set: {
              activeSeatLayoutVersionId: newLayout._id,
              seatCapacity: parsed.totalSeats,
              seatLayoutType: input.layoutType,
            },
          },
          { session },
        );

        return { _id: newLayout._id };
      },
      describe: () => ({
        busId,
        version: nextVersion,
        seats: parsed.totalSeats,
      }),
      operatorIdOf: () => bus.operatorId,
    });

    return this.getLayoutForBus(actor, busId);
  }

  async getLayoutVersion(
    actor: AuthenticatedUserActor,
    versionId: string,
  ): Promise<ClientSeatLayoutView> {
    const layout = await this.layouts.getById(versionId);
    if (!layout.operatorId.equals(this.requireOperatorId(actor))) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Seat layout not found.');
    }
    return this.seatLayoutViewOf(layout);
  }

  private seatLayoutViewOf(layout: SeatLayout & { _id: Types.ObjectId }): ClientSeatLayoutView {
    return {
      id: layout._id.toHexString(),
      busId: layout.busId.toHexString(),
      version: layout.version,
      name: layout.name,
      layoutType: layout.layoutType,
      decks: layout.decks,
      map: [...layout.map],
      upperDeckMap: layout.upperDeckMap ? [...layout.upperDeckMap] : undefined,
      seats: layout.seats,
      totalSeats: layout.totalSeats,
      ladiesSeatsCount: layout.ladiesSeatsCount,
    };
  }

  private async populateViews(buses: StoredBus[]): Promise<ClientBusView[]> {
    if (buses.length === 0) return [];

    const typeIds = [...new Set(buses.map((b) => b.busTypeId.toHexString()))];
    const types = await this.connection
      .model('BusType')
      .find({ _id: { $in: typeIds.map((id) => new Types.ObjectId(id)) } })
      .lean<Array<{ _id: Types.ObjectId; name: string }>>()
      .exec();
    const typeMap = new Map<string, string>(types.map((t) => [t._id.toHexString(), t.name]));

    return buses.map((b) => {
      const busTypeName = typeMap.get(b.busTypeId.toHexString()) ?? 'Standard Bus';
      return {
      id: b._id.toHexString(),
      registrationNumber: b.registrationNumber,
      name: b.name,
      busTypeId: b.busTypeId.toHexString(),
      busTypeName,
      ...(b.make ? { make: b.make } : {}),
      displayName: b.make ? `${b.make} ${busTypeName}` : busTypeName,
      amenities: [...b.amenities],
      seatCapacity: b.seatCapacity ?? 40,
      seatLayoutType: b.seatLayoutType ?? '2+2 Seater',
      activeSeatLayoutVersionId: b.activeSeatLayoutVersionId?.toHexString() ?? null,
      insuranceExpiryDate: b.insuranceExpiryDate ? b.insuranceExpiryDate.toISOString() : null,
      status: b.status,
      statusReason: b.statusReason,
      createdAt: b.createdAt ? b.createdAt.toISOString() : undefined,
      };
    });
  }

  private requireOperatorId(actor: AuthenticatedUserActor): Types.ObjectId {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Caller must belong to an operator.');
    }
    return new Types.ObjectId(actor.operatorId);
  }

  private assertOwnsBus(actor: AuthenticatedUserActor, bus: StoredBus): void {
    const opId = this.requireOperatorId(actor);
    if (!bus.operatorId.equals(opId)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Bus not found.');
    }
  }

  private async activeBusType(id: string): Promise<Types.ObjectId> {
    const busType = await this.busTypes.findById(id);
    if (!busType?.isActive) {
      throw new ApiException('VALIDATION_FAILED', 'busTypeId is not an active bus type.');
    }
    return busType._id;
  }
}

