import { Inject, Injectable, Logger } from '@nestjs/common';
import { Emitter } from '@socket.io/redis-emitter';
import { type Redis } from 'ioredis';
import { type UserType } from '../../common/request-context/request-actor';
import { REDIS_CLIENT } from '../../redis/redis.module';
import { AccessTokenService } from '../authentication/services/access-token.service';
import { userRoom } from '../notifications/realtime/realtime';
import { SessionsService } from '../sessions/services/sessions.service';
import { UsersService } from '../users/services/users.service';

// ===== 1. WHAT THE CHANNEL CARRIES ==================================================
// One socket event, `live`, carries every "something changed" message of the apps (a seat was
// held, a bus moved, an SOS was raised, a report was approved). It is only a nudge with the
// facts needed to update the screen: the record itself is always in the database, so nobody
// loses anything by being offline. `notification` (the in-app bell) keeps its own event.

export const LIVE_EVENT = 'live';

/** `<thing>.<what happened>`, lower case: `sos.raised`, `trip.delayed`, `seat.held`. */
export const LIVE_TYPE_PATTERN = /^[a-z][a-z-]*(\.[a-z][a-z-]*)+$/;

export interface LiveMessage {
  type: string;
  /** The topic it was published to, when it was a topic message. */
  topic?: string;
  data: Record<string, unknown>;
  /** ISO time the server published it. */
  at: string;
}

/** Large enough for any status change, small enough that nobody sends a record through here. */
const MAX_DATA_BYTES = 16 * 1024;

export const staffRoom = 'staff';
export const operatorRoom = (operatorId: string): string => `operator:${operatorId}`;
export const topicRoom = (kind: string, id: string): string => `topic:${kind}:${id}`;

// ===== 2. PUBLISHING (from the API and from the worker) ============================

/**
 * What every feature calls to tell people something changed. It publishes through Redis, so it
 * works from the API and from the worker, and reaches a browser or phone whichever API instance
 * it is connected to. Never put secrets or personal records in `data`: send ids and the new
 * state, and let the app fetch the rest with its own permissions.
 */
@Injectable()
export class LivePublisher {
  private readonly emitter: Emitter;

  constructor(@Inject(REDIS_CLIENT) redis: Redis) {
    this.emitter = new Emitter(redis);
  }

  /** One person, on every device they have open. */
  toUser(userId: string, type: string, data: Record<string, unknown> = {}): void {
    this.publish(userRoom(userId), type, data);
  }

  /** Everyone signed in to the admin portal. */
  toStaff(type: string, data: Record<string, unknown> = {}): void {
    this.publish(staffRoom, type, data);
  }

  /** The staff and drivers of one operator. */
  toOperator(operatorId: string, type: string, data: Record<string, unknown> = {}): void {
    this.publish(operatorRoom(operatorId), type, data);
  }

  /** Everyone who subscribed to `<kind>:<id>` and was allowed to (a trip, a booking, ...). */
  toTopic(kind: string, id: string, type: string, data: Record<string, unknown> = {}): void {
    this.publish(topicRoom(kind, id), type, data, `${kind}:${id}`);
  }

  private publish(room: string, type: string, data: Record<string, unknown>, topic?: string): void {
    if (!LIVE_TYPE_PATTERN.test(type)) throw new Error(`Invalid live event type "${type}"`);
    if (Buffer.byteLength(JSON.stringify(data)) > MAX_DATA_BYTES) {
      throw new Error(`Live event "${type}" is too large: send ids and state, not records`);
    }
    const message: LiveMessage = {
      type,
      ...(topic ? { topic } : {}),
      data,
      at: new Date().toISOString(),
    };
    this.emitter.to(room).emit(LIVE_EVENT, message);
  }
}

// ===== 3. TOPICS: what a client may ask to follow ===================================

/** Who is connected, as far as topic permissions are concerned. */
export interface LiveSubject {
  userId: string;
  userType: UserType;
  sessionId: string;
  permissionVersion: number;
  operatorId?: string;
}

export interface TopicAuthorizer {
  /** The part before the colon: `trip` for `trip:64f...`. */
  readonly kind: string;
  /** May this person follow this one thing? Answer false for "not yours" and for "does not exist". */
  authorize(subject: LiveSubject, id: string): Promise<boolean>;
}

const KIND_PATTERN = /^[a-z][a-z-]{1,19}$/;
const ID_PATTERN = /^[A-Za-z0-9_-]{1,64}$/;

/** Features register what can be followed (a trip, a booking, an SOS). Nothing is open by default. */
@Injectable()
export class TopicAuthorizerRegistry {
  private readonly authorizers = new Map<string, TopicAuthorizer>();

