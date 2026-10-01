import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { UserDirectoryController } from './controllers/user-directory.controller';
import { UserDirectoryRepository } from './repositories/user-directory.repository';
import { UserRepository } from './repositories/user.repository';
import { USER_MODEL, userSchema } from './schemas/user.schema';
import { UserDirectoryService } from './services/user-directory.service';
import { UsersService } from './services/users.service';

/**
 * `users` — Identity domain (documentation/architecture.md §5). Owns the `users` collection.
 * UsersService serves identity (authentication); UserDirectoryRepository is the scoped view used
 * when one user administers others (authorization.md §4).
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: USER_MODEL, schema: userSchema }])],
  controllers: [UserDirectoryController],
  providers: [UserRepository, UsersService, UserDirectoryRepository, UserDirectoryService],
  exports: [UsersService, UserDirectoryRepository],
})
export class UsersModule {}
