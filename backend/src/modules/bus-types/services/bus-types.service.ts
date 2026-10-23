import { Injectable, Logger, type OnApplicationBootstrap } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Connection } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { rejectDuplicates } from '../../../common/errors/duplicate-key';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../../rbac/services/audited-change.service';
import {
  type BusTypeListQueryDto,
  type CreateBusTypeDto,
  type UpdateBusTypeDto,
} from '../dto/bus-type.dto';
import { BusTypeRepository, type StoredBusType } from '../repositories/bus-type.repository';
import { type BusType } from '../schemas/bus-type.schema';

export interface BusTypeView {
  id: string;
  key: string;
  name: string;
  isAc: boolean;
  berthType: string;
  isActive: boolean;
}

export function busTypeViewOf(busType: StoredBusType): BusTypeView {
  return {
    id: busType._id.toHexString(),
    key: busType.key,
    name: busType.name,
    isAc: busType.isAc,
    berthType: busType.berthType,
    isActive: busType.isActive,
  };
}

/**
 * The standard kinds of bus, built from AC or not and the berth (as bus booking sites show them),
 * so every operator can describe any bus without waiting for an admin to add a type.
 */
export const STANDARD_BUS_TYPES: ReadonlyArray<Pick<BusType, 'key' | 'name' | 'isAc' | 'berthType'>> = [
  { key: 'AC_SEATER', name: 'AC Seater', isAc: true, berthType: 'SEATER' },
  { key: 'NON_AC_SEATER', name: 'Non-AC Seater', isAc: false, berthType: 'SEATER' },
  { key: 'AC_SLEEPER', name: 'AC Sleeper', isAc: true, berthType: 'SLEEPER' },
  { key: 'NON_AC_SLEEPER', name: 'Non-AC Sleeper', isAc: false, berthType: 'SLEEPER' },
  { key: 'AC_SEMI_SLEEPER', name: 'AC Semi-sleeper', isAc: true, berthType: 'SEMI_SLEEPER' },
  { key: 'NON_AC_SEMI_SLEEPER', name: 'Non-AC Semi-sleeper', isAc: false, berthType: 'SEMI_SLEEPER' },
  { key: 'AC_SEATER_SLEEPER', name: 'AC Seater + Sleeper', isAc: true, berthType: 'MIXED' },
  { key: 'NON_AC_SEATER_SLEEPER', name: 'Non-AC Seater + Sleeper', isAc: false, berthType: 'MIXED' },
];

/** The kinds of bus operators can register and customers can filter by. */
@Injectable()
export class BusTypesService implements OnApplicationBootstrap {
  private readonly logger = new Logger(BusTypesService.name);

  constructor(
    private readonly busTypes: BusTypeRepository,
    private readonly changes: AuditedChangeRunner,
    @InjectConnection() private readonly connection: Connection,
  ) {}

  /** Adds any standard bus type that is missing (an admin's renames, switch-offs and deletes are kept). */
  async onApplicationBootstrap(): Promise<void> {
    const collection = this.connection.collection('bus_types');
    let added = 0;
    for (const type of STANDARD_BUS_TYPES) {
      const result = await collection.updateOne(
        { key: type.key },
        { $setOnInsert: { ...type, isActive: true, createdAt: new Date(), updatedAt: new Date() } },
        { upsert: true },
      );
      added += result.upsertedCount;
    }
    this.logger.log({ added }, 'Standard bus types ready');
  }

  async list(query: BusTypeListQueryDto): Promise<PaginatedResult<BusTypeView>> {
    const { items, total } = await this.busTypes.list(
      { active: query.active },
      { skip: skipOf(query), limit: query.pageSize },
    );
    return new PaginatedResult(items.map(busTypeViewOf), query.page, query.pageSize, total);
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateBusTypeDto,
    client: ClientRequestInfo,
  ): Promise<BusTypeView> {
    const created = await rejectDuplicates('A bus type with this key already exists.', () =>
      this.changes.run({
        actor,
        client,
        action: 'catalogue.created',
        entityType: 'bus_type',
        before: {},
        apply: (session) => this.busTypes.insert({ ...input, isActive: true }, session),
        describe: (record) => ({ ...busTypeViewOf(record) }),
      }),
    );
    return busTypeViewOf(created);
  }

  /** Buses and trips already using the type keep the values copied when they were saved. */
  async update(
    actor: AuthenticatedUserActor,
    id: string,
    change: UpdateBusTypeDto & { isActive?: boolean },
    client: ClientRequestInfo,
  ): Promise<BusTypeView> {
    const before = await this.busTypes.findById(id);
    if (!before) throw new ApiException('RESOURCE_NOT_FOUND', 'Bus type not found');
    const set: Partial<BusType> = {
      ...(change.name !== undefined ? { name: change.name } : {}),
      ...(change.isAc !== undefined ? { isAc: change.isAc } : {}),
      ...(change.berthType !== undefined ? { berthType: change.berthType } : {}),
      ...(change.isActive !== undefined ? { isActive: change.isActive } : {}),
    };
    if (Object.keys(set).length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }
    const updated = await this.changes.run({
      actor,
      client,
      action: change.isActive === undefined ? 'catalogue.updated' : 'catalogue.status-changed',
      entityType: 'bus_type',
      before: { ...busTypeViewOf(before) },
      apply: async (session) => {
        const saved = await this.busTypes.update(before._id, set, session);
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Bus type not found');
        return saved;
      },
      describe: (record) => ({ ...busTypeViewOf(record) }),
    });
    return busTypeViewOf(updated);
  }
}
