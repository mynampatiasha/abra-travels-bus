import { Module } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { MySessionsController } from './controllers/my-sessions.controller';
import { AuthSessionRepository } from './repositories/auth-session.repository';
import { AUTH_SESSION_MODEL, authSessionSchema } from './schemas/auth-session.schema';
import { SessionsService } from './services/sessions.service';

/**
 * `sessions` — Identity domain (documentation/architecture.md §5). Owns `auth_sessions`: signed-in
 * devices, refresh-token rotation and reuse detection, revocation.
 */
@Module({
  imports: [MongooseModule.forFeature([{ name: AUTH_SESSION_MODEL, schema: authSessionSchema }])],
  controllers: [MySessionsController],
  providers: [AuthSessionRepository, SessionsService],
  exports: [SessionsService],
})
export class SessionsModule {}
