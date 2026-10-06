import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model } from 'mongoose';
import { type ScopeFields } from '../../../database/data-scope.policy';
import { ScopedRepository } from '../../../database/scoped-repository.base';
import { OPERATOR_MODEL, type Operator } from '../schemas/operator.schema';

/**
 * `operators`, through the actor's data scope: platform staff see every operator, operator
 * staff only their own (the operator's id is its own tenant key).
 */
@Injectable()
export class OperatorRepository extends ScopedRepository<Operator> {
  protected readonly scopeFields: ScopeFields = { operator: '_id' };

  constructor(@InjectModel(OPERATOR_MODEL) model: Model<Operator>) {
    super(model);
  }
}
