import { Module, type OnModuleDestroy, type OnModuleInit } from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  type OnGatewayConnection,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { type Server, type Socket } from 'socket.io';
import { AuthenticationModule } from '../authentication/authentication.module';
import { SessionsModule } from '../sessions/sessions.module';
import { UsersModule } from '../users/users.module';
import {
  LivePublisher,
  type LiveSubject,
  LiveUpdatesService,
  MAX_TOPICS_PER_SOCKET,
  type SubscribeAnswer,
  TopicAuthorizerRegistry,
  parseTopic,
  topicRoom,
} from './live_updates_channel.service';

// ===== 1. SOCKET DATA ===============================================================

interface SocketData {
  subject?: LiveSubject;
  /** Kept so the connection can be checked again; never sent anywhere. */
  token?: string;
}

const TOPIC_PREFIX = 'topic:';
const REVALIDATE_EVERY_MS = 60_000;
const REVALIDATE_PARALLEL = 10;

const dataOf = (socket: Socket): SocketData => socket.data as SocketData;

// ===== 2. THE GATEWAY ===============================================================

/**
 * The live channel of every app (documentation/abra-master-plan.md, Phase 0). A connection is
 * accepted only with a valid access token, sent as `auth: { token }`, for an active session and
 * an unchanged account. It joins the rooms of that person by itself (their own, `staff` for the
 * admin portal, `operator:<id>` for operator staff and drivers) and may ask to follow a topic
 * such as `trip:<id>` with `subscribe`; the answer says whether that was allowed. The client
 * sends nothing else and the server accepts nothing else.
 *
 * Events the client listens for: `ready`, `unauthorized` (then the socket closes: sign in again
 * or refresh the token and reconnect), `live` (every change, see LiveMessage) and
 * `notification` (the bell).
 */
@WebSocketGateway()
export class LiveUpdatesGateway implements OnGatewayConnection, OnModuleInit, OnModuleDestroy {
  @WebSocketServer() private server!: Server;
  private timer: NodeJS.Timeout | undefined;

  constructor(private readonly live: LiveUpdatesService) {}

  onModuleInit(): void {
    this.timer = setInterval(() => void this.sweep(), REVALIDATE_EVERY_MS);
    this.timer.unref();
  }

  onModuleDestroy(): void {
    if (this.timer) clearInterval(this.timer);
  }

  async handleConnection(client: Socket): Promise<void> {
    const auth = client.handshake.auth as { token?: unknown } | undefined;
    const token = typeof auth?.token === 'string' ? auth.token : '';
    const subject = token ? await this.live.authenticate(token) : undefined;
    if (!subject) return this.refuse(client);
    Object.assign(dataOf(client), { subject, token } satisfies SocketData);
    await client.join(this.live.roomsOf(subject));
    client.emit('ready');
  }

  // client -> server: { topic: 'trip:abc' }; answer: { ok: true } or { ok: false, reason }
  @SubscribeMessage('subscribe')
  async subscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { topic?: unknown } | undefined,
  ): Promise<SubscribeAnswer> {
    const subject = dataOf(client).subject;
    if (!subject) return { ok: false, reason: 'not-allowed' };
    const followed = [...client.rooms].filter((room) => room.startsWith(TOPIC_PREFIX)).length;
    const answer = await this.live.authorizeTopic(subject, body?.topic, followed);
    if (answer.ok && answer.room) await client.join(answer.room);
    return answer.ok ? { ok: true } : { ok: false, reason: answer.reason };
  }

  @SubscribeMessage('unsubscribe')
  async unsubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() body: { topic?: unknown } | undefined,
  ): Promise<{ ok: true }> {
    const parsed = parseTopic(body?.topic);
    if (parsed) await client.leave(topicRoom(parsed.kind, parsed.id));
    return { ok: true };
  }

  /**
   * Checks every open connection again; one that is no longer valid (signed out, deactivated,
   * access changed, token expired) is told and closed. Runs every minute; tests call it directly.
   */
  async sweep(): Promise<number> {
    const sockets = [...(this.server?.sockets.sockets.values() ?? [])].filter(
      (socket) => dataOf(socket).subject,
    );
    let closed = 0;
    for (let i = 0; i < sockets.length; i += REVALIDATE_PARALLEL) {
      await Promise.all(
        sockets.slice(i, i + REVALIDATE_PARALLEL).map(async (socket) => {
          const { subject, token } = dataOf(socket);
          if (subject && token && (await this.live.stillValid(token, subject))) return;
          this.refuse(socket);
          closed += 1;
        }),
      );
    }
    return closed;
  }

  private refuse(client: Socket): void {
    client.emit('unauthorized');
    client.disconnect(true);
  }
}

export { MAX_TOPICS_PER_SOCKET };

// ===== 3. MODULE ====================================================================

/**
 * `realtime`: the live channel. Features publish with `LivePublisher` (from the API or the
 * worker) and say what can be followed by registering a `TopicAuthorizer`.
 */
@Module({
  imports: [AuthenticationModule, SessionsModule, UsersModule],
  providers: [LivePublisher, TopicAuthorizerRegistry, LiveUpdatesService, LiveUpdatesGateway],
  exports: [LivePublisher, TopicAuthorizerRegistry],
})
export class RealtimeModule {}
