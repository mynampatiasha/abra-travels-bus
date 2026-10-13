import { type AddressInfo } from 'node:net';
import { Types } from 'mongoose';
import { io, type Socket } from 'socket.io-client';
import {
  type AuthTestContext,
  createAuthTestApp,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { newId, seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';
import { LiveUpdatesGateway, MAX_TOPICS_PER_SOCKET } from '../live_updates_channel';
import { LivePublisher, TopicAuthorizerRegistry } from '../live_updates_channel.service';

type Person = SeededUser & { tokens: Tokens };

/**
 * The live channel with real socket connections, against the real application, MongoDB and
 * Redis: who may connect, which rooms they land in, what they may follow, and how a connection
 * ends when the person signs out or their access changes.
 */
describe('Live updates e2e', () => {
  let context: AuthTestContext;
  let port: number;
  let publisher: LivePublisher;
  let gateway: LiveUpdatesGateway;
  let staff: Person;
  let customer: Person;
  let operatorOne: Person;
  let operatorTwo: Person;
  const operatorA = newId();
  const operatorB = newId();
  const sockets: Socket[] = [];

  beforeAll(async () => {
    context = await createAuthTestApp();
    const httpServer = context.app.getHttpServer();
    if (!httpServer.listening)
      await new Promise<void>((resolve) => httpServer.listen(0, '127.0.0.1', resolve));
    port = (httpServer.address() as AddressInfo).port;
    publisher = context.app.get(LivePublisher);
    gateway = context.app.get(LiveUpdatesGateway);
    // Topics for the tests: anybody may follow "open", everybody else only their own id
    context.app.get(TopicAuthorizerRegistry).register({
      kind: 'manytopic',
      authorize: () => Promise.resolve(true),
    });
    context.app.get(TopicAuthorizerRegistry).register({
      kind: 'testtopic',
      authorize: (subject, id) => Promise.resolve(id === 'open' || id === subject.userId),
    });
    staff = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    customer = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });
    operatorOne = await seedAndSignIn(context, {
      roleKeys: ['OPERATOR_ADMIN'],
      operatorId: operatorA,
    });
    operatorTwo = await seedAndSignIn(context, {
      roleKeys: ['OPERATOR_ADMIN'],
      operatorId: operatorB,
    });
  }, 90_000);

  afterAll(async () => {
    for (const socket of sockets) socket.close();
    await context.close();
  }, 60_000);

  const connect = (token: string): Socket => {
    const socket = io(`http://127.0.0.1:${port}`, {
      auth: { token },
      transports: ['websocket'],
      reconnection: false,
    });
    sockets.push(socket);
    return socket;
  };

  const once = <T>(socket: Socket, name: string, ms = 5000): Promise<T> =>
    new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`No "${name}" within ${ms} ms`)), ms);
      socket.once(name, (value: T) => {
        clearTimeout(timer);
        resolve(value);
      });
    });

  const ready = async (person: Person): Promise<Socket> => {
    const socket = connect(person.tokens.accessToken);
    await once(socket, 'ready');
    return socket;
  };

  /** Resolves true if the socket hears `live` within a short time. */
  const hears = (socket: Socket, ms = 400): Promise<boolean> =>
    new Promise((resolve) => {
      const heard = () => resolve(true);
      socket.once('live', heard);
      setTimeout(() => {
        socket.off('live', heard);
        resolve(false);
      }, ms);
    });

  /** The answer arrives in the standard envelope: `{ success, data }`. */
  const subscribe = async (
    socket: Socket,
    topic: unknown,
  ): Promise<{ ok: boolean; reason?: string }> => {
    const answer = (await socket.timeout(3000).emitWithAck('subscribe', { topic })) as {
      data: { ok: boolean; reason?: string };
    };
    return answer.data;
  };

  describe('connecting', () => {
    it('refuses a missing or invalid token and closes the socket', async () => {
      for (const token of ['', 'not-a-token']) {
        const socket = connect(token);
        const closed = new Promise((resolve) => socket.once('disconnect', resolve));
        await once(socket, 'unauthorized');
        await closed;
        expect(socket.connected).toBe(false);
      }
    });

    it('accepts a valid token', async () => {
      const socket = await ready(customer);
      expect(socket.connected).toBe(true);
    });

    it('refuses a token whose session was signed out', async () => {
      const person = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });
      await context.connection
        .collection('auth_sessions')
        .updateOne(
          { _id: new Types.ObjectId(person.tokens.sessionId) },
          { $set: { revokedAt: new Date() } },
        );
      const socket = connect(person.tokens.accessToken);
      await once(socket, 'unauthorized');
      expect(socket.connected).toBe(false);
    });

    it('refuses a token after the access of the person changed', async () => {
      const person = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });
      await context.connection
        .collection('users')
        .updateOne({ _id: new Types.ObjectId(person.id) }, { $inc: { permissionVersion: 1 } });
      const socket = connect(person.tokens.accessToken);
      await once(socket, 'unauthorized');
    });
  });

  describe('who hears what', () => {
    it('staff hear staff messages; a customer and operators do not', async () => {
      const [a, c, o] = await Promise.all([ready(staff), ready(customer), ready(operatorOne)]);
      const heardByStaff = once<{ type: string; data: { id: string }; at: string }>(a, 'live');
      const customerHears = hears(c);
      const operatorHears = hears(o);
      publisher.toStaff('sos.raised', { id: 'sos1' });
      const message = await heardByStaff;
      expect(message).toMatchObject({ type: 'sos.raised', data: { id: 'sos1' } });
      expect(new Date(message.at).getTime()).not.toBeNaN();
      expect(await customerHears).toBe(false);
      expect(await operatorHears).toBe(false);
    });

    it('one person hears on every open device, and nobody else does', async () => {
      const [first, second, stranger] = await Promise.all([
        ready(customer),
        ready(customer),
        ready(operatorOne),
      ]);
      const heard = Promise.all([once(first, 'live'), once(second, 'live')]);
      const strangerHears = hears(stranger);
      publisher.toUser(customer.id, 'report.approved', { id: 'r1' });
      await heard;
      expect(await strangerHears).toBe(false);
    });

    it('operator staff hear their own operator only', async () => {
      const [one, two] = await Promise.all([ready(operatorOne), ready(operatorTwo)]);
      const oneHears = once(one, 'live');
      const twoHears = hears(two);
      publisher.toOperator(operatorA.toHexString(), 'booking.created', { id: 'b1' });
      await oneHears;
      expect(await twoHears).toBe(false);
    });
  });

  describe('following a topic', () => {
    it('a person may follow what the topic allows and then hears it, with the topic named', async () => {
      const socket = await ready(customer);
      expect(await subscribe(socket, 'testtopic:open')).toEqual({ ok: true });
      const message = once<{ topic: string; type: string }>(socket, 'live');
      publisher.toTopic('testtopic', 'open', 'seat.held', { seat: '1A' });
      expect(await message).toMatchObject({ topic: 'testtopic:open', type: 'seat.held' });
    });

    it('refuses what the topic does not allow, without saying why', async () => {
      const socket = await ready(customer);
      expect(await subscribe(socket, 'testtopic:someone-elses')).toEqual({
        ok: false,
        reason: 'not-allowed',
      });
      expect(await subscribe(socket, 'unknownkind:abc')).toEqual({
        ok: false,
        reason: 'not-allowed',
      });
      expect(await subscribe(socket, 'nonsense')).toEqual({ ok: false, reason: 'bad-topic' });
      expect(await subscribe(socket, 42)).toEqual({ ok: false, reason: 'bad-topic' });
      const heard = hears(socket);
      publisher.toTopic('testtopic', 'someone-elses', 'seat.held', {});
      expect(await heard).toBe(false);
    });

    it('stops hearing after unsubscribe', async () => {
      const socket = await ready(customer);
      await subscribe(socket, `testtopic:${customer.id}`);
      await socket.timeout(3000).emitWithAck('unsubscribe', { topic: `testtopic:${customer.id}` });
      const heard = hears(socket);
      publisher.toTopic('testtopic', customer.id, 'seat.held', {});
      expect(await heard).toBe(false);
    });

    it('limits how many topics one connection follows', async () => {
      const socket = await ready(customer);
      for (let i = 0; i < MAX_TOPICS_PER_SOCKET; i += 1) {
        expect(await subscribe(socket, `manytopic:t${i}`)).toEqual({ ok: true });
      }
      expect(await subscribe(socket, 'manytopic:one-too-many')).toEqual({
        ok: false,
        reason: 'too-many',
      });
    });
  });

  describe('ending a connection', () => {
    it('closes only the connections whose session or access is no longer valid', async () => {
      const person = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });
      const gone = await ready(person);
      const stays = await ready(staff);
      const told = once(gone, 'unauthorized');
      await context.connection
        .collection('auth_sessions')
        .updateOne(
          { _id: new Types.ObjectId(person.tokens.sessionId) },
          { $set: { revokedAt: new Date() } },
        );
      const closed = await gateway.sweep();
      await told;
      expect(closed).toBeGreaterThanOrEqual(1);
      expect(gone.connected).toBe(false);
      expect(stays.connected).toBe(true);
    });

    it('closes a connection when the access of the person changes', async () => {
      const person = await seedAndSignIn(context, { roleKeys: ['CUSTOMER'], userType: 'CUSTOMER' });
      const socket = await ready(person);
      const told = once(socket, 'unauthorized');
      await context.connection
        .collection('users')
        .updateOne({ _id: new Types.ObjectId(person.id) }, { $inc: { permissionVersion: 1 } });
      await gateway.sweep();
      await told;
      expect(socket.connected).toBe(false);
    });
  });
});
