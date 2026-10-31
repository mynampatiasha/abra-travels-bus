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
  signInWithOtp,
  type Tokens,
  uniqueIp,
  uniquePhone,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';
import {
  type TicketDetailView,
  type TicketView,
} from '../support_admin_manage.service';

type Caller = SeededUser & { tokens: Tokens };
type Method = 'get' | 'post' | 'patch' | 'put' | 'delete';
interface Person {
  tokens: Tokens;
  id: string;
}

const NOTE = Buffer.from('Screenshot of the failed payment.\n', 'utf8');

/** Support tickets: a customer raises and follows them, staff answer them. */
describe('Support tickets e2e', () => {
  let context: AuthTestContext;
  let storageRoot: string;
  let superAdmin: Caller;
  let support: Caller;
  let accounts: Caller;

  const asStaff = (who: Caller, method: Method, path: string, body?: object) => {
    const request = client(context)[method](`/api/v1/admin/support${path}`).set(...bearer(who.tokens));
    return body ? request.send(body) : request;
  };
  const asCustomer = (who: Pick<Person, 'tokens'>, method: Method, path: string, body?: object) => {
    const request = client(context)[method](`/api/v1/customer/support${path}`).set(...bearer(who.tokens));
    return body ? request.send(body) : request;
  };
  const newCustomer = async (): Promise<Person> => {
    const tokens = await signInWithOtp(context, uniquePhone(), uniqueIp());
    return { tokens, id: tokens.user.id };
  };
  const upload = async (who: Pick<Person, 'tokens'>) =>
    dataOf<{ id: string }>(
      await client(context)
        .post('/api/v1/files/proofs')
        .set(...bearer(who.tokens))
        .attach('file', NOTE, { filename: 'note.txt' })
        .expect(201),
    );
  const raise = async (who: Person, overrides: Record<string, unknown> = {}) =>
    dataOf<TicketDetailView>(
      await asCustomer(who, 'post', '/tickets', {
        category: 'PAYMENT',
        message: 'My payment failed but the money was taken.',
        bookingRef: 'abr12345',
        ...overrides,
      }).expect(201),
    );

  beforeAll(async () => {
    storageRoot = await mkdtemp(join(tmpdir(), 'abra-support-e2e-'));
    process.env.STORAGE_LOCAL_ROOT = storageRoot;
    context = await createAuthTestApp();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    support = await seedAndSignIn(context, { roleKeys: ['SUPPORT'] });
    accounts = await seedAndSignIn(context, { roleKeys: ['ACCOUNTS'] });
  }, 120_000);

  afterAll(async () => {
    await context.close();
    await rm(storageRoot, { recursive: true, force: true });
  }, 60_000);

  describe('a customer raises a ticket', () => {
    it('with a category and message; it starts open with a time limit, and the booking number stays text', async () => {
      const me = await newCustomer();
      const ticket = await raise(me);
      expect(ticket).toMatchObject({
        status: 'OPEN',
        priority: 'NORMAL',
        category: 'PAYMENT',
        bookingRef: 'ABR12345',
        overdue: false,
        lastReplyBy: 'CUSTOMER',
        replies: [],
        proofs: [],
      });
      expect(ticket.ticketNumber).toMatch(/^TK-\d+$/);
      expect(new Date(ticket.respondBy ?? '').getTime()).toBeGreaterThan(Date.now() + 23 * 3600 * 1000);
    });

    it('keeps the subject, or uses the first line of the message when there is none', async () => {
      const me = await newCustomer();
      const titled = await raise(me, { subject: 'Payment failed twice' });
      expect(titled.subject).toBe('Payment failed twice');
      const plain = await raise(me, { message: ['Refund is late', 'It has been ten days.'].join(String.fromCharCode(10)) });
      expect(plain.subject).toBe('Refund is late');
    });

    it('with a proof file that both the customer and staff can see', async () => {
      const me = await newCustomer();
      const proof = await upload(me);
      const ticket = await raise(me, { proofFileIds: [proof.id] });
      expect(ticket.proofs.map((file) => file.id)).toEqual([proof.id]);
      const asStaffView = dataOf<TicketDetailView>(await asStaff(support, 'get', `/tickets/${ticket.id}`).expect(200));
      expect(asStaffView.proofs).toHaveLength(1);
      // the same proof cannot be used for a second ticket, and the second ticket is not created
      const before = dataOf<TicketView[]>(await asCustomer(me, 'get', '/tickets').expect(200)).length;
      await asCustomer(me, 'post', '/tickets', {
        category: 'OTHER',
        message: 'Reusing a file',
        proofFileIds: [proof.id],
      }).expect(400);
      const after = dataOf<TicketView[]>(await asCustomer(me, 'get', '/tickets').expect(200)).length;
      expect(after).toBe(before);
    });

    it('refuses an empty message, an unknown category, and a staff account', async () => {
      const me = await newCustomer();
      await asCustomer(me, 'post', '/tickets', { category: 'PAYMENT', message: '   ' }).expect(400);
      await asCustomer(me, 'post', '/tickets', { category: 'WEATHER', message: 'Hello' }).expect(400);
      await asCustomer({ tokens: support.tokens }, 'post', '/tickets', {
        category: 'OTHER',
        message: 'I am staff',
      }).expect(403);
      await client(context).get('/api/v1/customer/support/tickets').expect(401);
    });

    it('sees only their own tickets', async () => {
      const me = await newCustomer();
      const other = await newCustomer();
      const mine = await raise(me);
      await raise(other, { message: 'Someone elses problem' });
      const listed = dataOf<TicketView[]>(await asCustomer(me, 'get', '/tickets').expect(200));
      expect(listed.map((ticket) => ticket.id)).toEqual([mine.id]);
      await asCustomer(other, 'get', `/tickets/${mine.id}`).expect(404);
      await asCustomer(other, 'post', `/tickets/${mine.id}/replies`, { message: 'Hello' }).expect(404);
    });
  });

  describe('who can use the admin side', () => {
    it('Super Admin and Support read; Accounts, a customer and a signed-out caller do not', async () => {
      await asStaff(superAdmin, 'get', '/tickets').expect(200);
      await asStaff(support, 'get', '/tickets').expect(200);
      await asStaff(accounts, 'get', '/tickets').expect(403);
      const me = await newCustomer();
      await asStaff({ ...support, tokens: me.tokens }, 'get', '/tickets').expect(403);
      await client(context).get('/api/v1/admin/support/tickets').expect(401);
    });
  });

  describe('the admin list', () => {
    it('filters by status, category, priority, search, overdue and mine', async () => {
      const me = await newCustomer();
      const refund = await raise(me, { category: 'REFUND', message: 'Where is my refund zebra?' });
      const late = await raise(me, { category: 'TRIP', message: 'Bus never came' });
      await context.connection
        .collection('support_tickets')
        .updateOne({ _id: new Types.ObjectId(late.id) }, { $set: { respondBy: new Date(Date.now() - 3600_000) } });
      await asStaff(superAdmin, 'patch', `/tickets/${refund.id}`, { priority: 'HIGH' }).expect(200);
      await asStaff(superAdmin, 'post', `/tickets/${refund.id}/assign`, { assignToMe: true }).expect(201);

      const ids = async (query: string) =>
        dataOf<TicketView[]>(await asStaff(superAdmin, 'get', `/tickets?${query}`).expect(200)).map((t) => t.id);

      expect(await ids('search=zebra')).toEqual([refund.id]);
      expect(await ids('category=TRIP&search=never')).toEqual([late.id]);
      expect(await ids('priority=HIGH')).toEqual([refund.id]);
      expect(await ids('status=IN_PROGRESS&search=zebra')).toEqual([refund.id]);
      expect(await ids('mine=true')).toEqual([refund.id]);
      expect(await ids('overdue=true')).toEqual([late.id]);
      const overdue = dataOf<TicketView[]>(await asStaff(superAdmin, 'get', '/tickets?overdue=true').expect(200));
      expect(overdue[0]).toMatchObject({ overdue: true });
      await asStaff(superAdmin, 'get', '/tickets?status=NOPE').expect(400);
    });
  });

  describe('answering a ticket', () => {
    it('taking it starts the work; giving it back keeps it in progress without an owner', async () => {
      const me = await newCustomer();
      const ticket = await raise(me);
      const taken = dataOf<TicketDetailView>(
        await asStaff(support, 'post', `/tickets/${ticket.id}/assign`, { assignToMe: true }).expect(201),
      );
      expect(taken).toMatchObject({ status: 'IN_PROGRESS', assignedToMe: true });
      expect(taken.assignedToName).not.toBe('');
      const back = dataOf<TicketDetailView>(
        await asStaff(support, 'post', `/tickets/${ticket.id}/assign`, { assignToMe: false }).expect(201),
      );
      expect(back).toMatchObject({ assignedToMe: false, assignedToName: '' });
    });

    it('a reply reaches the customer and stops the time limit; an empty reply is refused', async () => {
      const me = await newCustomer();
      const ticket = await raise(me);
      await asStaff(support, 'post', `/tickets/${ticket.id}/reply`, { message: '   ' }).expect(400);
      await asStaff(accounts, 'post', `/tickets/${ticket.id}/reply`, { message: 'Hi' }).expect(403);

      const replied = dataOf<TicketDetailView>(
        await asStaff(support, 'post', `/tickets/${ticket.id}/reply`, { message: 'We are checking with the bank.' }).expect(201),
      );
      expect(replied).toMatchObject({ status: 'IN_PROGRESS', respondBy: null, overdue: false, lastReplyBy: 'STAFF' });
      expect(replied.replies).toHaveLength(1);

      const seen = dataOf<TicketDetailView>(await asCustomer(me, 'get', `/tickets/${ticket.id}`).expect(200));
      expect(seen.replies.map((reply) => [reply.authorType, reply.body])).toEqual([
        ['STAFF', 'We are checking with the bank.'],
      ]);
      expect(seen.status).toBe('IN_PROGRESS');
    });

    it('a customer message starts the time limit again', async () => {
      const me = await newCustomer();
      const ticket = await raise(me);
      await asStaff(support, 'post', `/tickets/${ticket.id}/reply`, { message: 'Please send the screenshot.' }).expect(201);
      const written = dataOf<TicketDetailView>(
        await asCustomer(me, 'post', `/tickets/${ticket.id}/replies`, { message: 'Here it is.' }).expect(201),
      );
      expect(written.lastReplyBy).toBe('CUSTOMER');
      expect(written.respondBy).not.toBeNull();
      expect(written.replies).toHaveLength(2);
      await asCustomer(me, 'post', `/tickets/${ticket.id}/replies`, { message: '  ' }).expect(400);
    });

    it('resolve, reopen, and a customer message on a resolved ticket opens it again', async () => {
      const me = await newCustomer();
      const ticket = await raise(me);
      const done = dataOf<TicketDetailView>(await asStaff(support, 'post', `/tickets/${ticket.id}/resolve`).expect(201));
      expect(done).toMatchObject({ status: 'RESOLVED', respondBy: null });
      const again = await asStaff(support, 'post', `/tickets/${ticket.id}/resolve`).expect(409);
      expect(errorCodeOf(again)).toBe('INVALID_STATE_TRANSITION');
      await asStaff(support, 'post', `/tickets/${ticket.id}/reply`, { message: 'Too late' }).expect(409);
      await asStaff(support, 'post', `/tickets/${ticket.id}/assign`, { assignToMe: true }).expect(409);

      const reopened = dataOf<TicketDetailView>(await asStaff(support, 'post', `/tickets/${ticket.id}/reopen`).expect(201));
      expect(reopened.status).toBe('OPEN');
      expect(reopened.respondBy).not.toBeNull();
      await asStaff(support, 'post', `/tickets/${ticket.id}/reopen`).expect(409);

      await asStaff(support, 'post', `/tickets/${ticket.id}/resolve`).expect(201);
      const byCustomer = dataOf<TicketDetailView>(
        await asCustomer(me, 'post', `/tickets/${ticket.id}/replies`, { message: 'It is still not fixed.' }).expect(201),
      );
      expect(byCustomer.status).toBe('OPEN');
      const stored = await context.connection
        .collection('support_tickets')
        .findOne({ _id: new Types.ObjectId(ticket.id) });
      expect(stored?.['reopenedCount']).toBe(2);
    });
  });

  describe('ready-made replies', () => {
    it('are added, listed and removed by staff who may manage; Accounts cannot', async () => {
      await asStaff(accounts, 'post', '/canned-replies', { title: 'Hi', body: 'Hello' }).expect(403);
      await asStaff(support, 'post', '/canned-replies', { title: '  ', body: 'Hello' }).expect(400);
      const created = dataOf<{ id: string; title: string }>(
        await asStaff(support, 'post', '/canned-replies', {
          title: 'Refund timeline',
          body: 'Refunds reach your account in 5 to 7 working days.',
        }).expect(201),
      );
      const listed = dataOf<Array<{ id: string }>>(await asStaff(support, 'get', '/canned-replies').expect(200));
      expect(listed.map((item) => item.id)).toContain(created.id);
      await asStaff(support, 'delete', `/canned-replies/${created.id}`).expect(200);
      await asStaff(support, 'delete', `/canned-replies/${created.id}`).expect(404);
    });
  });

  describe('audit', () => {
    it('every staff change left an entry, and none holds what the customer wrote', async () => {
      const entries = await context.connection.collection('audit_logs').find({ action: /^support\./ }).toArray();
      const actions = new Set(entries.map((entry) => entry['action']));
      for (const action of [
        'support.ticket.assigned',
        'support.ticket.replied',
        'support.ticket.resolved',
        'support.ticket.reopened',
        'support.ticket.updated',
        'support.canned.created',
        'support.canned.deleted',
      ]) {
        expect(actions).toContain(action);
      }
      expect(JSON.stringify(entries)).not.toMatch(/money was taken|zebra|screenshot/i);
    });
  });
});
