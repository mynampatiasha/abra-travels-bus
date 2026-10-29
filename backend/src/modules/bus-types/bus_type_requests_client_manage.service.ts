import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type Model, type QueryFilter, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { type PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { escapeRegExp } from '../../common/pipes/list-query';
import { operatorForNewRecord } from '../../common/request-context/operator-scope';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { OutboxService } from '../../events/outbox.service';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';
import {
  BUS_TYPE_REQUEST_MODEL,
  type BusTypeRequest,
  busTypeRequestEventOf,
  busTypeRequestMatch,
  type BusTypeRequestView,
  busTypeRequestViewOf,
  existingBusType,
  listBusTypeRequests,
  type StoredBusTypeRequest,
} from './bus_type_requests_admin_manage.service';
import {
  type ClientBusTypeRequestListQueryDto,
  type CreateBusTypeRequestDto,
} from './bus_type_requests_client_manage';

/**
 * The client portal "My bus type isn't listed" request: an operator asks Abra to add a kind of bus
 * and sees its own requests with their status and the reason of a rejection. Operators see only
 * their own requests; asking for a bus type that exists already, or that is already asked for, is
 * refused.
 */
@Injectable()
export class BusTypeRequestsClientService {
  constructor(
    @InjectModel(BUS_TYPE_REQUEST_MODEL) private readonly requests: Model<BusTypeRequest>,
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
    private readonly outbox: OutboxService,
  ) {}

  list(
    actor: AuthenticatedUserActor,
    query: ClientBusTypeRequestListQueryDto,
  ): Promise<PaginatedResult<BusTypeRequestView>> {
    return listBusTypeRequests(
      this.requests,
      { ...busTypeRequestMatch(query), ...this.ownScope(actor) },
      query,
    );
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<BusTypeRequestView> {
    const found = Types.ObjectId.isValid(id)
      ? await this.requests
          .findOne({ _id: new Types.ObjectId(id), ...this.ownScope(actor) })
          .lean<StoredBusTypeRequest>()
          .exec()
      : null;
    // Another operator's request is "not found", never "forbidden"
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'This request was not found.');
    return busTypeRequestViewOf(found);
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreateBusTypeRequestDto,
    client: ClientRequestInfo,
  ): Promise<BusTypeRequestView> {
    assertOperatorStaff(actor);
    const operatorId = operatorForNewRecord(actor, input.operatorId);
    const operator = await this.connection
      .model<{ companyName: string; displayName?: string }>('Operator')
      .findById(operatorId)
      .lean<{ _id: Types.ObjectId; companyName: string; displayName?: string }>()
      .exec();
    if (!operator) throw new ApiException('RESOURCE_NOT_FOUND', 'Operator not found');
    if (await existingBusType(this.connection, input.name)) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `A bus type named "${input.name}" already exists. You can use it now.`,
      );
    }
    const waiting = await this.requests
      .exists({
        status: 'PENDING',
        name: new RegExp(`^${escapeRegExp(input.name)}$`, 'i'),
      })
      .exec();
    if (waiting) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'This bus type has already been asked for. Abra is checking it.',
      );
    }

    const created = await this.changes.run<StoredBusTypeRequest>({
      actor,
      client,
      action: 'bus-type-request.created',
      entityType: 'bus_type_request',
      before: {},
      operatorIdOf: (record) => record.operatorId,
      apply: async (session) => {
        const [request] = await this.requests.create(
          [
            {
              operatorId,
              operatorName: operator.displayName ?? operator.companyName,
              name: input.name,
              isAc: input.isAc,
              berthType: input.berthType,
              status: 'PENDING',
              requestedBy: new Types.ObjectId(actor.userId),
            },
          ],
          { session },
        );
        if (!request) throw new Error('The request was not created');
        const stored = request.toObject() as StoredBusTypeRequest;
        await this.outbox.record(busTypeRequestEventOf('bus-type-request.created', stored), session);
        return stored;
      },
      describe: (record) => ({
        name: record.name,
        isAc: record.isAc,
        berthType: record.berthType,
        status: record.status,
      }),
    });
    return busTypeRequestViewOf(created);
  }

  /** Operator staff see the requests of the operators in their scope only. */
  private ownScope(actor: AuthenticatedUserActor): QueryFilter<BusTypeRequest> {
    assertOperatorStaff(actor);
    return {
      operatorId: { $in: actor.dataScope.operatorIds.map((id) => new Types.ObjectId(id)) },
    };
  }
}

function assertOperatorStaff(actor: AuthenticatedUserActor): void {
  if (actor.userType !== 'OPERATOR_STAFF' || actor.dataScope.type === 'ALL') {
    throw new ApiException(
      'PERMISSION_DENIED',
      'Bus type requests are sent from the operator portal. Abra staff decide them on the Bus types page.',
    );
  }
}
