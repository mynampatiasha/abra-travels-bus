import { Injectable } from '@nestjs/common';
import { InjectConnection, InjectModel } from '@nestjs/mongoose';
import { type Connection, type HydratedDocument, type Model, Types } from 'mongoose';
import { type StoredDocument } from '../../database/scoped-repository.base';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { skipOf } from '../../common/pipes/list-query';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuditedChangeRunner } from '../rbac/services/audited-change.service';

export const FARE_MODEL = 'Fare';

export interface ClientFare {
  operatorId: Types.ObjectId;
  routeId: Types.ObjectId;
  route: string;
  seatType: string;
  weekday: number;
  weekend: number;
  festival: number;
  from: string;
  status: 'ACTIVE' | 'INACTIVE';
  version?: number;
  fareRuleSetVersionId?: Types.ObjectId;
  isDeleted: boolean;
  deletedAt?: Date;
  createdAt?: Date;
  updatedAt?: Date;
}

export type StoredFareDoc = StoredDocument<ClientFare>;
export type FareHydratedDoc = HydratedDocument<ClientFare>;

export interface CustomerPayBreakdown {
  fare: number;
  cm: number;
  gst: number;
  fee: number;
  total: number;
}

export interface ClientFareView {
  id: string;
  operatorId: string;
  routeId: string;
  route: string;
  seatType: string;
  weekday: number;
  weekend: number;
  festival: number;
  from: string;
  status: 'ACTIVE' | 'INACTIVE';
  version: number;
  fareRuleSetVersionId: string;
  customerPaysWeekday: CustomerPayBreakdown;
  createdAt?: string;
  updatedAt?: string;
}

export interface CreateClientFareInput {
  routeId: string;
  seatType: string;
  weekday: number;
  weekend: number;
  festival: number;
  from: string;
  status?: 'ACTIVE' | 'INACTIVE';
}

export interface UpdateClientFareInput {
  routeId?: string;
  seatType?: string;
  weekday?: number;
  weekend?: number;
  festival?: number;
  from?: string;
  status?: 'ACTIVE' | 'INACTIVE';
}

export interface ClientFareQueryInput {
  routeId?: string;
  status?: string;
  search?: string;
  page?: number;
  pageSize?: number;
}

export function calculateCustomerPays(fareInPaise: number): CustomerPayBreakdown {
  const cm = Math.round((fareInPaise * 800) / 10000); // 8% commission
  const gst = Math.round((fareInPaise + cm) * 0.05); // 5% GST
  const fee = 500; // Rs 5 convenience fee
  const total = fareInPaise + cm + gst + fee;
  return { fare: fareInPaise, cm, gst, fee, total };
}

@Injectable()
export class FaresClientManageService {
  constructor(
    @InjectModel(FARE_MODEL) private readonly fareModel: Model<ClientFare>,
    @InjectConnection() private readonly connection: Connection,
    private readonly auditedChanges: AuditedChangeRunner,
  ) {}

  private toView(fare: StoredFareDoc): ClientFareView {
    return {
      id: fare._id.toString(),
      operatorId: fare.operatorId.toString(),
      routeId: fare.routeId.toString(),
      route: fare.route,
      seatType: fare.seatType,
      weekday: fare.weekday,
      weekend: fare.weekend,
      festival: fare.festival,
      from: fare.from,
      status: fare.status,
      version: fare.version ?? 1,
      fareRuleSetVersionId: (fare.fareRuleSetVersionId ?? fare._id).toString(),
      customerPaysWeekday: calculateCustomerPays(fare.weekday),
      createdAt: fare.createdAt ? fare.createdAt.toISOString() : undefined,
      updatedAt: fare.updatedAt ? fare.updatedAt.toISOString() : undefined,
    };
  }

  /** The seat type of a fare is the name of a bus type; only real, active bus types can be priced. */
  private async assertRealBusType(seatType: string): Promise<void> {
    const found = await this.connection.collection('bus_types').countDocuments({
      name: seatType,
      isActive: true,
      isDeleted: { $ne: true },
    });
    if (found === 0) {
      throw new ApiException(
        'VALIDATION_FAILED',
        `"${seatType}" is not an active bus type. Pick one from the list of bus types.`,
      );
    }
  }