  register(authorizer: TopicAuthorizer): void {
    if (!KIND_PATTERN.test(authorizer.kind))
      throw new Error(`Invalid topic kind "${authorizer.kind}"`);
    if (this.authorizers.has(authorizer.kind))
      throw new Error(`Topic "${authorizer.kind}" is registered twice`);
    this.authorizers.set(authorizer.kind, authorizer);
  }

  get(kind: string): TopicAuthorizer | undefined {
    return this.authorizers.get(kind);
  }
}

/** `trip:abc123` into its parts, or nothing when it is not a well-formed topic. */
export function parseTopic(topic: unknown): { kind: string; id: string } | undefined {
  if (typeof topic !== 'string') return undefined;
  const separator = topic.indexOf(':');
  if (separator < 0) return undefined;
  const kind = topic.slice(0, separator);
  const id = topic.slice(separator + 1);
  return KIND_PATTERN.test(kind) && ID_PATTERN.test(id) ? { kind, id } : undefined;
}

// ===== 4. CONNECTIONS ===============================================================

export const MAX_TOPICS_PER_SOCKET = 50;

export type SubscribeAnswer =
  { ok: true } | { ok: false; reason: 'bad-topic' | 'not-allowed' | 'too-many' };

/**
 * The rules of a live connection. A connection is as trustworthy as an HTTP request: the same
 * token, an active session, an active user and an unchanged permission version are needed to
 * connect, and they are checked again every minute, so signing out or changing someone's access
 * ends their live connection within a minute.
 */
@Injectable()
export class LiveUpdatesService {
  private readonly logger = new Logger(LiveUpdatesService.name);

  constructor(
    private readonly tokens: AccessTokenService,
    private readonly sessions: SessionsService,
    private readonly users: UsersService,
    private readonly topics: TopicAuthorizerRegistry,
  ) {}

  /** The person behind a token, or nothing if the connection must be refused. */
  async authenticate(token: string): Promise<LiveSubject | undefined> {
    try {
      const claims = await this.tokens.verify(token);
      const [session, user] = await Promise.all([
        this.sessions.findActive(claims.sessionId, claims.userId),
        this.users.findById(claims.userId),
      ]);
      if (!session || !user || user.status !== 'ACTIVE') return undefined;
      if (claims.permissionVersion !== user.permissionVersion) return undefined;
      // A session that still has to set up two-step verification gets nothing live
      if (session.mfaEnrollmentPending) return undefined;
      return {
        userId: claims.userId,
        userType: claims.userType,
        sessionId: claims.sessionId,
        permissionVersion: claims.permissionVersion,
        ...(user.operatorId ? { operatorId: user.operatorId.toHexString() } : {}),
      };
    } catch {
      return undefined;
    }
  }

  /** The rooms every connection of this person joins by itself. */
  roomsOf(subject: LiveSubject): string[] {
    const rooms = [userRoom(subject.userId)];
    if (subject.userType === 'STAFF') rooms.push(staffRoom);
    if (
      (subject.userType === 'OPERATOR_STAFF' || subject.userType === 'DRIVER') &&
      subject.operatorId
    ) {
      rooms.push(operatorRoom(subject.operatorId));
    }
    return rooms;
  }

  /** Decides whether the person may follow a topic; the caller joins the room when `ok`. */
  async authorizeTopic(
    subject: LiveSubject,
    topic: unknown,
    followed: number,
  ): Promise<SubscribeAnswer & { room?: string }> {
    const parsed = parseTopic(topic);
    if (!parsed) return { ok: false, reason: 'bad-topic' };
    if (followed >= MAX_TOPICS_PER_SOCKET) return { ok: false, reason: 'too-many' };
    const authorizer = this.topics.get(parsed.kind);
    if (!authorizer) return { ok: false, reason: 'not-allowed' };
    try {
      if (!(await authorizer.authorize(subject, parsed.id)))
        return { ok: false, reason: 'not-allowed' };
    } catch (error) {
      this.logger.warn(
        { kind: parsed.kind },
        error instanceof Error ? error.message : 'Topic check failed',
      );
      return { ok: false, reason: 'not-allowed' };
    }
    return { ok: true, room: topicRoom(parsed.kind, parsed.id) };
  }

  /** Is this connection still allowed? Run on a timer for every open connection. */
  async stillValid(token: string, subject: LiveSubject): Promise<boolean> {
    const current = await this.authenticate(token);
    return (
      current !== undefined &&
      current.sessionId === subject.sessionId &&
      current.userId === subject.userId
    );
  }
}
