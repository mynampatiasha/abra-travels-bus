import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model } from 'mongoose';
import { type ScopeFields } from '../../../database/data-scope.policy';
import { ScopedRepository, type StoredDocument } from '../../../database/scoped-repository.base';
import { BUS_MODEL, type Bus } from '../schemas/bus.schema';

export type StoredBus = StoredDocument<Bus>;

/** `buses`, restricted to the operators in the actor's data scope. */
@Injectable()
export class BusRepository extends ScopedRepository<Bus> {
  protected readonly scopeFields: ScopeFields = { operator: 'operatorId' };

  constructor(@InjectModel(BUS_MODEL) model: Model<Bus>) {
    super(model);
  }
}
