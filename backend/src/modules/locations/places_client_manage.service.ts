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
  eventOf,
  existingPlace,
  listPlaceRequests,
  PLACE_REQUEST_MODEL,
  type PlaceRequest,
  placeRequestMatch,
  type PlaceRequestView,
  placeRequestViewOf,
  type StoredPlaceRequest,
} from './places_admin_manage.service';
import {
  type ClientPlaceRequestListQueryDto,
  type CreatePlaceRequestDto,
} from './places_client_manage';

/** A city an operator can ask for a place in. */
export interface PlaceRequestCity {
  id: string;
  name: string;
  state: string;
}

/**
 * The client portal Places page: an operator asks Abra to add a place that is missing, and sees
 * its own requests with their status and the reason of a rejection. Operators see only their own
 * requests; asking for a place that exists already, or that is already asked for, is refused.
 */
@Injectable()
export class PlaceRequestsClientService {
  constructor(
    @InjectModel(PLACE_REQUEST_MODEL) private readonly requests: Model<PlaceRequest>,
    @InjectConnection() private readonly connection: Connection,
    private readonly changes: AuditedChangeRunner,
    private readonly outbox: OutboxService,
  ) {}

  list(
    actor: AuthenticatedUserActor,
    query: ClientPlaceRequestListQueryDto,
  ): Promise<PaginatedResult<PlaceRequestView>> {
    return listPlaceRequests(
      this.requests,
      { ...placeRequestMatch(query), ...this.ownScope(actor) },
      query,
    );
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<PlaceRequestView> {
    const found = Types.ObjectId.isValid(id)
      ? await this.requests
          .findOne({ _id: new Types.ObjectId(id), ...this.ownScope(actor) })
          .lean<StoredPlaceRequest>()
          .exec()
      : null;
    // Another operator's request is "not found", never "forbidden"
    if (!found) throw new ApiException('RESOURCE_NOT_FOUND', 'This request was not found.');
    return placeRequestViewOf(found);
  }

  /** The active cities, for the City field and filter (operators cannot read the admin catalogue). */
  async cities(): Promise<PlaceRequestCity[]> {
    const cities = await this.connection
      .model<{ name: string; state: string; isActive: boolean }>('City')
      .find({ isActive: true })
      .sort({ name: 1 })
      .lean<Array<{ _id: Types.ObjectId; name: string; state: string }>>()
      .exec();
    return cities.map((city) => ({
      id: city._id.toHexString(),
      name: city.name,
      state: city.state,
    }));
  }

  async create(
    actor: AuthenticatedUserActor,
    input: CreatePlaceRequestDto,
    client: ClientRequestInfo,
  ): Promise<PlaceRequestView> {
    assertOperatorStaff(actor);
    const operatorId = operatorForNewRecord(actor, input.operatorId);
    const [operator, city] = await Promise.all([
      this.connection
        .model<{ companyName: string; displayName?: string }>('Operator')
        .findById(operatorId)
        .lean<{ _id: Types.ObjectId; companyName: string; displayName?: string }>()
        .exec(),
      this.connection
        .model<{ name: string; isActive: boolean }>('City')
        .findById(input.cityId)
        .lean<{ _id: Types.ObjectId; name: string; isActive: boolean }>()
        .exec(),
    ]);
    if (!operator) throw new ApiException('RESOURCE_NOT_FOUND', 'Operator not found');
    if (!city?.isActive) {
      throw new ApiException('VALIDATION_FAILED', 'Choose one of the cities in the list.');
    }
    if (await existingPlace(this.connection, city._id, input.name)) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `This place already exists in ${city.name}. You can use it now.`,
      );
    }
    const waiting = await this.requests
      .exists({
        cityId: city._id,
        status: 'PENDING',
        name: new RegExp(`^${escapeRegExp(input.name)}$`, 'i'),
      })
      .exec();
    if (waiting) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'This place has already been asked for. Abra is checking it.',
      );
    }

    const created = await this.changes.run<StoredPlaceRequest>({
      actor,
      client,
      action: 'place-request.created',
      entityType: 'place_request',
      before: {},
      operatorIdOf: (record) => record.operatorId,
      apply: async (session) => {
        const [request] = await this.requests.create(
          [
            {
              operatorId,
              operatorName: operator.displayName ?? operator.companyName,
              cityId: city._id,
              cityName: city.name,
              name: input.name,
              address: input.address,
              ...(input.landmark ? { landmark: input.landmark } : {}),
              status: 'PENDING',
              requestedBy: new Types.ObjectId(actor.userId),
            },
          ],
          { session },
        );
        if (!request) throw new Error('The request was not created');
        const stored = request.toObject() as StoredPlaceRequest;
        await this.outbox.record(eventOf('place-request.created', stored), session);
        return stored;
      },
      describe: (record) => ({ name: record.name, city: record.cityName, status: record.status }),
    });
    return placeRequestViewOf(created);
  }

  /** Operator staff see the requests of the operators in their scope only. */
  private ownScope(actor: AuthenticatedUserActor): QueryFilter<PlaceRequest> {
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
      'Place requests are sent from the operator portal. Abra staff decide them on the Cities and places page.',
    );
  }
}
