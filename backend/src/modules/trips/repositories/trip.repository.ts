import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model } from 'mongoose';
import { type ScopeFields } from '../../../database/data-scope.policy';
import { ScopedRepository, type StoredDocument } from '../../../database/scoped-repository.base';
import { TRIP_MODEL, type Trip } from '../schemas/trip.schema';

export type StoredTrip = StoredDocument<Trip>;

/**
 * `trips` for the people who run them, restricted to the operators in the actor's data scope.
 * Customers never go through this class; they read the public catalogue
 * (TripCatalogueRepository).
 */
@Injectable()
export class TripRepository extends ScopedRepository<Trip> {
  protected readonly scopeFields: ScopeFields = { operator: 'operatorId' };

  constructor(@InjectModel(TRIP_MODEL) model: Model<Trip>) {
    super(model);
  }
}
