import { Injectable } from '@nestjs/common';
import { ApiException } from '../../../common/errors/api-exception';
import { type ClientRequestInfo } from '../../../common/http/client-request-info';
import { SessionsService } from '../../sessions/services/sessions.service';
import { type StoredUser } from '../../users/repositories/user.repository';
import { UsersService } from '../../users/services/users.service';
import { type AuthenticationResult, AuthSessionIssuer } from './auth-session-issuer.service';

/** Exchanges a refresh token for a new access token and a new refresh token (rotation). */
@Injectable()
export class TokenRefreshService {
  constructor(
    private readonly sessions: SessionsService,
    private readonly users: UsersService,
    private readonly issuer: AuthSessionIssuer,
  ) {}

  async refresh(refreshToken: unknown, client: ClientRequestInfo): Promise<AuthenticationResult> {
    let user: StoredUser | undefined;
    const rotated = await this.sessions.rotate(refreshToken, client, async (userId) => {
      const found = await this.users.findById(userId);
      // A disabled or deleted account cannot extend its session; the token is left untouched
      if (!found || found.status !== 'ACTIVE') {
        throw new ApiException(
          'UNAUTHENTICATED',
          'The session is no longer valid. Please sign in again.',
        );
      }
      user = found;
      return found.userType;
    });
    if (!user) throw new Error('Session rotated without resolving its user');
    return this.issuer.result(user, rotated.session, rotated.refreshToken);
  }
}
