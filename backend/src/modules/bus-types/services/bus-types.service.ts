import { Injectable } from '@nestjs/common';
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

/** The kinds of bus operators can register and customers can filter by. */
@Injectable()
export class BusTypesService {
  constructor(
    private readonly busTypes: BusTypeRepository,
    private readonly changes: AuditedChangeRunner,
  ) {}

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