  private async assertNoActiveDuplicate(
    operatorId: Types.ObjectId,
    routeId: Types.ObjectId,
    seatType: string,
    excludeId?: Types.ObjectId,
  ): Promise<void> {
    const existing = await this.fareModel.findOne({
      ...(excludeId ? { _id: { $ne: excludeId } } : {}),
      operatorId,
      routeId,
      seatType,
      status: 'ACTIVE',
      isDeleted: { $ne: true },
    }).lean<StoredFareDoc>().exec();

    if (existing) {
      throw new ApiException(
        'VALIDATION_FAILED',
        'An active fare already exists for this route and seat type. Edit that one.',
      );
    }
  }

  private validateFares(weekday: number, weekend: number, festival: number): void {
    if (weekday < 10000) {
      throw new ApiException('VALIDATION_FAILED', 'At least Rs 100');
    }
    if (weekend < weekday * 0.5) {
      throw new ApiException('VALIDATION_FAILED', 'Too low compared with weekday');
    }
    if (festival < 10000) {
      throw new ApiException('VALIDATION_FAILED', 'At least Rs 100');
    }
  }

  async list(actor: AuthenticatedUserActor, query: ClientFareQueryInput): Promise<PaginatedResult<ClientFareView>> {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }
    const operatorId = new Types.ObjectId(actor.operatorId);
    const filter: Record<string, unknown> = {
      operatorId,
      isDeleted: { $ne: true },
    };

    if (query.routeId && Types.ObjectId.isValid(query.routeId)) {
      filter.routeId = new Types.ObjectId(query.routeId);
    }

    if (query.status && query.status !== 'ALL') {
      filter.status = query.status.toUpperCase();
    }

    if (query.search && query.search.trim().length > 0) {
      const s = query.search.trim();
      filter.$or = [
        { route: { $regex: s, $options: 'i' } },
        { seatType: { $regex: s, $options: 'i' } },
      ];
    }

    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.min(100, Math.max(1, query.pageSize ?? 50));
    const skip = skipOf({ page, pageSize });

    const [total, fares] = await Promise.all([
      this.fareModel.countDocuments(filter).exec(),
      this.fareModel.find(filter).sort({ createdAt: -1 }).skip(skip).limit(pageSize).lean<StoredFareDoc[]>().exec(),
    ]);

