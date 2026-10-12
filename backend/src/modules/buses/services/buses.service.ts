import { Injectable } from '@nestjs/common';
import { Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { rejectDuplicates } from '../../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../../common/pipes/list-query';
import { operatorForNewRecord } from '../../../common/request-context/operator-scope';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { BusTypeRepository } from '../../bus-types/repositories/bus-type.repository';
import { OperatorRepository } from '../../operators/repositories/operator.repository';
import { AuditedChangeRunner } from '../../rbac/services/audited-change.service';
import {
  type BusListQueryDto,
  type ChangeBusStatusDto,
  type CreateBusDto,
  type UpdateBusDto,
} from '../dto/bus.dto';
import { BusRepository, type StoredBus } from '../repositories/bus.repository';
import { type Bus, type BusStatus } from '../schemas/bus.schema';

export interface BusView {
  id: string;
  operatorId: string;
  registrationNumber: string;
  name: string;
  busTypeId: string;
  amenities: string[];
  seatCapacity: number | null;
  /** Reference to the seat layout in use; null until seat layouts exist. */
  activeSeatLayoutVersionId: string | null;
  status: BusStatus;
}

export function busViewOf(bus: StoredBus): BusView {
  return {
    id: bus._id.toHexString(),
    operatorId: bus.operatorId.toHexString(),
    registrationNumber: bus.registrationNumber,
    name: bus.name,
    busTypeId: bus.busTypeId.toHexString(),
    amenities: [...bus.amenities],
    seatCapacity: bus.seatCapacity ?? null,
    activeSeatLayoutVersionId: bus.activeSeatLayoutVersionId?.toHexString() ?? null,
    status: bus.status,
  };
}

/** An operator's vehicles. */
@Injectable()
export class BusesService {
  constructor(
    private readonly buses: BusRepository,
    private readonly busTypes: BusTypeRepository,
    private readonly operators: OperatorRepository,
    private readonly changes: AuditedChangeRunner,
  ) {}

  async list(query: BusListQueryDto): Promise<PaginatedResult<BusView>> {
    const filter = {
      ...(query.operatorId ? { operatorId: new Types.ObjectId(query.operatorId) } : {}),
      ...(query.status ? { status: query.status } : {}),
    };
    const [items, total] = await Promise.all([
      this.buses.findMany(filter, {
        sort: { name: 1, _id: 1 },
        skip: skipOf(query),
        limit: query.pageSize,
      }),
      this.buses.count(filter),
    ]);
    return new PaginatedResult(items.map(busViewOf), query.page, query.pageSize, total);
  }

  async get(id: string): Promise<BusView> {
    return busViewOf(await this.buses.getById(id));
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateBusDto,
    client: ClientRequestInfo,
  ): Promise<BusView> {
    const operatorId = operatorForNewRecord(actor, input.operatorId);
    // Scoped read: an operator outside the caller's scope does not exist for them
    await this.operators.getById(operatorId.toHexString());
    const busTypeId = await this.activeBusType(input.busTypeId);
    const created = await rejectDuplicates(
      'A bus with this registration number already exists.',
      () =>
        this.changes.run({
          actor,
          client,
          action: 'catalogue.created',
          entityType: 'bus',
          before: {},
          apply: (session) =>
            this.buses.insertOne(
              {
                operatorId,
                registrationNumber: input.registrationNumber,
                name: input.name,
                busTypeId,
                amenities: input.amenities,
                seatCapacity: input.seatCapacity,
                // A bus owner's new bus waits for its documents to be approved; platform staff
                // add buses they have already checked
                status: actor.userType === 'STAFF' ? 'ACTIVE' : 'PENDING_APPROVAL',
              },
              { session },
            ),
          describe: (record) => ({ ...busViewOf(record) }),
          operatorIdOf: (record) => record.operatorId,
        }),
    );
    return busViewOf(created);
  }

  /** The registration number and the operator cannot be changed. */
  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateBusDto,
    client: ClientRequestInfo,
  ): Promise<BusView> {
    const before = await this.buses.getById(id);
    const set: Partial<Bus> = {};
    if (input.name !== undefined) set.name = input.name;
    if (input.amenities !== undefined) set.amenities = input.amenities;
    if (input.seatCapacity !== undefined) set.seatCapacity = input.seatCapacity;
    if (input.busTypeId !== undefined) set.busTypeId = await this.activeBusType(input.busTypeId);
    if (Object.keys(set).length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }
    return busViewOf(await this.save(actor, client, before, 'catalogue.updated', set));
  }

  /** ACTIVE, MAINTENANCE or RETIRED. Only an ACTIVE bus can have a trip published. */
  async changeStatus(
    actor: AuthenticatedUserActor,
    id: string,
    input: ChangeBusStatusDto,
    client: ClientRequestInfo,
  ): Promise<BusView> {
    const before = await this.buses.getById(id);
    if (before.status === input.status) return busViewOf(before);
    if (before.status === 'PENDING_APPROVAL' && actor.userType !== 'STAFF') {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        'This bus is waiting for its documents to be approved. Platform staff approve it.',
      );
    }
    if (before.status === 'RETIRED') {
      throw new ApiException('INVALID_STATE_TRANSITION', 'A retired bus cannot be put back.');
    }
    return busViewOf(
      await this.save(
        actor,
        client,
        before,
        'catalogue.status-changed',
        { status: input.status },
        input.reason,
      ),
    );
  }

  private async activeBusType(id: string): Promise<Types.ObjectId> {
    const busType = await this.busTypes.findById(id);
    if (!busType?.isActive) {
      throw new ApiException('VALIDATION_FAILED', 'busTypeId is not an active bus type.');
    }
    return busType._id;
  }

  private save(
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    before: StoredBus,
    action: 'catalogue.updated' | 'catalogue.status-changed',
    set: Partial<Bus>,
    reason?: string,
  ): Promise<StoredBus> {
    return this.changes.run({
      actor,
      client,
      action,
      entityType: 'bus',
      before: { ...busViewOf(before) },
      reason,
      apply: async (session) => {
        const saved = await this.buses.findOneAndUpdate(
          { _id: before._id },
          { $set: set },
          { session },
        );
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Record not found');
        return saved;
      },
      describe: (record) => ({ ...busViewOf(record) }),
      operatorIdOf: (record) => record.operatorId,
    });
  }
}
