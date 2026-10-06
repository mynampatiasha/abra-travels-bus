import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model } from 'mongoose';
import { type ScopeFields } from '../../../database/data-scope.policy';
import { ScopedRepository, type StoredDocument } from '../../../database/scoped-repository.base';
import { ROUTE_MODEL, type Route } from '../schemas/route.schema';

export type StoredRoute = StoredDocument<Route>;

/** `routes`, restricted to the operators in the actor's data scope. */
@Injectable()
export class RouteRepository extends ScopedRepository<Route> {
  protected readonly scopeFields: ScopeFields = { operator: 'operatorId' };

  constructor(@InjectModel(ROUTE_MODEL) model: Model<Route>) {
    super(model);
  }
}
