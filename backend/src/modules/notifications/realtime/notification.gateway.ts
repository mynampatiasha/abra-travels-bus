import { type OnGatewayConnection, WebSocketGateway } from '@nestjs/websockets';
import { type Socket } from 'socket.io';
import { AccessTokenService } from '../../authentication/services/access-token.service';
import { userRoom } from './realtime';

/**
 * The live channel of the apps. A connection is accepted only with a valid access token (sent as
 * `auth: { token }`); it then joins the room of that person and receives their notifications. It
 * carries nothing else and accepts nothing from the client.
 */
@WebSocketGateway()
export class NotificationGateway implements OnGatewayConnection {
  constructor(private readonly tokens: AccessTokenService) {}

  async handleConnection(client: Socket): Promise<void> {
    const auth = client.handshake.auth as { token?: unknown } | undefined;
    const token = typeof auth?.token === 'string' ? auth.token : '';
    try {
      const subject = await this.tokens.verify(token);
      await client.join(userRoom(subject.userId));
      client.emit('ready');
    } catch {
      client.emit('unauthorized');
      client.disconnect(true);
    }
  }
}
