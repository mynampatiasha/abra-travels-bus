import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  expireOtpCooldowns,
  signInWithOtp,
  type Tokens,
  uniqueEmail,
  uniqueIp,
  uniquePhone,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';
import {
  type CustomerDetailView,
  type CustomerRowView,
} from '../customers_admin_manage.service';
import { type ProfileView } from '../customers_customer.service';

type Caller = SeededUser & { tokens: Tokens };
type Method = 'get' | 'post' | 'patch' | 'delete';
interface Person {
  tokens: Tokens;
  id: string;
  phone: string;
}

const NOTE = Buffer.from('Screenshot of the abusive messages.\n', 'utf8');

/** The customer's own profile and account, and the admin Customers page. */
describe('Customers e2e', () => {
  let context: AuthTestContext;
  let storageRoot: string;
  let superAdmin: Caller;
  let support: Caller;
  const bookingIds: Types.ObjectId[] = [];

  const asCustomer = (who: Pick<Person, 'tokens'>, method: Method, path: string, body?: object) => {
    const request = client(context)[method](`/api/v1/customer${path}`).set(...bearer(who.tokens));
    return body ? request.send(body) : request;
  };
  const asStaff = (who: Caller, method: Method, path: string, body?: object) => {
    const request = client(context)[method](`/api/v1/admin/customers${path}`).set(...bearer(who.tokens));
    return body ? request.send(body) : request;
  };
  const newCustomer = async (): Promise<Person> => {
    const phone = uniquePhone();
    const tokens = await signInWithOtp(context, phone, uniqueIp());
    return { tokens, id: tokens.user.id, phone };
  };
  const addBooking = async (customerId: string, status: string, amountPaise: number) => {
    const _id = new Types.ObjectId();
    bookingIds.push(_id);
    await context.connection.collection('bookings').insertOne({
      _id,
      customerId: new Types.ObjectId(customerId),
      lockId: `lock-${_id.toHexString()}`,
      status,
      amountPaise,
      pnr: `T${_id.toHexString().slice(-8).toUpperCase()}`,
      passengers: [{ name: 'A' }, { name: 'B' }],
      createdAt: new Date(),
    });
    return _id;
  };
  /** Signs in again with a phone that signed in a moment ago (the code cooldown is lifted). */
  const signInAgain = async (phone: string) => {
    await expireOtpCooldowns(context);
    return signInWithOtp(context, phone, uniqueIp());
  };
  const refreshStatus = async (tokens: Tokens) =>
    (
      await client(context)
        .post('/api/v1/auth/refresh')
        .send({ refreshToken: tokens.refreshToken })
    ).status;

  beforeAll(async () => {
    storageRoot = await mkdtemp(join(tmpdir(), 'abra-customers-e2e-'));
    process.env.STORAGE_LOCAL_ROOT = storageRoot;
    context = await createAuthTestApp();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    support = await seedAndSignIn(context, { roleKeys: ['SUPPORT'] });
  }, 120_000);

  afterAll(async () => {
    await context.connection.collection('bookings').deleteMany({ _id: { $in: bookingIds } });
    await context.close();
    await rm(storageRoot, { recursive: true, force: true });
  }, 60_000);

  describe('my profile', () => {
    it('shows my phone, no email yet, and English until I choose', async () => {
      const me = await newCustomer();
      const profile = dataOf<ProfileView>(await asCustomer(me, 'get', '/profile').expect(200));
      expect(profile).toMatchObject({
        id: me.id,
        phone: me.phone,
        email: '',
        language: 'en',
        signInMethod: 'whatsapp',
      });
    });

    it('is only for customers, and needs a sign-in', async () => {
      await asCustomer({ tokens: support.tokens }, 'get', '/profile').expect(403);
      await client(context).get('/api/v1/customer/profile').expect(401);
    });

    it('needs an email; saves name, email and language; a new email must be verified again', async () => {
      const me = await newCustomer();
      const refused = await asCustomer(me, 'patch', '/profile', { name: 'Asha Rao' }).expect(400);
      expect(errorCodeOf(refused)).toBe('VALIDATION_FAILED');

      const email = uniqueEmail();
      const saved = dataOf<ProfileView>(
        await asCustomer(me, 'patch', '/profile', {
          name: 'Asha Rao',
          email,
          language: 'hi',
        }).expect(200),
      );
      expect(saved).toMatchObject({ name: 'Asha Rao', email, language: 'hi', emailVerified: false });

      // the phone cannot be changed here, and the choice stays
      await asCustomer(me, 'patch', '/profile', { phone: '+910000000000' }).expect(400);
      const again = dataOf<ProfileView>(await asCustomer(me, 'get', '/profile').expect(200));
      expect(again).toMatchObject({ name: 'Asha Rao', email, language: 'hi', phone: me.phone });
    });

    it('refuses an empty email, an unknown language, an empty change and an email of someone else', async () => {
      const me = await newCustomer();
      const other = await newCustomer();
      const taken = uniqueEmail();
      await asCustomer(other, 'patch', '/profile', { name: 'Other', email: taken }).expect(200);

      await asCustomer(me, 'patch', '/profile', { email: '   ' }).expect(400);
      await asCustomer(me, 'patch', '/profile', { email: 'not-an-email' }).expect(400);
      await asCustomer(me, 'patch', '/profile', { language: 'xx' }).expect(400);
      await asCustomer(me, 'patch', '/profile', {}).expect(400);
      const clash = await asCustomer(me, 'patch', '/profile', { name: 'Me', email: taken }).expect(409);
      expect(errorCodeOf(clash)).toBe('ALREADY_REGISTERED');
    });
  });

  describe('deleting my account', () => {
    it('is refused while I have a booking to travel on, and says why', async () => {
      const me = await newCustomer();
      await addBooking(me.id, 'CONFIRMED', 90000);
      const refused = await asCustomer(me, 'delete', '/account').expect(409);
      expect(errorCodeOf(refused)).toBe('INVALID_STATE_TRANSITION');
      expect(JSON.stringify(refused.body)).toMatch(/booking to travel on/);
      await asCustomer(me, 'get', '/profile').expect(200);
    });

    it('removes my personal data, signs me out, and keeps the financial records', async () => {
      const me = await newCustomer();
      await asCustomer(me, 'patch', '/profile', { name: 'Leaving Soon', email: uniqueEmail() }).expect(200);
      const bookingId = await addBooking(me.id, 'COMPLETED', 120000);

      await asCustomer(me, 'delete', '/account').expect(200);

      await asCustomer(me, 'get', '/profile').expect(401);
      expect(await refreshStatus(me.tokens)).toBe(401);
      const user = await context.connection
        .collection('users')
        .findOne({ _id: new Types.ObjectId(me.id) });
      expect(user).toMatchObject({ name: 'Deleted customer', status: 'DEACTIVATED' });
      expect(user).not.toHaveProperty('email');
      expect(user).not.toHaveProperty('phone');
      const profile = await context.connection
        .collection('customers')
        .findOne({ userId: new Types.ObjectId(me.id) });
      expect(profile?.['anonymisedAt']).toBeInstanceOf(Date);
      expect(await context.connection.collection('bookings').countDocuments({ _id: bookingId })).toBe(1);

      // the same phone number can open a new account
      const again = await signInAgain(me.phone);
      expect(again.user.id).not.toBe(me.id);
    });
  });

  describe('the admin list and a customer', () => {
    it('Super Admin and Support read; a signed-out caller does not', async () => {
      await asStaff(superAdmin, 'get', '').expect(200);
      await asStaff(support, 'get', '').expect(200);
      await client(context).get('/api/v1/admin/customers').expect(401);
      const me = await newCustomer();
      await asStaff({ ...support, tokens: me.tokens }, 'get', '').expect(403);
    });

    it('finds by name, email or phone, filters by status and sign-in method, and counts bookings and money', async () => {
      const me = await newCustomer();
      const email = uniqueEmail();
      await asCustomer(me, 'patch', '/profile', { name: 'Zainab Findme', email }).expect(200);
      await addBooking(me.id, 'CONFIRMED', 50000);
      await addBooking(me.id, 'CANCELLED', 30000);
      await addBooking(me.id, 'INITIATED', 99999);

      const rows = async (query: string) =>
        dataOf<CustomerRowView[]>(await asStaff(superAdmin, 'get', query).expect(200));

      for (const q of ['Findme', email.slice(0, 12), me.phone.slice(-8)]) {
        const found = await rows(`?search=${encodeURIComponent(q)}`);
        expect(found.map((row) => row.id)).toContain(me.id);
      }
      const [row] = await rows(`?search=${encodeURIComponent('Findme')}`);
      expect(row).toMatchObject({
        name: 'Zainab Findme',
        signInMethod: 'whatsapp',
        status: 'ACTIVE',
        bookings: 2,
        spentPaise: 50000,
      });
      expect(row).not.toHaveProperty('passwordHash');

      expect((await rows('?status=ACTIVE&search=Findme')).length).toBe(1);
      expect(await rows('?status=SUSPENDED&search=Findme')).toHaveLength(0);
      expect((await rows('?signInMethod=whatsapp&search=Findme')).length).toBe(1);
      expect(await rows('?signInMethod=google&search=Findme')).toHaveLength(0);
      expect(await rows('?signInMethod=password&search=Findme')).toHaveLength(0);
      await asStaff(superAdmin, 'get', '?status=NOPE').expect(400);
    });

    it('shows one customer with the latest bookings and the devices that are signed in', async () => {
      const me = await newCustomer();
      await addBooking(me.id, 'CONFIRMED', 70000);
      const detail = dataOf<CustomerDetailView>(await asStaff(support, 'get', `/${me.id}`).expect(200));
      expect(detail).toMatchObject({ id: me.id, blocked: null, bookings: 1, spentPaise: 70000 });
      expect(detail.recentBookings).toHaveLength(1);
      expect(detail.recentBookings[0]).toMatchObject({ status: 'CONFIRMED', amountPaise: 70000, seats: 2 });
      expect(detail.devices).toHaveLength(1);
      await asStaff(support, 'get', `/${new Types.ObjectId().toHexString()}`).expect(404);
      await asStaff(support, 'get', '/not-an-id').expect(400);
    });

    it('does not open a staff account as a customer', async () => {
      await asStaff(superAdmin, 'get', `/${support.id}`).expect(404);
    });

    it('changes a name or email, audited, and refuses an email of someone else', async () => {
      const me = await newCustomer();
      const other = await newCustomer();
      const taken = uniqueEmail();
      await asCustomer(other, 'patch', '/profile', { name: 'Other', email: taken }).expect(200);

      const changed = dataOf<CustomerDetailView>(
        await asStaff(superAdmin, 'patch', `/${me.id}`, { name: 'Fixed By Staff' }).expect(200),
      );
      expect(changed.name).toBe('Fixed By Staff');
      await asStaff(superAdmin, 'patch', `/${me.id}`, { email: taken }).expect(409);
      await asStaff(superAdmin, 'patch', `/${me.id}`, {}).expect(400);
      await asStaff(support, 'patch', `/${me.id}`, { name: 'Nope' }).expect(403);
    });
  });

  describe('block and unblock', () => {
    it('needs a reason; signs the customer out everywhere and keeps them out until unblocked', async () => {
      const me = await newCustomer();
      const second = await signInAgain(me.phone);
      await asStaff(superAdmin, 'post', `/${me.id}/block`, { reason: '  ' }).expect(400);
      await asStaff(support, 'post', `/${me.id}/block`, { reason: 'Abuse' }).expect(403);

      const blocked = dataOf<CustomerDetailView>(
        await asStaff(superAdmin, 'post', `/${me.id}/block`, { reason: 'Abusive to drivers' }).expect(201),
      );
      expect(blocked.status).toBe('SUSPENDED');
      expect(blocked.blocked).toMatchObject({ reason: 'Abusive to drivers' });
      expect(await refreshStatus(me.tokens)).toBe(401);
      expect(await refreshStatus(second)).toBe(401);
      await asCustomer(me, 'get', '/profile').expect(401);

      // blocked twice is refused, and sign-in is refused
      const twice = await asStaff(superAdmin, 'post', `/${me.id}/block`, { reason: 'Again' }).expect(409);
      expect(errorCodeOf(twice)).toBe('INVALID_STATE_TRANSITION');
      const caller = client(context, uniqueIp());
      await caller.post('/api/v1/auth/otp/send').send({ phone: me.phone });
      const attempt = await caller.post('/api/v1/auth/otp/verify').send({ phone: me.phone, code: '000000' });
      expect(attempt.status).toBeGreaterThanOrEqual(400);

      const open = dataOf<CustomerDetailView>(await asStaff(superAdmin, 'post', `/${me.id}/unblock`).expect(201));
      expect(open).toMatchObject({ status: 'ACTIVE', blocked: null });
      await asStaff(superAdmin, 'post', `/${me.id}/unblock`).expect(409);
      const back = await signInAgain(me.phone);
      expect(back.user.id).toBe(me.id);
    });

    it('takes a proof file, and refuses one that was already used', async () => {
      const me = await newCustomer();
      const upload = async () =>
        dataOf<{ id: string }>(
          await client(context)
            .post('/api/v1/files/proofs')
            .set(...bearer(superAdmin.tokens))
            .attach('file', NOTE, { filename: 'note.txt' })
            .expect(201),
        );
      const proof = await upload();
      await asStaff(superAdmin, 'post', `/${me.id}/block`, {
        reason: 'Fake bookings',
        proofFileIds: [proof.id],
      }).expect(201);
      const stored = await context.connection
        .collection('proof_files')
        .findOne({ _id: new Types.ObjectId(proof.id) });
      expect(stored).toMatchObject({ subjectType: 'customer-block' });

      const other = await newCustomer();
      const refused = await asStaff(superAdmin, 'post', `/${other.id}/block`, {
        reason: 'Same proof',
        proofFileIds: [proof.id],
      }).expect(400);
      expect(errorCodeOf(refused)).toBe('VALIDATION_FAILED');
      // nothing changed for the second customer
      const detail = dataOf<CustomerDetailView>(await asStaff(superAdmin, 'get', `/${other.id}`).expect(200));
      expect(detail.status).toBe('ACTIVE');
    });
  });

  describe('sign out of all devices', () => {
    it('ends every session at once; the customer can sign in again', async () => {
      const me = await newCustomer();
      const second = await signInAgain(me.phone);
      const result = dataOf<{ signedOut: number }>(
        await asStaff(superAdmin, 'post', `/${me.id}/sessions/revoke`).expect(201),
      );
      expect(result.signedOut).toBe(2);
      expect(await refreshStatus(me.tokens)).toBe(401);
      expect(await refreshStatus(second)).toBe(401);
      await asStaff(support, 'post', `/${me.id}/sessions/revoke`).expect(403);
      await signInAgain(me.phone);
    });
  });

  describe('delete and restore by staff', () => {
    it('only a role that may delete can; a booking to travel on stops it', async () => {
      const me = await newCustomer();
      await asStaff(support, 'delete', `/${me.id}`).expect(403);
      const booking = await addBooking(me.id, 'CONFIRMED', 10000);
      const refused = await asStaff(superAdmin, 'delete', `/${me.id}`).expect(409);
      expect(JSON.stringify(refused.body)).toMatch(/booking to travel on|bookings to travel on/);
      await context.connection.collection('bookings').updateOne({ _id: booking }, { $set: { status: 'COMPLETED' } });

      await asStaff(superAdmin, 'delete', `/${me.id}`).expect(200);
      await asStaff(superAdmin, 'get', `/${me.id}`).expect(404);
      const listed = dataOf<CustomerRowView[]>(await asStaff(superAdmin, 'get', `?search=${me.phone.slice(-8)}`).expect(200));
      expect(listed.map((row) => row.id)).not.toContain(me.id);
      expect(await refreshStatus(me.tokens)).toBe(401);

      await asStaff(support, 'post', `/${me.id}/restore`).expect(403);
      const back = dataOf<CustomerDetailView>(await asStaff(superAdmin, 'post', `/${me.id}/restore`).expect(201));
      expect(back).toMatchObject({ id: me.id, status: 'ACTIVE' });
      await asStaff(superAdmin, 'post', `/${me.id}/restore`).expect(409);
      await signInAgain(me.phone);
    });

    it('cannot bring back an account the customer deleted themselves', async () => {
      const me = await newCustomer();
      await asCustomer(me, 'delete', '/account').expect(200);
      const refused = await asStaff(superAdmin, 'post', `/${me.id}/restore`).expect(409);
      expect(JSON.stringify(refused.body)).toMatch(/personal data is gone/);
    });
  });

  describe('my notification settings', () => {
    const all = (value: boolean) => ({ whatsapp: value, email: value, push: value });

    it('start with bookings and trips on and offers off, for a customer who never chose', async () => {
      const me = await newCustomer();
      const settings = dataOf<Record<string, Record<string, boolean>>>(
        await asCustomer(me, 'get', '/notification-settings').expect(200),
      );
      expect(settings).toEqual({ bookings: all(true), trips: all(true), offers: all(false) });
    });

    it('are saved per kind and channel, and stay saved', async () => {
      const me = await newCustomer();
      const chosen = {
        bookings: { whatsapp: false, email: true, push: true },
        trips: all(false),
        offers: { whatsapp: true, email: false, push: false },
      };
      await asCustomer(me, 'put', '/notification-settings', chosen).expect(200);
      const again = dataOf<typeof chosen>(await asCustomer(me, 'get', '/notification-settings').expect(200));
      expect(again).toEqual(chosen);
      const stored = await context.connection
        .collection('customers')
        .findOne({ userId: new Types.ObjectId(me.id) });
      expect(stored?.['notificationSettings']).toEqual(chosen);
    });

    it('refuse a set with a kind or a channel missing, and a staff account', async () => {
      const me = await newCustomer();
      await asCustomer(me, 'put', '/notification-settings', { bookings: all(true), trips: all(true) }).expect(400);
      await asCustomer(me, 'put', '/notification-settings', {
        bookings: { whatsapp: true, email: true },
        trips: all(true),
        offers: all(false),
      }).expect(400);
      await asCustomer({ tokens: support.tokens }, 'get', '/notification-settings').expect(403);
    });
  });

  describe('audit', () => {
    it('every change left an entry, and none holds a phone number or an email', async () => {
      const entries = await context.connection
        .collection('audit_logs')
        .find({ action: /^customer\./ })
        .toArray();
      const actions = new Set(entries.map((entry) => entry['action']));
      for (const action of [
        'customer.updated',
        'customer.blocked',
        'customer.unblocked',
        'customer.sessions-revoked',
        'customer.deleted',
        'customer.restored',
        'customer.account-deleted',
      ]) {
        expect(actions).toContain(action);
      }
      expect(JSON.stringify(entries)).not.toMatch(/@example|\+91\d{8}/);
    });
  });
});
