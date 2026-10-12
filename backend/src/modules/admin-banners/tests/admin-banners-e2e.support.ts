import {
  type AuthTestContext,
  bearer,
  client,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';

/** Shared by the banner e2e suites. */
export const ADMIN = '/api/v1/admin/banners';
export const PUBLIC = '/api/v1/banners';

export interface BannerBody {
  id: string;
  title: string;
  linkType: string;
  linkValue: string;
  status: string;
  isActive: boolean;
  imageUrl: string | null;
  externalImageUrl: string | null;
  desktopImageUrl: string | null;
  externalDesktopImageUrl: string | null;
  startsAt: string | null;
  endsAt: string | null;
}

export interface PublicBannerBody {
  id: string;
  title: string;
  imageUrl: string | null;
  desktopImageUrl: string | null;
}

export const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.alloc(64, 7),
]);
export const WEBP = Buffer.concat([
  Buffer.from('RIFF'),
  Buffer.from([0x24, 0, 0, 0]),
  Buffer.from('WEBPVP8 '),
  Buffer.alloc(32, 1),
]);
const DAY_MS = 24 * 60 * 60 * 1000;
export const inDays = (days: number) => new Date(Date.now() + days * DAY_MS).toISOString();
export const CITY_A = '64b0000000000000000000a1';
export const CITY_B = '64b0000000000000000000b2';

/** Calls the API as one signed-in user. */
export function api(context: AuthTestContext, tokens: Tokens) {
  const caller = client(context);
  return {
    get: (path: string) => caller.get(path).set(...bearer(tokens)),
    post: (path: string, body: object = {}) =>
      caller
        .post(path)
        .set(...bearer(tokens))
        .send(body),
    put: (path: string, body: object) =>
      caller
        .put(path)
        .set(...bearer(tokens))
        .send(body),
    delete: (path: string) => caller.delete(path).set(...bearer(tokens)),
    upload: (path: string, content: Buffer, filename: string) =>
      caller
        .post(path)
        .set(...bearer(tokens))
        .attach('file', content, { filename }),
  };
}
export type Api = ReturnType<typeof api>;

/** POSTs a banner and returns it; fails the test when it is not accepted. */
export async function createBanner(admin: Api, body: object): Promise<BannerBody> {
  const response = await admin.post(ADMIN, body);
  if (response.status !== 201) {
    throw new Error(`create answered ${response.status}: ${JSON.stringify(response.body)}`);
  }
  return dataOf<BannerBody>(response);
}
