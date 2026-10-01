import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type ClientSession, type Model, type Types } from 'mongoose';
import { CUSTOMER_MODEL, type Customer } from '../schemas/customer.schema';

export type StoredCustomer = Customer & { _id: Types.ObjectId };

/**
 * Customer profiles. Created during sign-up, before the new user has a session, so creation is
 * not actor-scoped; reads by user id are always for the authenticated user's own id.
 */
@Injectable()
export class CustomerRepository {
  constructor(@InjectModel(CUSTOMER_MODEL) private readonly model: Model<Customer>) {}

  async insert(customer: Partial<Customer>, session: ClientSession): Promise<StoredCustomer> {
    const [created] = await this.model.create([customer], { session });
    if (!created) throw new Error('Customer insert returned no document');
    return created.toObject();
  }

  findByUserId(userId: string): Promise<StoredCustomer | null> {
    return this.model.findOne({ userId }).lean<StoredCustomer>().exec();
  }
}
