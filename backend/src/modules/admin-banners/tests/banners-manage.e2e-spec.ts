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
  createBanner,
  PNG,
  PUBLIC,
  type PublicBannerBody,
} from './admin-banners-e2e.support';

interface OrderEntry {
  id: string;
  sortOrder: number;
}

/** Phase 1 step 2: duplicate, archive, un-archive and move banners — real app and storage. */
describe('Banners e2e: duplicate, archive, move', () => {
  let context: AuthTestContext;
  let superAdmin: Api;
  let viewer: Api;

  const create = (body: object) => createBanner(superAdmin, body);
  const fetchOrder = async (placement = 'HOME_TOP'): Promise<string[]> =>
    dataOf<BannerBody[]>(
      await superAdmin.get(`${ADMIN}?placement=${placement}&pageSize=100`).expect(200),
    )
      .filter((banner) => banner.status !== 'ARCHIVED')
      .map((banner) => banner.id);

  beforeAll(async () => {
    context = await createAuthTestApp();
    await context.connection.collection('banners').deleteMany({});
    superAdmin = api(context, (await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] })).tokens);
    const user = await seedUser(context, { roleKeys: [], userType: 'STAFF' });
    await superAdmin
      .put(`/api/v1/users/${user.id}/permissions/banners.read`, { effect: 'ALLOW', reason: 'test' })
      .expect(200);
    viewer = api(context, await signIn(context, user));
  }, 180_000);

  afterAll(async () => {
    await context.connection.collection('banners').deleteMany({});
    await context.close();
  }, 60_000);

  describe('duplicate', () => {
    it('makes an unpublished copy with its own copy of the images', async () => {
      const original = await create({
        title: 'Festive special',
        subtitle: 'Flat 15% off',
        linkType: 'OFFER',
        linkValue: 'WEEKEND15',
        sortOrder: 5,
      });
      await superAdmin.upload(`${ADMIN}/${original.id}/image`, PNG, 'm.png').expect(201);
      await superAdmin
        .upload(`${ADMIN}/${original.id}/image?variant=desktop`, PNG, 'd.png')
        .expect(201);

      const copy = dataOf<BannerBody>(
        await superAdmin.post(`${ADMIN}/${original.id}/duplicate`).expect(201),
      );
      expect(copy).toMatchObject({
        title: 'Festive special (copy)',
        linkType: 'OFFER',
        linkValue: 'WEEKEND15',
        isActive: false,
        status: 'INACTIVE',
      });
      expect(copy.id).not.toBe(original.id);
      expect(copy.imageUrl).toMatch(/^banners\//);
      expect(copy.desktopImageUrl).toMatch(/variant=desktop/);

      const stored = (await context.connection
        .collection('banners')
        .find({})
        .toArray()) as Array<{ imageKey?: string | null; desktopImageKey?: string | null }>;
      const keys = stored
        .flatMap((row) => [row.imageKey, row.desktopImageKey])
        .filter((key): key is string => Boolean(key));
      expect(new Set(keys).size).toBe(4); // two images each, no key shared

      // removing the copy's image leaves the original's alone
      await superAdmin.delete(`${ADMIN}/${copy.id}/image`).expect(200);
      await client(context).get(`${PUBLIC}/${original.id}/image`).expect(200);
    });

    it('keeps the title within 80 characters and refuses an unknown banner', async () => {
      const long = await create({ title: 'x'.repeat(80) });
      const copy = dataOf<BannerBody>(
        await superAdmin.post(`${ADMIN}/${long.id}/duplicate`).expect(201),
      );
      expect(copy.title).toHaveLength(80);
      expect(copy.title.endsWith(' (copy)')).toBe(true);
      await expectCode(
        superAdmin.post(`${ADMIN}/64b000000000000000000fff/duplicate`),
        404,
        'RESOURCE_NOT_FOUND',
      );
    });
  });

  describe('archive', () => {
    it('puts a live banner away: not shown, own status, filter, and back as a draft', async () => {
      await context.connection.collection('banners').deleteMany({});
      const live = await create({ title: 'Live one' });
      const before = dataOf<PublicBannerBody[]>(await client(context).get(PUBLIC).expect(200));
      expect(before.map((banner) => banner.id)).toContain(live.id);

      const archived = dataOf<BannerBody>(
        await superAdmin.post(`${ADMIN}/${live.id}/archive`, { reason: 'Season over' }).expect(201),
      );
      expect(archived).toMatchObject({ status: 'ARCHIVED', isActive: false });
      const after = dataOf<PublicBannerBody[]>(await client(context).get(PUBLIC).expect(200));
      expect(after.map((banner) => banner.id)).not.toContain(live.id);

      const filtered = dataOf<BannerBody[]>(
        await superAdmin.get(`${ADMIN}?status=ARCHIVED`).expect(200),
      );
      expect(filtered.map((banner) => banner.id)).toEqual([live.id]);
      const drafts = dataOf<BannerBody[]>(
        await superAdmin.get(`${ADMIN}?status=INACTIVE`).expect(200),
      );
      expect(drafts.map((banner) => banner.id)).not.toContain(live.id);

      // archiving again changes nothing; un-archiving gives a draft, not a live banner
      await superAdmin.post(`${ADMIN}/${live.id}/archive`).expect(201);
      const back = dataOf<BannerBody>(
        await superAdmin.post(`${ADMIN}/${live.id}/unarchive`).expect(201),
      );
      expect(back).toMatchObject({ status: 'INACTIVE', isActive: false });
    });

    it('publishing an archived banner un-archives nothing by itself: it stays out until put back', async () => {
      const banner = await create({ title: 'Stay away' });
      await superAdmin.post(`${ADMIN}/${banner.id}/archive`).expect(201);
      const published = dataOf<BannerBody>(
        await superAdmin.post(`${ADMIN}/${banner.id}/active`, { active: true }).expect(201),
      );
      expect(published.status).toBe('ARCHIVED');
      const shown = dataOf<PublicBannerBody[]>(await client(context).get(PUBLIC).expect(200));
      expect(shown.map((entry) => entry.id)).not.toContain(banner.id);
    });
  });

  describe('move up and down', () => {
    it('moves one place, ignores the ends, skips archived banners, and audits', async () => {
      await context.connection.collection('banners').deleteMany({});
      const a = await create({ title: 'Aa', sortOrder: 1 });
      const b = await create({ title: 'Bb', sortOrder: 2 });
      const c = await create({ title: 'Cc', sortOrder: 3 });
      const gone = await create({ title: 'Gone', sortOrder: 2 });
      await superAdmin.post(`${ADMIN}/${gone.id}/archive`).expect(201);

      // higher order shows first
      expect(await fetchOrder()).toEqual([c.id, b.id, a.id]);

      const down = dataOf<OrderEntry[]>(
        await superAdmin.patch(`${ADMIN}/order`, { id: c.id, direction: 'down' }).expect(200),
      );
      expect(down.map((entry) => entry.id)).toEqual([b.id, c.id, a.id]);
      expect(await fetchOrder()).toEqual([b.id, c.id, a.id]);

      const up = dataOf<OrderEntry[]>(
        await superAdmin.patch(`${ADMIN}/order`, { id: a.id, direction: 'up' }).expect(200),
      );
      expect(up.map((entry) => entry.id)).toEqual([b.id, a.id, c.id]);

      // first up and last down are no-ops
      const same = dataOf<OrderEntry[]>(
        await superAdmin.patch(`${ADMIN}/order`, { id: b.id, direction: 'up' }).expect(200),
      );
      expect(same.map((entry) => entry.id)).toEqual([b.id, a.id, c.id]);

      // the customer app shows the same order
      const shown = dataOf<PublicBannerBody[]>(await client(context).get(PUBLIC).expect(200));
      expect(shown.map((entry) => entry.id)).toEqual([b.id, a.id, c.id]);

      const entries = dataOf<{ action: string }[]>(
        await superAdmin.get(`/api/v1/audit-logs?entityId=${c.id}&pageSize=50`).expect(200),
      );
      expect(entries.filter((entry) => entry.action === 'banner.updated').length).toBeGreaterThan(
        0,
      );
    });

    it('refuses a bad body and an unknown banner', async () => {
      await expectCode(
        superAdmin.patch(`${ADMIN}/order`, { id: 'nope', direction: 'up' }),
        400,
        'VALIDATION_FAILED',
      );
      await expectCode(
        superAdmin.patch(`${ADMIN}/order`, { id: '64b000000000000000000fff', direction: 'up' }),
        404,
        'RESOURCE_NOT_FOUND',
      );
    });
  });

  describe('the fields of the demo form', () => {
    it('keeps colour style and audience, and links to an operator', async () => {
      await context.connection.collection('banners').deleteMany({});
      const defaults = await create({ title: 'Defaults' });
      expect(defaults).toMatchObject({ colourStyle: 'NAVY_BLUE', audience: 'ALL' });

      const operatorId = '64b0000000000000000000c3';
      const styled = await create({
        title: 'For operators',
        colourStyle: 'GREEN_NAVY',
        audience: 'SIGNED_IN',
        linkType: 'OPERATOR',
        linkValue: operatorId,
      });
      expect(styled).toMatchObject({
        colourStyle: 'GREEN_NAVY',
        audience: 'SIGNED_IN',
        linkType: 'OPERATOR',
        linkValue: operatorId,
      });
      await expectCode(
        superAdmin.post(ADMIN, { title: 'Bad operator', linkType: 'OPERATOR', linkValue: 'abc' }),
        400,
        'VALIDATION_FAILED',
      );
      await expectCode(
        superAdmin.post(ADMIN, { title: 'Bad style', colourStyle: 'PINK' }),
        400,
        'VALIDATION_FAILED',
      );
      const edited = dataOf<BannerBody>(
        await superAdmin.put(`${ADMIN}/${defaults.id}`, { colourStyle: 'BLUE_SKY' }).expect(200),
      );
      expect(edited).toMatchObject({ colourStyle: 'BLUE_SKY' });
    });

    it('shows each audience only to the people it is meant for', async () => {
      await context.connection.collection('banners').deleteMany({});
      const all = await create({ title: 'For all', audience: 'ALL' });
      const fresh = await create({ title: 'For new', audience: 'NEW_USERS' });
      const signed = await create({ title: 'For signed in', audience: 'SIGNED_IN' });
      const idsFor = async (viewer?: string) =>
        dataOf<PublicBannerBody[]>(
          await client(context)
            .get(viewer ? `${PUBLIC}?viewer=${viewer}` : PUBLIC)
            .expect(200),
        )
          .map((banner) => banner.id)
          .sort();

      expect(await idsFor()).toEqual([all.id, fresh.id].sort()); // a guest by default
      expect(await idsFor('GUEST')).toEqual([all.id, fresh.id].sort());
      expect(await idsFor('NEW_USER')).toEqual([all.id, fresh.id, signed.id].sort());
      expect(await idsFor('RETURNING')).toEqual([all.id, signed.id].sort());
      await client(context).get(`${PUBLIC}?viewer=NOBODY`).expect(400);
    });
  });

  describe('permissions', () => {
    it('banners.read alone can open the list but not duplicate, archive or move', async () => {
      const banner = await create({ title: 'Guarded' });
      await viewer.get(ADMIN).expect(200);
      const attempts: Array<() => PromiseLike<import('supertest').Response>> = [
        () => viewer.post(`${ADMIN}/${banner.id}/duplicate`),
        () => viewer.post(`${ADMIN}/${banner.id}/archive`),
        () => viewer.post(`${ADMIN}/${banner.id}/unarchive`),
        () => viewer.patch(`${ADMIN}/order`, { id: banner.id, direction: 'up' }),
      ];
      for (const attempt of attempts) await expectCode(attempt(), 403, 'PERMISSION_DENIED');
    });
  });
});
