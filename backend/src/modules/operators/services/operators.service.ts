import { Injectable } from '@nestjs/common';
import { type Types } from 'mongoose';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { type StoredDocument } from '../../../database/scoped-repository.base';
import { AuditedChangeRunner } from '../../rbac/services/audited-change.service';
import {
  type ChangeOperatorStatusDto,
  type CreateOperatorDto,
  type OperatorListQueryDto,
  type UpdateOperatorDto,
} from '../dto/operator.dto';
import { OperatorRepository } from '../repositories/operator.repository';
import { type Operator, type OperatorStatus } from '../schemas/operator.schema';

export interface OperatorView {
  id: string;
  companyName: string;
  displayName: string | null;
  status: OperatorStatus;
  updatedAt: string | null;
}

/** state-machines.md §Operator. */
const TRANSITIONS: Record<OperatorStatus, readonly OperatorStatus[]> = {
  PENDING_APPROVAL: ['ACTIVE', 'REJECTED'],
  ACTIVE: ['SUSPENDED'],
  SUSPENDED: ['ACTIVE'],
  REJECTED: [],
};

type StoredOperator = StoredDocument<Operator>;

export function operatorViewOf(operator: StoredOperator): OperatorView {
  return {
    id: operator._id.toHexString(),
    companyName: operator.companyName,
    displayName: operator.displayName ?? null,
    status: operator.status,
    updatedAt: operator.updatedAt?.toISOString() ?? null,
  };
}

/** Operators: registration and status by platform staff, profile by the operator itself. */
@Injectable()
export class OperatorsService {
  constructor(
    private readonly operators: OperatorRepository,
    private readonly changes: AuditedChangeRunner,
  ) {}

  async list(query: OperatorListQueryDto): Promise<PaginatedResult<OperatorView>> {
    const filter = query.status ? { status: query.status } : {};
    const [items, total] = await Promise.all([
      this.operators.findMany(filter, {
        sort: { companyName: 1, _id: 1 },
        skip: skipOf(query),
        limit: query.pageSize,
      }),
      this.operators.count(filter),
    ]);
    return new PaginatedResult(items.map(operatorViewOf), query.page, query.pageSize, total);
  }

  async get(id: string): Promise<OperatorView> {
    return operatorViewOf(await this.operators.getById(id));
  }

  /** A new operator awaits approval; its trips cannot be published until it is ACTIVE. */
  async create(
    actor: AuthenticatedUserActor,
    input: CreateOperatorDto,
    client: ClientRequestInfo,
  ): Promise<OperatorView> {
    const created = await this.changes.run({
      actor,
      client,
      action: 'catalogue.created',
      entityType: 'operator',
      before: {},
      apply: (session) =>
        this.operators.insertOne(
          {
            companyName: input.companyName,
            ...(input.displayName ? { displayName: input.displayName } : {}),
            status: 'PENDING_APPROVAL',
          },
          { session },
        ),
      describe: (record) => ({ ...operatorViewOf(record) }),
      operatorIdOf: (record) => record._id,
    });
    return operatorViewOf(created);
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    input: UpdateOperatorDto,
    client: ClientRequestInfo,
  ): Promise<OperatorView> {
    const before = await this.operators.getById(id);
    const set: Partial<Operator> = {};
    const unset: Record<string, ''> = {};
    if (input.companyName !== undefined) set.companyName = input.companyName;
    if (input.displayName === null) unset.displayName = '';
    else if (input.displayName !== undefined) set.displayName = input.displayName;
    if (Object.keys(set).length + Object.keys(unset).length === 0) {
      throw new ApiException('VALIDATION_FAILED', 'Nothing to change.');
    }
    return operatorViewOf(
      await this.apply(actor, client, before, 'catalogue.updated', undefined, {
        ...(Object.keys(set).length > 0 ? { $set: set } : {}),
        ...(Object.keys(unset).length > 0 ? { $unset: unset } : {}),
      }),
    );
  }

  /**
   * Approve, reject, suspend or reactivate. Suspending hides the operator's trips from customer
   * search at once (the search reads the status); nothing else about its trips is changed.
   */
  async changeStatus(
    actor: AuthenticatedUserActor,
    id: string,
    input: ChangeOperatorStatusDto,
    client: ClientRequestInfo,
  ): Promise<OperatorView> {
    const before = await this.operators.getById(id);
    if (!TRANSITIONS[before.status].includes(input.status)) {
      throw new ApiException(
        'INVALID_STATE_TRANSITION',
        `An operator that is ${before.status} cannot become ${input.status}.`,
      );
    }
    return operatorViewOf(
      await this.apply(actor, client, before, 'catalogue.status-changed', input.reason, {
        $set: { status: input.status },
      }),
    );
  }

  private apply(
    actor: AuthenticatedUserActor,
    client: ClientRequestInfo,
    before: StoredOperator,
    action: 'catalogue.updated' | 'catalogue.status-changed',
    reason: string | undefined,
    update: Record<string, unknown>,
  ): Promise<StoredOperator> {
    return this.changes.run({
      actor,
      client,
      action,
      entityType: 'operator',
      before: { ...operatorViewOf(before) },
      reason,
      apply: async (session) => {
        const saved = await this.operators.findOneAndUpdate({ _id: before._id }, update, {
          session,
        });
        if (!saved) throw new ApiException('RESOURCE_NOT_FOUND', 'Record not found');
        return saved;
      },
      describe: (record) => ({ ...operatorViewOf(record) }),
      operatorIdOf: (record): Types.ObjectId => record._id,
    });
  }
}
