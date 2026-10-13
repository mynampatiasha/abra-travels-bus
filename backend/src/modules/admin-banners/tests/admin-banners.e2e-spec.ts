import {
  type AuthTestContext,
  client,
  createAuthTestApp,
  dataOf,
} from '../../authentication/tests/auth-e2e.harness';
import { seedAndSignIn, seedUser, signIn } from '../../rbac/tests/rbac-e2e.harness';
import { expectCode } from '../../trips/tests/catalogue-e2e.support';
import {
  ADMIN,
  api,
  type Api,
  type BannerBody,
  CITY_A,
  CITY_B,
  createBanner,
  inDays,
  PNG,
  PUBLIC,
  type PublicBannerBody,
} from './admin-banners-e2e.support';

/** Banners managed in the admin app and read by the customer app — real app, MongoDB, Redis. */
describe('Banners e2e', () => {
  let context: AuthTestContext;
  let superAdmin: Api;
  let manager: Api;
  let viewer: Api;
  let deleter: Api;
  let support: Api;

  /** A staff account holding exactly `permissions`, through ALLOW overrides. */
  async function staffWith(permissions: string[]): Promise<Api> {
    const user = await seedUser(context, { roleKeys: [], userType: 'STAFF' });
    for (const permission of permissions) {
      await superAdmin
        .put(`/api/v1/users/${user.id}/permissions/${permission}`, {
          effect: 'ALLOW',
          reason: 'banner tests',
        })
        .expect(200);
    }
    return api(context, await signIn(context, user));
  }

  const create = (body: object) => createBanner(superAdmin, body);

  beforeAll(async () => {
    context = await createAuthTestApp();
    await context.connection.collection('banners').deleteMany({});
    superAdmin = api(context, (await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] })).tokens);
    manager = await staffWith(['banners.read', 'banners.manage']);
    viewer = await staffWith(['banners.read']);
    deleter = await staffWith(['banners.delete']);
    support = api(context, (await seedAndSignIn(context, { roleKeys: ['SUPPORT'] })).tokens);
  }, 180_000);

  afterAll(async () => {
    await context.connection.collection('banners').deleteMany({});
    await context.close();
  }, 60_000);

  describe('permissions', () => {
    it('is closed without a token', async () => {
      await client(context).get(ADMIN).expect(401);
    });

    it('banners.manage lists, adds, edits, toggles and uploads, but cannot delete', async () => {
      await manager.get(ADMIN).expect(200);
      const created = dataOf<BannerBody>(
        await manager.post(ADMIN, { title: 'Monsoon sale' }).expect(201),
      );
      expect(created).toMatchObject({
        title: 'Monsoon sale',
        linkType: 'NONE',
        linkValue: '',
        isActive: true,
        status: 'LIVE',
        imageUrl: null,
      });
      await manager.get(`${ADMIN}/${created.id}`).expect(200);
      const edited = await manager
        .put(`${ADMIN}/${created.id}`, { subtitle: 'Up to 20% off' })
        .expect(200);
      expect(dataOf<{ subtitle: string }>(edited).subtitle).toBe('Up to 20% off');
      const toggled = await manager.post(`${ADMIN}/${created.id}/active`, { active: false });
      expect(toggled.status).toBe(201);
      expect(dataOf<BannerBody>(toggled).status).toBe('INACTIVE');
      await manager.upload(`${ADMIN}/${created.id}/image`, PNG, 'banner.png').expect(201);

      await expectCode(manager.delete(`${ADMIN}/${created.id}`), 403, 'PERMISSION_DENIED');
      await deleter.delete(`${ADMIN}/${created.id}`).expect(200);
      await expectCode(superAdmin.get(`${ADMIN}/${created.id}`), 404, 'RESOURCE_NOT_FOUND');
      // the delete is soft: Undo brings it back
      await expectCode(manager.post(`${ADMIN}/${created.id}/restore`), 403, 'PERMISSION_DENIED');
      await deleter.post(`${ADMIN}/${created.id}/restore`).expect(201);
      await superAdmin.get(`${ADMIN}/${created.id}`).expect(200);
    });

    it('banners.read alone can look but not change', async () => {
      const created = await create({ title: 'Look only' });
      await viewer.get(ADMIN).expect(200);
      await viewer.get(`${ADMIN}/${created.id}`).expect(200);
      await expectCode(viewer.post(ADMIN, { title: 'No' }), 403, 'PERMISSION_DENIED');
      await expectCode(
        viewer.put(`${ADMIN}/${created.id}`, { title: 'No' }),
        403,
        'PERMISSION_DENIED',
      );
      await expectCode(viewer.post(`${ADMIN}/${created.id}/duplicate`), 403, 'PERMISSION_DENIED');
      await expectCode(viewer.post(`${ADMIN}/${created.id}/archive`), 403, 'PERMISSION_DENIED');
    });

    it('without banners.read the list is refused', async () => {
      await expectCode(support.get(ADMIN), 403, 'PERMISSION_DENIED');
      await expectCode(deleter.get(ADMIN), 403, 'PERMISSION_DENIED');
    });

    it('refuses an empty edit and an unknown banner', async () => {
      const created = await create({ title: 'Edit me' });
      await expectCode(superAdmin.put(`${ADMIN}/${created.id}`, {}), 400, 'VALIDATION_FAILED');
      await expectCode(
        superAdmin.put(`${ADMIN}/64b000000000000000000fff`, { title: 'Nobody' }),
        404,
        'RESOURCE_NOT_FOUND',
      );
    });
  });

  describe('validation', () => {
    it('endsAt must be after startsAt, on creation and on an edit', async () => {
      await expectCode(
        superAdmin.post(ADMIN, { title: 'Bad dates', startsAt: inDays(2), endsAt: inDays(1) }),
        400,
        'VALIDATION_FAILED',
      );
      const created = await create({ title: 'Dated', startsAt: inDays(1), endsAt: inDays(5) });
      await expectCode(
        superAdmin.put(`${ADMIN}/${created.id}`, { endsAt: inDays(0) }),
        400,
        'VALIDATION_FAILED',
      );
    });

    it('a URL link must be https', async () => {
      await expectCode(
        superAdmin.post(ADMIN, { title: 'Insecure', linkType: 'URL', linkValue: 'http://x.in' }),
        400,
        'VALIDATION_FAILED',
      );
      const created = await create({
        title: 'Secure',
        linkType: 'URL',
        linkValue: 'https://abra.travel/offers',
      });
      expect(created.linkValue).toBe('https://abra.travel/offers');
      await expectCode(
        superAdmin.post(ADMIN, { title: 'External', externalImageUrl: 'http://cdn.in/a.png' }),
        400,
        'VALIDATION_FAILED',
      );
    });

    it('a route search link is two city ids', async () => {
      for (const linkValue of ['', 'bengaluru:tirupati', `${CITY_A}`, `${CITY_A}:${CITY_A}`]) {
        await expectCode(
          superAdmin.post(ADMIN, { title: 'Route', linkType: 'ROUTE_SEARCH', linkValue }),
          400,
          'VALIDATION_FAILED',
        );
      }
      const created = await create({
        title: 'Route',
        linkType: 'ROUTE_SEARCH',
        linkValue: `${CITY_A}:${CITY_B}`,
      });
      // Changing the type alone is checked against the stored value
      await expectCode(
        superAdmin.put(`${ADMIN}/${created.id}`, { linkType: 'URL' }),
        400,
        'VALIDATION_FAILED',
      );
      const cleared = await superAdmin
        .put(`${ADMIN}/${created.id}`, { linkType: 'NONE' })
        .expect(200);
      expect(dataOf<BannerBody>(cleared)).toMatchObject({ linkType: 'NONE', linkValue: '' });
    });

    it('on an edit, null clears an optional text or date', async () => {
      // What the admin app sends: start and end of a local day as UTC instants
      const created = await create({
        title: 'Clearable',
        subtitle: 'Weekend only',
        buttonText: 'Book',
        linkType: 'OFFER',
        linkValue: 'WEEKEND10',
        startsAt: '2026-10-09T18:30:00.000Z',
        endsAt: '2026-10-10T18:29:59.999Z',
        externalImageUrl: 'https://cdn.example.test/w.jpg',
      });
      const cleared = await superAdmin
        .put(`${ADMIN}/${created.id}`, {
          subtitle: null,
          buttonText: null,
          linkType: 'NONE',
          linkValue: null,
          startsAt: null,
          endsAt: null,
          externalImageUrl: null,
        })
        .expect(200);
      expect(dataOf<BannerBody & { subtitle: string; buttonText: string }>(cleared)).toMatchObject({
        subtitle: '',
        buttonText: '',
        linkType: 'NONE',
        linkValue: '',
        startsAt: null,
        endsAt: null,
        externalImageUrl: null,
        imageUrl: null,
      });
      await expectCode(
        superAdmin.put(`${ADMIN}/${created.id}`, { title: null }),
        400,
        'VALIDATION_FAILED',
      );
    });

    it('filters the admin list by status and search', async () => {
      const scheduled = await create({ title: 'Diwali preview', startsAt: inDays(3) });
      const list = await superAdmin.get(`${ADMIN}?status=SCHEDULED&search=diwali`).expect(200);
      const items = (list.body as { data: BannerBody[] }).data;
      expect(items.map((item) => item.id)).toEqual([scheduled.id]);
      expect(items[0]?.status).toBe('SCHEDULED');

      // The summary cards read the total of a one-item page
      const count = await superAdmin.get(`${ADMIN}?status=SCHEDULED&pageSize=1`).expect(200);
      expect((count.body as { meta: { total: number } }).meta.total).toBeGreaterThanOrEqual(1);
    });
  });

  describe('public list', () => {
    beforeAll(async () => {
      await context.connection.collection('banners').deleteMany({});
    });

    it('shows only live banners, in order, without a token', async () => {
      const second = await create({ title: 'Second', sortOrder: 2 });
      const first = await create({ title: 'First', sortOrder: 1 });
      await create({ title: 'Scheduled', startsAt: inDays(2) });
      await create({ title: 'Expired', startsAt: inDays(-5), endsAt: inDays(-1) });
      await create({ title: 'Inactive', isActive: false });
      await create({ title: 'Offers page', placement: 'OFFERS' });
      const windowed = await create({
        title: 'Windowed',
        sortOrder: 3,
        startsAt: inDays(-1),
        endsAt: inDays(1),
      });

      const response = await client(context).get(PUBLIC).expect(200);
      expect(response.headers['cache-control']).toBe('public, max-age=60');
      const items = dataOf<PublicBannerBody[]>(response);
      expect(items.map((item) => item.id)).toEqual([windowed.id, second.id, first.id]); // higher order shows first
      expect(Object.keys(items[0] ?? {}).sort()).toEqual(
        [
          'buttonText',
          'colourStyle',
          'desktopImageUrl',
          'id',
          'imageUrl',
          'linkType',
          'linkValue',
          'subtitle',
          'title',
        ].sort(),
      );

      const offers = dataOf<PublicBannerBody[]>(
        await client(context).get(`${PUBLIC}?placement=OFFERS`).expect(200),
      );
      expect(offers.map((item) => item.title)).toEqual(['Offers page']);
    });

    it('shows banners for every language and for the Accept-Language language', async () => {
      await create({ title: 'Telugu only', language: 'te', placement: 'OFFERS' });
      const titles = async (language?: string) => {
        const request = client(context).get(`${PUBLIC}?placement=OFFERS`);
        if (language) request.set('Accept-Language', language);
        return dataOf<PublicBannerBody[]>(await request.expect(200)).map((item) => item.title);
      };
      expect(await titles('te-IN,te;q=0.9')).toEqual(
        expect.arrayContaining(['Offers page', 'Telugu only']),
      );
      expect(await titles('kn')).toEqual(['Offers page']);
      expect(await titles()).toEqual(['Offers page']);
    });
  });
});
