import { Injectable } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Connection, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { rejectDuplicates } from '../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp, skipOf } from '../../common/pipes/list-query';
import { operatorForNewRecord } from '../../common/request-context/operator-scope';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AmenitiesService } from '../amenities/amenities_admin_manage.service';
import { BusTypeRepository } from '../bus-types/repositories/bus-type.repository';
import { OperatorRepository } from '../operators/repositories/operator.repository';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import {
  type BulkMaintenanceDto,
  type BusListQueryDto,
  type ChangeBusStatusDto,
  type CreateBusDto,
  type UpdateBusDto,
} from './dto/bus.dto';
import { BusRepository, type StoredBus } from './repositories/bus.repository';
import { SeatLayoutRepository, defaultSeatMap, parseSeatMapToSeats } from './buses_client_manage.service';
import { SEAT_LAYOUT_MODEL, type SeatLayout } from './buses_client_manage.service';
import { type Bus, type BusStatus } from './schemas/bus.schema';


export interface AdminBusView {
  id: string;
  operatorId: string;
  operatorName?: string;
  registrationNumber: string;
  name: string;
  busTypeId: string;
  busTypeName?: string;
  amenities: string[];
  seatCapacity: number;
  seatLayoutType: string;
  activeSeatLayoutVersionId: string | null;
  insuranceExpiryDate: string | null;
  status: BusStatus;
  statusReason?: string;
  createdAt?: string;
}

@Injectable()
export class BusesAdminManageService {
  constructor(
    private readonly buses: BusRepository,
    private readonly layouts: SeatLayoutRepository,
    private readonly busTypes: BusTypeRepository,
    private readonly operators: OperatorRepository,
    private readonly amenities: AmenitiesService,
    private readonly changes: AuditedChangeRunner,
    @InjectConnection() private readonly connection: Connection,
  ) {}

  async list(query: BusListQueryDto): Promise<PaginatedResult<AdminBusView>> {
    const filter: Record<string, unknown> = {};

    if (query.operatorId) {
      filter.operatorId = new Types.ObjectId(query.operatorId);
    }
    if (query.busTypeId) {
      filter.busTypeId = new Types.ObjectId(query.busTypeId);
    }
    if (query.status) {
      filter.status = query.status;
    }
    if (query.query) {
      const rx = new RegExp(escapeRegExp(query.query), 'i');
      filter.$or = [{ registrationNumber: rx }, { name: rx }];
    }
    if (query.expiredInsurance) {
      filter.insuranceExpiryDate = { $lt: new Date() };
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

  async get(id: string): Promise<AdminBusView> {
    const bus = await this.buses.getById(id);
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
  ): Promise<AdminBusView> {
    const operatorId = operatorForNewRecord(actor, input.operatorId);
    await this.operators.getById(operatorId.toHexString());
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
                amenities: input.amenities,
                seatCapacity,
                seatLayoutType,
                insuranceExpiryDate: insExp,
                status: actor.userType === 'STAFF' ? 'ACTIVE' : 'PENDING_APPROVAL',
              },
              { session },
            );

            // Generate layout version 1 automatically
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

    return this.get(created._id.toHexString());
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateBusDto,
    client: ClientRequestInfo,
  ): Promise<AdminBusView> {
    const before = await this.buses.getById(id);
    const set: Partial<Bus> = {};

    if (input.name !== undefined) set.name = input.name;
    if (input.amenities !== undefined) {
      await this.amenities.assertUsable(input.amenities, before.amenities);
      set.amenities = input.amenities;
    }
    if (input.seatCapacity !== undefined) set.seatCapacity = input.seatCapacity;
    if (input.seatLayoutType !== undefined) set.seatLayoutType = input.seatLayoutType;
    if (input.insuranceExpiryDate !== undefined) {
      set.insuranceExpiryDate = new Date(input.insuranceExpiryDate);
    }
    if (input.busTypeId !== undefined) {
      set.busTypeId = await this.activeBusType(input.busTypeId);
    }

    if (Object.keys(set).length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }

    await this.changes.run({
      actor,
      client,
      action: 'catalogue.updated',
      entityType: 'bus',
      before: { name: before.name, seatCapacity: before.seatCapacity },
      apply: async (session) => {
        await this.buses.updateOne({ _id: before._id }, { $set: set }, { session });
        return { _id: before._id };
      },
      describe: () => ({ id: before._id.toHexString(), reg: before.registrationNumber }),
      operatorIdOf: () => before.operatorId,
    });

    return this.get(id);
  }

