import { Injectable } from '@nestjs/common';
import { InjectModel, InjectConnection } from '@nestjs/mongoose';
import { Model, Connection, Types } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../common/http/client-request-info';
import { PaginatedResult } from '../../common/interceptors/response-envelope.interceptor';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';

export const CREW_ROLES = ['DRIVER', 'CONDUCTOR', 'MANAGER'] as const;
export type CrewRole = (typeof CREW_ROLES)[number];

export const CREW_STATUSES = ['ACTIVE', 'ON_LEAVE', 'INACTIVE'] as const;
export type CrewStatus = (typeof CREW_STATUSES)[number];

export interface OperatorCrewDocument {
  _id: Types.ObjectId;
  operatorId: Types.ObjectId;
  name: string;
  role: CrewRole;
  phone: string;
  licenseNumber?: string;
  licenseExpiryDate?: Date;
  badgeNumber?: string;
  status: CrewStatus;
  userId?: Types.ObjectId;
  isDeleted?: boolean;
  deletedAt?: Date;
  createdAt: Date;
  updatedAt: Date;
}

export interface ClientCrewView {
  id: string;
  operatorId: string;
  name: string;
  role: CrewRole;
  phone: string;
  licenseNumber?: string;
  licenseExpiryDate?: string;
  badgeNumber?: string;
  status: CrewStatus;
  isLicenceExpired?: boolean;
  isLicenceExpiringSoon?: boolean;
  tripsCount7Days?: number;
  createdAt?: string;
  updatedAt?: string;
}

export interface ClientCrewKpis {
  totalDrivers: number;
  totalActive: number;
  totalOnLeave: number;
  expiringLicences30Days: number;
}

export interface CrewListQueryInput {
  role?: string;
  status?: string;
  search?: string;
  page?: number;
  pageSize?: number;
}

export interface CreateCrewInput {
  name: string;
  role: CrewRole;
  phone: string;
  licenseNumber?: string;
  licenseExpiryDate?: string;
  badgeNumber?: string;
  status?: CrewStatus;
}

export interface UpdateCrewInput {
  name?: string;
  role?: CrewRole;
  phone?: string;
  licenseNumber?: string;
  licenseExpiryDate?: string;
  badgeNumber?: string;
  status?: CrewStatus;
}

@Injectable()
export class CrewClientManageService {
  constructor(
    @InjectModel('operator_crew')
    private readonly crewModel: Model<OperatorCrewDocument>,
    @InjectConnection()
    private readonly connection: Connection,
  ) {}

  private toView(
    doc: OperatorCrewDocument,
    tripsCount7Days?: number,
  ): ClientCrewView {
    const now = new Date();
    const in30Days = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    let isLicenceExpired = false;
    let isLicenceExpiringSoon = false;

    const expiryDate = doc.licenseExpiryDate ? new Date(doc.licenseExpiryDate) : undefined;
    if (expiryDate && !isNaN(expiryDate.getTime())) {
      if (expiryDate.getTime() < now.getTime()) {
        isLicenceExpired = true;
      } else if (expiryDate.getTime() <= in30Days.getTime()) {
        isLicenceExpiringSoon = true;
      }
    }

    return {
      id: doc._id.toString(),
      operatorId: doc.operatorId.toString(),
      name: doc.name,
      role: doc.role,
      phone: doc.phone,
      licenseNumber: doc.licenseNumber,
      licenseExpiryDate: expiryDate ? expiryDate.toISOString().split('T')[0] : undefined,
      badgeNumber: doc.badgeNumber,
      status: doc.status,
      isLicenceExpired,
      isLicenceExpiringSoon,
      tripsCount7Days,
      createdAt: doc.createdAt?.toISOString(),
      updatedAt: doc.updatedAt?.toISOString(),
    };
  }

  async kpis(actor: AuthenticatedUserActor): Promise<ClientCrewKpis> {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator identification missing from session actor');
    }

    const opId = new Types.ObjectId(actor.operatorId);
    const now = new Date();
    const in30Days = new Date(now.getTime() + 30 * 24 * 60 * 60 * 1000);

    const [totalDrivers, totalActive, totalOnLeave, expiringLicences30Days] = await Promise.all([
      this.crewModel.countDocuments({
        operatorId: opId,
        role: 'DRIVER',
        isDeleted: { $ne: true },
      }),
      this.crewModel.countDocuments({
        operatorId: opId,
        status: 'ACTIVE',
        isDeleted: { $ne: true },
      }),
      this.crewModel.countDocuments({
        operatorId: opId,
        status: 'ON_LEAVE',
        isDeleted: { $ne: true },
      }),
      this.crewModel.countDocuments({
        operatorId: opId,
        role: 'DRIVER',
        isDeleted: { $ne: true },
        licenseExpiryDate: { $gte: now, $lte: in30Days },
      }),
    ]);

