import { Types } from 'mongoose';
import {
  type AuthTestContext,
  client,
  createAuthTestApp,
  dataOf,
} from '../../authentication/tests/auth-e2e.harness';
import { FILE_STORAGE, type FileStorage } from '../../files/storage/file-storage';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
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
  WEBP,
} from './admin-banners-e2e.support';

/** Banner images (mobile and desktop): upload, serve, replace, remove — real app and storage. */
describe('Banner images e2e', () => {
  let context: AuthTestContext;
  let superAdmin: Api;
  const create = (body: object) => createBanner(superAdmin, body);

  beforeAll(async () => {
    context = await createAuthTestApp();
    await context.connection.collection('banners').deleteMany({});
    superAdmin = api(context, (await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] })).tokens);
  }, 180_000);

  afterAll(async () => {
    await context.connection.collection('banners').deleteMany({});
    await context.close();
  }, 60_000);

  it('stores a PNG and serves it publicly', async () => {
    const banner = await create({ title: 'With image' });
    const uploaded = dataOf<BannerBody>(
      await superAdmin.upload(`${ADMIN}/${banner.id}/image`, PNG, 'banner.png').expect(201),
    );
    expect(uploaded.imageUrl).toMatch(new RegExp(`^banners/${banner.id}/image\\?v=\\d+$`));

    const image = await client(context)
      .get(`/api/v1/${uploaded.imageUrl ?? ''}`)
      .buffer(true)
      .expect(200);
    expect(image.headers['content-type']).toBe('image/png');
    expect(image.headers['cache-control']).toBe('public, max-age=86400');
    expect(image.headers['x-content-type-options']).toBe('nosniff');
    expect(Buffer.compare(image.body as Buffer, PNG)).toBe(0);

    // A new upload replaces the old image and changes the address
    const replaced = dataOf<BannerBody>(
      await superAdmin.upload(`${ADMIN}/${banner.id}/image`, WEBP, 'banner.webp').expect(201),
    );
    const webp = await client(context).get(`${PUBLIC}/${banner.id}/image`).expect(200);
    expect(webp.headers['content-type']).toBe('image/webp');
    expect(replaced.imageUrl).not.toBe(uploaded.imageUrl);

    const audit = await context.connection
      .collection('audit_logs')
      .countDocuments({ entityType: 'banner', action: 'banner.image-changed' });
    expect(audit).toBeGreaterThanOrEqual(2);
  });

  it('keeps a separate desktop image next to the mobile one', async () => {
    const banner = await create({ title: 'Wide screens' });
    const mobile = dataOf<BannerBody>(
      await superAdmin.upload(`${ADMIN}/${banner.id}/image`, PNG, 'mobile.png').expect(201),
    );
    const desktop = dataOf<BannerBody>(
      await superAdmin
        .upload(`${ADMIN}/${banner.id}/image?variant=desktop`, WEBP, 'desktop.webp')
        .expect(201),
    );
    expect(desktop.imageUrl).toBe(mobile.imageUrl);
    expect(desktop.desktopImageUrl).toMatch(
      new RegExp(`^banners/${banner.id}/image\\?variant=desktop&v=\\d+$`),
    );

    const live = dataOf<PublicBannerBody[]>(await client(context).get(PUBLIC).expect(200));
    const listed = live.find((item) => item.id === banner.id);
    expect(listed).toMatchObject({
      imageUrl: mobile.imageUrl,
      desktopImageUrl: desktop.desktopImageUrl,
    });

    const wide = await client(context)
      .get(`/api/v1/${desktop.desktopImageUrl ?? ''}`)
      .buffer(true)
      .expect(200);
    expect(wide.headers['content-type']).toBe('image/webp');
    const narrow = await client(context).get(`${PUBLIC}/${banner.id}/image`).expect(200);
    expect(narrow.headers['content-type']).toBe('image/png');

    const removed = dataOf<BannerBody>(
      await superAdmin.delete(`${ADMIN}/${banner.id}/image?variant=desktop`).expect(200),
    );
    expect(removed.desktopImageUrl).toBeNull();
    expect(removed.imageUrl).toBe(mobile.imageUrl);
    await expectCode(
      client(context).get(`${PUBLIC}/${banner.id}/image?variant=desktop`),
      404,
      'RESOURCE_NOT_FOUND',
    );
    await client(context).get(`${PUBLIC}/${banner.id}/image`).expect(200);
    await expectCode(
      superAdmin.upload(`${ADMIN}/${banner.id}/image?variant=wide`, PNG, 'x.png'),
      400,
      'VALIDATION_FAILED',
    );
  });

  it('takes an external desktop image address and clears it with null', async () => {
    const banner = await create({
      title: 'Imported wide',
      externalDesktopImageUrl: 'https://cdn.example.test/wide.jpg',
    });
    expect(banner).toMatchObject({
      desktopImageUrl: 'https://cdn.example.test/wide.jpg',
      externalDesktopImageUrl: 'https://cdn.example.test/wide.jpg',
      imageUrl: null,
    });
    await expectCode(
      superAdmin.put(`${ADMIN}/${banner.id}`, { externalDesktopImageUrl: 'http://x.in/a.jpg' }),
      400,
      'VALIDATION_FAILED',
    );
    const cleared = await superAdmin
      .put(`${ADMIN}/${banner.id}`, { externalDesktopImageUrl: null })
      .expect(200);
    expect(dataOf<BannerBody>(cleared)).toMatchObject({
      desktopImageUrl: null,
      externalDesktopImageUrl: null,
    });
  });

  it('deleting a banner keeps its images, so Undo brings the banner back whole', async () => {
    const banner = await create({ title: 'Delete both' });
    await superAdmin.upload(`${ADMIN}/${banner.id}/image`, PNG, 'm.png').expect(201);
    await superAdmin
      .upload(`${ADMIN}/${banner.id}/image?variant=desktop`, PNG, 'd.png')
      .expect(201);
    const stored = await context.connection
      .collection('banners')
      .findOne({ _id: new Types.ObjectId(banner.id) });
    const keys = [stored?.imageKey, stored?.desktopImageKey] as string[];
    expect(keys.every((key) => typeof key === 'string')).toBe(true);
    await superAdmin.delete(`${ADMIN}/${banner.id}`).expect(200);
    const storage = context.app.get<FileStorage>(FILE_STORAGE);
    for (const key of keys) await expect(storage.open(key)).resolves.toBeDefined();
    await superAdmin.post(`${ADMIN}/${banner.id}/restore`).expect(201);
    const restored = dataOf<BannerBody>(await superAdmin.get(`${ADMIN}/${banner.id}`).expect(200));
    expect(restored.imageUrl).toMatch(/^banners\//);
    expect(restored.desktopImageUrl).toMatch(/variant=desktop/);
  });

  it('prefers an external image address until an image is uploaded', async () => {
    const banner = await create({
      title: 'Imported',
      externalImageUrl: 'https://cdn.example.test/banner.jpg',
    });
    expect(banner.imageUrl).toBe('https://cdn.example.test/banner.jpg');
    const uploaded = dataOf<BannerBody>(
      await superAdmin.upload(`${ADMIN}/${banner.id}/image`, PNG, 'banner.png').expect(201),
    );
    expect(uploaded.externalImageUrl).toBeNull();
    expect(uploaded.imageUrl).toMatch(/^banners\//);
  });

  it('refuses text files and files over 3 MB', async () => {
    const banner = await create({ title: 'Refuses files' });
    await expectCode(
      superAdmin.upload(`${ADMIN}/${banner.id}/image`, Buffer.from('hello world'), 'a.png'),
      415,
      'UNSUPPORTED_MEDIA_TYPE',
    );
    const tooLarge = Buffer.concat([PNG, Buffer.alloc(3 * 1024 * 1024)]);
    await expectCode(
      superAdmin.upload(`${ADMIN}/${banner.id}/image`, tooLarge, 'big.png'),
      413,
      'PAYLOAD_TOO_LARGE',
    );
  });

  it('has no image to serve for a banner without one, or a missing banner', async () => {
    const banner = await create({ title: 'No image' });
    await expectCode(
      client(context).get(`${PUBLIC}/${banner.id}/image`),
      404,
      'RESOURCE_NOT_FOUND',
    );
    await expectCode(
      client(context).get(`${PUBLIC}/64b000000000000000000fff/image`),
      404,
      'RESOURCE_NOT_FOUND',
    );
  });
});