  async changeStatus(
    actor: AuthenticatedUserActor,
    id: string,
    input: ChangeBusStatusDto,
    client: ClientRequestInfo,
  ): Promise<AdminBusView> {
    const before = await this.buses.getById(id);
    if (before.status === input.status) return this.get(id);

    if (before.status === 'PENDING_APPROVAL' && actor.userType !== 'STAFF') {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'This bus is waiting for its documents to be approved. Platform staff approve it.',
      );
    }
    if (before.status === 'RETIRED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'A retired bus cannot be put back.');
    }

    if (input.status === 'RETIRED') {
      const activeTripsCount = await this.connection.collection('trips').countDocuments({
        busId: before._id,
        status: { $in: ['SCHEDULED', 'BOARDING', 'IN_TRANSIT'] },
      });
      if (activeTripsCount > 0) {
        throw new ApiException(
          'VALIDATION_FAILED',
          `Cannot retire this bus while ${activeTripsCount} upcoming trip(s) use it. Cancel or reassign them first.`,
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

    return this.get(id);
  }

  async bulkMaintenance(
    actor: AuthenticatedUserActor,
    input: BulkMaintenanceDto,
    client: ClientRequestInfo,
  ): Promise<{ updatedCount: number }> {
    const objectIds = input.busIds.map((id) => new Types.ObjectId(id));
    const buses = await this.buses.findMany({ _id: { $in: objectIds }, status: 'ACTIVE' });

    if (buses.length > 0) {
      await this.changes.run({
        actor,
        client,
        action: 'catalogue.status-changed',
        entityType: 'bus',
        before: { count: buses.length },
        apply: async () => {
          await this.connection.collection('buses').updateMany(
            { _id: { $in: buses.map((b) => b._id) } },
            { $set: { status: 'MAINTENANCE', statusReason: input.reason ?? 'Bulk maintenance' } },
          );
          const first = buses[0];
          return { _id: first ? first._id : new Types.ObjectId() };
        },
        describe: () => ({ count: buses.length, action: 'Bulk maintenance' }),
      });
    }

    return { updatedCount: buses.length };
  }

  private async populateViews(buses: StoredBus[]): Promise<AdminBusView[]> {
    if (buses.length === 0) return [];

    const opIds = [...new Set(buses.map((b) => b.operatorId.toHexString()))];
    const typeIds = [...new Set(buses.map((b) => b.busTypeId.toHexString()))];

    const [operators, types] = await Promise.all([
      this.operators.findMany({ _id: { $in: opIds.map((id) => new Types.ObjectId(id)) } }),
      this.connection
        .model('BusType')
        .find({ _id: { $in: typeIds.map((id) => new Types.ObjectId(id)) } })
        .lean<Array<{ _id: Types.ObjectId; name: string }>>()
        .exec(),
    ]);

    const opMap = new Map<string, string>(
      operators.map((o) => [o._id.toHexString(), o.displayName || o.companyName]),
    );
    const typeMap = new Map<string, string>(types.map((t) => [t._id.toHexString(), t.name]));

    return buses.map((b) => ({
      id: b._id.toHexString(),
      operatorId: b.operatorId.toHexString(),
      operatorName: opMap.get(b.operatorId.toHexString()) ?? 'Unknown Operator',
      registrationNumber: b.registrationNumber,
      name: b.name,
      busTypeId: b.busTypeId.toHexString(),
      busTypeName: typeMap.get(b.busTypeId.toHexString()) ?? 'Standard Bus',
      amenities: [...b.amenities],
      seatCapacity: b.seatCapacity ?? 40,
      seatLayoutType: b.seatLayoutType ?? '2+2 Seater',
      activeSeatLayoutVersionId: b.activeSeatLayoutVersionId?.toHexString() ?? null,
      insuranceExpiryDate: b.insuranceExpiryDate ? b.insuranceExpiryDate.toISOString() : null,
      status: b.status,
      statusReason: b.statusReason,
      createdAt: b.createdAt ? b.createdAt.toISOString() : undefined,
    }));
  }

  private async activeBusType(id: string): Promise<Types.ObjectId> {
    const busType = await this.busTypes.findById(id);
    if (!busType?.isActive) {
      throw new ApiException('VALIDATION_FAILED', 'busTypeId is not an active bus type.');
    }
    return busType._id;
  }
}