    return { totalDrivers, totalActive, totalOnLeave, expiringLicences30Days };
  }

  async list(
    actor: AuthenticatedUserActor,
    query: CrewListQueryInput,
  ): Promise<PaginatedResult<ClientCrewView> & { kpis: ClientCrewKpis }> {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator identification missing from session actor');
    }

    const opId = new Types.ObjectId(actor.operatorId);
    const filter: Record<string, unknown> = {
      operatorId: opId,
      isDeleted: { $ne: true },
    };

    if (query.role && query.role !== 'ALL') {
      filter.role = query.role.toUpperCase();
    }
    if (query.status && query.status !== 'ALL') {
      filter.status = query.status.toUpperCase();
    }
    if (query.search && query.search.trim().length > 0) {
      const s = query.search.trim();
      filter.$or = [
        { name: { $regex: s, $options: 'i' } },
        { phone: { $regex: s, $options: 'i' } },
        { licenseNumber: { $regex: s, $options: 'i' } },
      ];
    }

    const page = Math.max(1, query.page ?? 1);
    const pageSize = Math.min(100, Math.max(1, query.pageSize ?? 20));
    const skip = (page - 1) * pageSize;

    const [items, total, kpisResult] = await Promise.all([
      this.crewModel.find(filter).sort({ createdAt: -1 }).skip(skip).limit(pageSize).exec(),
      this.crewModel.countDocuments(filter).exec(),
      this.kpis(actor),
    ]);

    const views = items.map((doc) => this.toView(doc));
    const result = new PaginatedResult(views, page, pageSize, total);
    return Object.assign(result, { kpis: kpisResult });
  }

  async findById(actor: AuthenticatedUserActor, id: string): Promise<ClientCrewView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Crew record with ID ' + id + ' not found');
    }

    const doc = await this.crewModel.findById(id).exec();
    if (!doc || doc.isDeleted) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Crew record with ID ' + id + ' not found');
    }

    if (actor.operatorId && doc.operatorId.toString() !== actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Cannot access crew belonging to another operator');
    }

    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    let tripsCount7Days = 0;
    try {
      const tripsColl = this.connection.collection('trips');
      tripsCount7Days = await tripsColl.countDocuments({
        $or: [
          { driverIds: doc._id },
          { 'bus.driverId': doc._id },
          { driverId: doc._id },
          { conductorIds: doc._id },
        ],
        departureTime: { $gte: sevenDaysAgo },
      });
    } catch {
      // tripsCount7Days remains 0
    }

    return this.toView(doc, tripsCount7Days);
  }

  async create(
    actor: AuthenticatedUserActor,
    dto: CreateCrewInput,
    _clientInfo?: ClientRequestInfo,
  ): Promise<ClientCrewView> {
    if (!actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Operator identification missing from session actor');
    }

    const opId = new Types.ObjectId(actor.operatorId);

    const existing = await this.crewModel
      .findOne({
        operatorId: opId,
        phone: dto.phone.trim(),
        isDeleted: { $ne: true },
      })
      .exec();

    if (existing) {
      throw new ApiException('ALREADY_REGISTERED', 'A crew member with phone ' + dto.phone + ' already exists for this operator');
    }

    const parsedExpiry = dto.licenseExpiryDate ? new Date(dto.licenseExpiryDate) : undefined;

    const doc = await this.crewModel.create({
      operatorId: opId,
      name: dto.name.trim(),
      role: dto.role,
      phone: dto.phone.trim(),
      licenseNumber: dto.licenseNumber?.trim(),
      licenseExpiryDate: parsedExpiry,
      badgeNumber: dto.badgeNumber?.trim(),
      status: dto.status ?? 'ACTIVE',
      isDeleted: false,
    });

    return this.toView(doc);
  }

  async update(
    actor: AuthenticatedUserActor,
    id: string,
    dto: UpdateCrewInput,
    _clientInfo?: ClientRequestInfo,
  ): Promise<ClientCrewView> {
    const existing = await this.findById(actor, id);

    const updateData: Record<string, unknown> = {};
    if (dto.name !== undefined) updateData.name = dto.name.trim();
    if (dto.role !== undefined) updateData.role = dto.role;
    if (dto.phone !== undefined) {
      const trimmedPhone = dto.phone.trim();
      if (trimmedPhone !== existing.phone) {
        const dup = await this.crewModel
          .findOne({
            operatorId: new Types.ObjectId(existing.operatorId),
            phone: trimmedPhone,
            _id: { $ne: new Types.ObjectId(id) },
            isDeleted: { $ne: true },
          })
          .exec();
        if (dup) {
          throw new ApiException('ALREADY_REGISTERED', 'A crew member with phone ' + trimmedPhone + ' already exists for this operator');
        }
      }
      updateData.phone = trimmedPhone;
    }
    if (dto.licenseNumber !== undefined) updateData.licenseNumber = dto.licenseNumber.trim();
    if (dto.licenseExpiryDate !== undefined) {
      updateData.licenseExpiryDate = dto.licenseExpiryDate ? new Date(dto.licenseExpiryDate) : undefined;
    }
    if (dto.badgeNumber !== undefined) updateData.badgeNumber = dto.badgeNumber.trim();
    if (dto.status !== undefined) updateData.status = dto.status;

    const updated = await this.crewModel
      .findByIdAndUpdate(id, { $set: updateData }, { new: true })
      .exec();

    if (!updated) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Crew record ' + id + ' not found');
    }

    return this.toView(updated);
  }

  async updateStatus(
    actor: AuthenticatedUserActor,
    id: string,
    status: CrewStatus,
  ): Promise<ClientCrewView> {
    await this.findById(actor, id);

    const updated = await this.crewModel
      .findByIdAndUpdate(id, { $set: { status } }, { new: true })
      .exec();

    if (!updated) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Crew record ' + id + ' not found');
    }

    return this.toView(updated);
  }

  async delete(
    actor: AuthenticatedUserActor,
    id: string,
    _clientInfo?: ClientRequestInfo,
  ): Promise<{ success: boolean; id: string }> {
    const existing = await this.findById(actor, id);

    try {
      const tripsColl = this.connection.collection('trips');
      const activeTrip = await tripsColl.findOne({
        $or: [
          { driverIds: new Types.ObjectId(id) },
          { driverId: new Types.ObjectId(id) },
          { 'bus.driverId': new Types.ObjectId(id) },
          { conductorIds: new Types.ObjectId(id) },
          { conductorId: new Types.ObjectId(id) },
        ],
        status: { $in: ['SCHEDULED', 'BOARDING', 'RUNNING'] },
      });

      if (activeTrip) {
        throw new ApiException('RESOURCE_IN_USE', 'Cannot delete crew member assigned to active or scheduled trips');
      }
    } catch (err: unknown) {
      if (err instanceof ApiException) throw err;
    }

    await this.crewModel.findByIdAndUpdate(id, {
      $set: { isDeleted: true, deletedAt: new Date(), status: 'INACTIVE' },
    });

    return { success: true, id: existing.id };
  }

  async restore(
    actor: AuthenticatedUserActor,
    id: string,
  ): Promise<ClientCrewView> {
    if (!Types.ObjectId.isValid(id)) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Crew record with ID ' + id + ' not found');
    }
    const doc = await this.crewModel.findById(id).exec();
    if (!doc) {
      throw new ApiException('RESOURCE_NOT_FOUND', 'Crew record with ID ' + id + ' not found');
    }
    if (actor.operatorId && doc.operatorId.toString() !== actor.operatorId) {
      throw new ApiException('PERMISSION_DENIED', 'Cannot restore crew belonging to another operator');
    }

    const restored = await this.crewModel
      .findByIdAndUpdate(id, { $set: { isDeleted: false, deletedAt: null } }, { new: true })
      .exec();

    return this.toView(restored!);
  }

  async checkAssignmentEligibility(
    actor: AuthenticatedUserActor,
    id: string,
    travelDate: Date,
  ): Promise<{
    eligible: boolean;
    warning?: string;
    reason?: string;
    code?: string;
  }> {
    const crew = await this.findById(actor, id);

    if (crew.status !== 'ACTIVE') {
      return {
        eligible: false,
        reason: 'Crew member is not ACTIVE',
        code: 'CREW_NOT_ACTIVE',
      };
    }

    if (crew.licenseExpiryDate) {
      const expDate = new Date(crew.licenseExpiryDate);
      if (expDate.getTime() < travelDate.getTime()) {
        return {
          eligible: false,
          reason: 'An expired licence cannot be assigned to a trip',
          code: 'LICENCE_EXPIRED',
        };
      }

      const warnThreshold = new Date(travelDate.getTime() + 30 * 24 * 60 * 60 * 1000);
      if (expDate.getTime() <= warnThreshold.getTime()) {
        return {
          eligible: true,
          warning: 'Licence expires within 30 days of travel date',
          code: 'LICENCE_EXPIRING_SOON',
        };
      }
    }

    return { eligible: true };
  }
}
