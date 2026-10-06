import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type QueryFilter, type Types } from 'mongoose';
import { BUS_TYPE_MODEL, type BusType } from '../schemas/bus-type.schema';

export type StoredBusType = BusType & { _id: Types.ObjectId };

/** `bus_types`. Platform catalogue without a tenant; access is decided by permission. */
@Injectable()
export class BusTypeRepository {
  constructor(@InjectModel(BUS_TYPE_MODEL) private readonly model: Model<BusType>) {}

  findById(id: string | Types.ObjectId, session?: ClientSession): Promise<StoredBusType | null> {
    return this.model
      .findById(id)
      .session(session ?? null)
      .lean<StoredBusType>()
      .exec();
  }

  async list(
    filter: { active?: boolean | undefined },
    page: { skip: number; limit: number },
  ): Promise<{ items: StoredBusType[]; total: number }> {
    const match: QueryFilter<BusType> =
      filter.active === undefined ? {} : { isActive: filter.active };
    const [items, total] = await Promise.all([
      this.model
        .find(match)
        .sort({ key: 1 })
        .skip(page.skip)
        .limit(page.limit)
        .lean<StoredBusType[]>()
        .exec(),
      this.model.countDocuments(match).exec(),
    ]);
    return { items, total };
  }

  async insert(busType: BusType, session: ClientSession): Promise<StoredBusType> {
    const [created] = await this.model.create([busType], { session });
    if (!created) throw new Error('Bus type was not created');
    return created.toObject();
  }

  update(
    id: Types.ObjectId,
    set: Partial<BusType>,
    session: ClientSession,
  ): Promise<StoredBusType | null> {
    return this.model
      .findOneAndUpdate(
        { _id: id },
        { $set: set },
        { returnDocument: 'after', session, runValidators: true },
      )
      .lean<StoredBusType>()
      .exec();
  }
}
