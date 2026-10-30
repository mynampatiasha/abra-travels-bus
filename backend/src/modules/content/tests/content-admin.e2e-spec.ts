import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  errorCodeOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn, type SeededUser } from '../../rbac/tests/rbac-e2e.harness';
import {
  type ContactView,
  type FaqView,
  type PageView,
  type PublicPageView,
} from '../content_admin_manage.service';

type Caller = SeededUser & { tokens: Tokens };

const ADMIN_API = '/api/v1/admin/content';
const PUBLIC_API = '/api/v1/content';
const OWN_COLLECTIONS = ['content_pages', 'content_faqs', 'content_contact'];

/** Information pages, FAQs and contact details: admin writes, everyone reads. */
describe('Content e2e', () => {
  let context: AuthTestContext;
  let superAdmin: Caller;
  let support: Caller;

  const send = (
    who: Caller,
    method: 'get' | 'post' | 'put' | 'patch' | 'delete',
    path: string,
    body?: object,
  ) => {
    const request = client(context)[method](`${ADMIN_API}${path}`).set(...bearer(who.tokens));
    return body ? request.send(body) : request;
  };
  const publicGet = (path: string) => client(context).get(`${PUBLIC_API}${path}`);
  const faq = (overrides: Record<string, unknown> = {}) => ({
    question: 'How do I cancel a booking?',
    answer: 'Open My Trips, choose the trip and press Cancel.',
    category: 'Cancellation',
    status: 'PUBLISHED',
    ...overrides,
  });
  const wipe = async () => {
    for (const name of OWN_COLLECTIONS) {
      await context.connection.collection(name).deleteMany({});
    }
  };

  beforeAll(async () => {
    context = await createAuthTestApp();
    await wipe();
    superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    support = await seedAndSignIn(context, { roleKeys: ['SUPPORT'] });
  }, 120_000);

  afterAll(async () => {
    await wipe();
    await context.close();
  }, 60_000);

  describe('who can use it', () => {
    it('Super Admin reads and writes; Support and a signed-out caller cannot use the admin side', async () => {
      await send(superAdmin, 'get', '/pages').expect(200);
      await send(support, 'get', '/pages').expect(403);
      await send(support, 'put', '/pages/terms', {
        title: 'Terms',
        body: 'x',
        status: 'DRAFT',
      }).expect(403);
      await send(support, 'post', '/faqs', faq()).expect(403);
      await send(support, 'put', '/contact', {
        phone: '1',
        email: '',
        address: '',
        hours: '',
      }).expect(403);
      await client(context).get(`${ADMIN_API}/pages`).expect(401);
    });

    it('the public endpoints need no sign-in', async () => {
      await publicGet('/faqs').expect(200);
      await publicGet('/contact').expect(200);
    });
  });

  describe('information pages', () => {
    it('lists all three pages as empty drafts until someone writes them', async () => {
      const pages = dataOf<PageView[]>(await send(superAdmin, 'get', '/pages').expect(200));
      expect(pages.map((page) => page.key)).toEqual(['terms', 'privacy', 'about']);
      expect(pages.every((page) => page.status === 'DRAFT' && page.body === '')).toBe(true);
    });

    it('a draft is not shown to the public; a published page is', async () => {
      await send(superAdmin, 'put', '/pages/terms', {
        title: 'Terms and conditions',
        body: 'Draft text',
        status: 'DRAFT',
      }).expect(200);
      const hidden = await publicGet('/pages/terms').expect(404);
      expect(errorCodeOf(hidden)).toBe('RESOURCE_NOT_FOUND');

      const saved = dataOf<PageView>(
        await send(superAdmin, 'put', '/pages/terms', {
          title: 'Terms and conditions',
          body: 'You agree to travel safely.',
          status: 'PUBLISHED',
        }).expect(200),
      );
      expect(saved).toMatchObject({ key: 'terms', status: 'PUBLISHED' });
      expect(saved.updatedBy).not.toBe('');

      const shown = dataOf<PublicPageView>(await publicGet('/pages/terms').expect(200));
      expect(shown).toMatchObject({
        key: 'terms',
        title: 'Terms and conditions',
        body: 'You agree to travel safely.',
      });
      expect(shown).not.toHaveProperty('updatedBy');
    });

    it('unpublishing hides it again', async () => {
      await send(superAdmin, 'put', '/pages/terms', {
        title: 'Terms and conditions',
        body: 'You agree to travel safely.',
        status: 'DRAFT',
      }).expect(200);
      await publicGet('/pages/terms').expect(404);
    });

    it('refuses an empty page that is published, an empty title and an unknown page', async () => {
      await send(superAdmin, 'put', '/pages/privacy', {
        title: 'Privacy',
        body: '   ',
        status: 'PUBLISHED',
      }).expect(400);
      await send(superAdmin, 'put', '/pages/privacy', {
        title: '  ',
        body: 'Text',
        status: 'DRAFT',
      }).expect(400);
      await send(superAdmin, 'put', '/pages/refunds', {
        title: 'Refunds',
        body: 'Text',
        status: 'DRAFT',
      }).expect(400);
      await publicGet('/pages/refunds').expect(400);
    });
  });

  describe('FAQs', () => {
    it('adds, lists and changes a FAQ, and keeps the order staff set', async () => {
      const first = dataOf<FaqView>(await send(superAdmin, 'post', '/faqs', faq()).expect(201));
      const second = dataOf<FaqView>(
        await send(
          superAdmin,
          'post',
          '/faqs',
          faq({ question: 'Which payments work?', answer: 'UPI, cards and net banking.', category: 'Payments' }),
        ).expect(201),
      );
      expect(second.order).toBeGreaterThan(first.order);

      const changed = dataOf<FaqView>(
        await send(
          superAdmin,
          'patch',
          `/faqs/${second.id}`,
          faq({
            question: 'Which payments work?',
            answer: 'UPI and cards.',
            category: 'Payments',
            order: 0,
          }),
        ).expect(200),
      );
      expect(changed).toMatchObject({ answer: 'UPI and cards.', order: 0 });

      const listed = dataOf<FaqView[]>(await publicGet('/faqs').expect(200));
      expect(listed.map((item) => item.id)).toEqual([second.id, first.id]);
    });

    it('filters the admin list by search, status and category', async () => {
      await send(
        superAdmin,
        'post',
        '/faqs',
        faq({
          question: 'Hidden question',
          answer: 'Not ready yet.',
          category: 'Payments',
          status: 'DRAFT',
        }),
      ).expect(201);
      const body = (path: string) =>
        send(superAdmin, 'get', `/faqs${path}`).then((response) => {
          expect(response.status).toBe(200);
          return dataOf<FaqView[]>(response);
        });
      expect(await body('?status=DRAFT')).toHaveLength(1);
      expect(await body('?category=Payments')).toHaveLength(2);
      expect(await body('?search=cancel')).toHaveLength(1);
      expect(await body('?search=zzzz')).toHaveLength(0);
    });

    it('does not show a draft FAQ to the public, and a category narrows the public list', async () => {
      const listed = dataOf<FaqView[]>(await publicGet('/faqs').expect(200));
      expect(listed.some((item) => item.question === 'Hidden question')).toBe(false);
      const cancel = dataOf<FaqView[]>(await publicGet('/faqs?category=Cancellation').expect(200));
      expect(cancel).toHaveLength(1);
    });

    it('a deleted FAQ disappears from both lists and cannot be changed', async () => {
      const [target] = dataOf<FaqView[]>(await publicGet('/faqs').expect(200));
      expect(target).toBeDefined();
      await send(superAdmin, 'delete', `/faqs/${target?.id}`).expect(200);
      const listed = dataOf<FaqView[]>(await publicGet('/faqs').expect(200));
      expect(listed.some((item) => item.id === target?.id)).toBe(false);
      await send(superAdmin, 'patch', `/faqs/${target?.id}`, faq()).expect(404);
      await send(superAdmin, 'delete', `/faqs/${target?.id}`).expect(404);
    });

    it('refuses an empty question or answer and a bad id', async () => {
      await send(superAdmin, 'post', '/faqs', faq({ question: ' ' })).expect(400);
      await send(superAdmin, 'post', '/faqs', faq({ answer: '' })).expect(400);
      await send(superAdmin, 'patch', '/faqs/not-an-id', faq()).expect(400);
    });
  });

  describe('contact details', () => {
    it('is not configured until saved, then everyone reads what staff saved', async () => {
      const empty = dataOf<ContactView>(await publicGet('/contact').expect(200));
      expect(empty).toMatchObject({ configured: false, phone: '', email: '' });

      const saved = dataOf<ContactView>(
        await send(superAdmin, 'put', '/contact', {
          phone: '+91 40 1234 5678',
          email: 'help@abra.example',
          address: 'Hyderabad',
          hours: '8am to 10pm, every day',
        }).expect(200),
      );
      expect(saved).toMatchObject({ configured: true, email: 'help@abra.example' });
      const shown = dataOf<ContactView>(await publicGet('/contact').expect(200));
      expect(shown).toMatchObject({ phone: '+91 40 1234 5678', hours: '8am to 10pm, every day' });
    });

    it('needs a phone or an email, and a valid email', async () => {
      await send(superAdmin, 'put', '/contact', {
        phone: '',
        email: '',
        address: 'x',
        hours: 'x',
      }).expect(400);
      await send(superAdmin, 'put', '/contact', {
        phone: '1',
        email: 'not-an-email',
        address: '',
        hours: '',
      }).expect(400);
    });
  });

  describe('audit', () => {
    it('every change left an audit entry with the right action', async () => {
      const actions = await context.connection
        .collection('audit_logs')
        .distinct('action', { action: /^content\./ });
      expect(actions.sort()).toEqual([
        'content.contact.saved',
        'content.faq.created',
        'content.faq.deleted',
        'content.faq.updated',
        'content.page.saved',
      ]);
    });
  });
});