    const items = fares.map((f) => this.toView(f));
    return new PaginatedResult(items, page, pageSize, total);
  }

  async get(actor: AuthenticatedUserActor, id: string): Promise<ClientFareView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid fare ID');
    }
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }

    const fare = await this.fareModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
      isDeleted: { $ne: true },
    }).lean<StoredFareDoc>().exec();

    if (!fare) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Fare not found');
    }

    return this.toView(fare);
  }

  async create(actor: AuthenticatedUserActor, input: CreateClientFareInput, info: ClientRequestInfo): Promise<ClientFareView> {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }
    if (!Types.ObjectId.isValid(input.routeId)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid route ID');
    }

    this.validateFares(input.weekday, input.weekend, input.festival);

    const operatorId = new Types.ObjectId(actor.operatorId);
    const routeId = new Types.ObjectId(input.routeId);
    const status = input.status ?? 'ACTIVE';

    await this.assertRealBusType(input.seatType);
    if (status === 'ACTIVE') {
      await this.assertNoActiveDuplicate(operatorId, routeId, input.seatType);
    }

    const routeDoc = await this.connection.collection('routes').findOne({ _id: routeId });
    const routeName = (routeDoc && typeof routeDoc['name'] === 'string') ? routeDoc['name'] : 'General Route';

    const fareRuleSetVersionId = new Types.ObjectId();

    const created = await this.auditedChanges.run<FareHydratedDoc>({
      actor,
      client: info,
      action: 'fare.created',
      entityType: 'fare',
      before: {},
      apply: async (session) => {
        const docs = await this.fareModel.create(
          [
            {
              operatorId,
              routeId,
              route: routeName,
              seatType: input.seatType,
              weekday: input.weekday,
              weekend: input.weekend,
              festival: input.festival,
              from: input.from,
              status,
              version: 1,
              fareRuleSetVersionId,
              isDeleted: false,
            },
          ],
          { session },
        );
        const doc = docs[0];
        if (!doc) {
          throw new ApiException('INTERNAL_ERROR', 'Failed to create fare');
        }

        await this.connection.collection('fare_versions').insertOne(
          {
            _id: fareRuleSetVersionId,
            fareId: doc._id,
            operatorId: doc.operatorId,
            routeId: doc.routeId,
            route: doc.route,
            seatType: doc.seatType,
            weekday: doc.weekday,
            weekend: doc.weekend,
            festival: doc.festival,
            from: doc.from,
            version: 1,
            createdAt: new Date(),
          },
          { session },
        );

        return doc;
      },
      describe: (record) => ({ id: record._id.toHexString(), route: record.route, seatType: record.seatType, version: 1 }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(created.toObject());
  }

  async update(actor: AuthenticatedUserActor, id: string, input: UpdateClientFareInput, info: ClientRequestInfo): Promise<ClientFareView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid fare ID');
    }
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }

    const fare = await this.fareModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
      isDeleted: { $ne: true },
    }).exec();

    if (!fare) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Fare not found');
    }

    const weekday = input.weekday ?? fare.weekday;
    const weekend = input.weekend ?? fare.weekend;
    const festival = input.festival ?? fare.festival;
    this.validateFares(weekday, weekend, festival);

    const seatType = input.seatType ?? fare.seatType;
    const routeId = input.routeId ? new Types.ObjectId(input.routeId) : fare.routeId;
    const status = input.status ?? fare.status;

    if (input.seatType !== undefined && input.seatType !== fare.seatType) {
      await this.assertRealBusType(seatType);
    }
    if (status === 'ACTIVE') {
      await this.assertNoActiveDuplicate(fare.operatorId, routeId, seatType, fare._id);
    }

    let routeName = fare.route;
    if (input.routeId && input.routeId !== fare.routeId.toString()) {
      const routeDoc = await this.connection.collection('routes').findOne({ _id: routeId });
      routeName = (routeDoc && typeof routeDoc['name'] === 'string') ? routeDoc['name'] : fare.route;
    }

    const nextVersion = (fare.version ?? 1) + 1;
    const nextVersionId = new Types.ObjectId();

    const updated = await this.auditedChanges.run<FareHydratedDoc>({
      actor,
      client: info,
      action: 'fare.updated',
      entityType: 'fare',
      before: { id: fare._id.toHexString(), route: fare.route, weekday: fare.weekday, version: fare.version ?? 1 },
      apply: async (session) => {
        fare.routeId = routeId;
        fare.route = routeName;
        fare.seatType = seatType;
        fare.weekday = weekday;
        fare.weekend = weekend;
        fare.festival = festival;
        if (input.from) {
          fare.from = input.from;
        }
        fare.status = status;
        fare.version = nextVersion;
        fare.fareRuleSetVersionId = nextVersionId;
        await fare.save({ session });

        await this.connection.collection('fare_versions').insertOne(
          {
            _id: nextVersionId,
            fareId: fare._id,
            operatorId: fare.operatorId,
            routeId: fare.routeId,
            route: routeName,
            seatType,
            weekday,
            weekend,
            festival,
            from: input.from ?? fare.from,
            version: nextVersion,
            createdAt: new Date(),
          },
          { session },
        );

        return fare;
      },
      describe: (record) => ({ id: record._id.toHexString(), route: record.route, seatType: record.seatType, version: nextVersion }),
      operatorIdOf: (record) => record.operatorId,
    });

    return this.toView(updated.toObject());
  }

  async deleteFare(actor: AuthenticatedUserActor, id: string, info: ClientRequestInfo): Promise<{ success: boolean }> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('VALIDATION_FAILED', 'Invalid fare ID');
    }
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator ID required');
    }

    const fare = await this.fareModel.findOne({
      _id: new Types.ObjectId(id),
      operatorId: new Types.ObjectId(actor.operatorId),
      isDeleted: { $ne: true },
    }).exec();

    if (!fare) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Fare not found');
    }

    await this.auditedChanges.run<FareHydratedDoc>({
      actor,
      client: info,
      action: 'fare.deleted',
      entityType: 'fare',
      before: { id: fare._id.toHexString(), route: fare.route },
      apply: async () => {
        fare.isDeleted = true;
        fare.deletedAt = new Date();
        await fare.save();
        return fare;
      },
      describe: (record) => ({ id: record._id.toHexString(), route: record.route }),
      operatorIdOf: (record) => record.operatorId,
    });

    return { success: true };
  }
}
