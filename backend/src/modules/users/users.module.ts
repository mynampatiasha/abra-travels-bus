import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { UserRepository } from './repositories/user.repository';
import { USER_MODEL, userSchema } from './schemas/user.schema';
import { UsersService } from './services/users.service';

/**
 * `users` — Identity domain (documentation/architecture.md §5). Owns the `users` collection.
 * Other modules use UsersService; user administration endpoints arrive with RBAC (step 8).
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: USER_MODEL, schema: userSchema }])],
  providers: [UserRepository, UsersService],
  exports: [UsersService],
})
export class UsersModule {}
