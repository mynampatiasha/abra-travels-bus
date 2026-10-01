import { Injectable } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { type Model } from 'mongoose';
import { type ScopeFields } from '../../../database/data-scope.policy';
import { ScopedRepository } from '../../../database/scoped-repository.base';
import { USER_MODEL, type User } from '../schemas/user.schema';

/**
 * The `users` collection as seen by an authenticated actor administering other users. Unlike
 * UserRepository (identity lookups before an actor exists), every read here is restricted to the
 * actor's data scope: an operator administrator sees only users of their operator, a partner
 * user only users of their partner, and a user outside the scope looks like it does not exist.
 */
@Injectable()
export class UserDirectoryRepository extends ScopedRepository<User> {
  protected readonly scopeFields: ScopeFields = {
    operator: 'operatorId',
    partner: 'partnerId',
    owner: '_id',
  };

  constructor(@InjectModel(USER_MODEL) model: Model<User>) {
    super(model);
  }
}
