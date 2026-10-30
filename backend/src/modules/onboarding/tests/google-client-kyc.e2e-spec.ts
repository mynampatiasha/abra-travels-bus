/* eslint-disable max-lines -- One integration journey covers all client login methods and the same KYC. */
import { jest } from '@jest/globals';
import { Types } from 'mongoose';
import { type SpiedFunction } from 'jest-mock';
import { sha256Hex } from '../../../common/crypto/secure-hash';
import { ApiException } from '../../../common/errors/api-exception';
import { RateLimiterService } from '../../../common/rate-limit/rate-limiter.service';
import { FirebaseGoogleVerifier } from '../../authentication/google_sign_in';
import {
  dataOf,
  lastOtp,
  uniquePhone,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { OnboardingNotificationHandler } from '../../notifications/notifications';
import {
  createOnboardingWorld,
  type OnboardingWorld,
  PDF,
  OWNER_PASSWORD,
} from './onboarding-e2e.support';

describe('Google client KYC journey', () => {
  let world: OnboardingWorld;
  let owner: { tokens: Tokens };
  let id: string;
  let operatorId: string;
  let verifier: SpiedFunction<FirebaseGoogleVerifier['verify']>;
  const email = `google-client-${Date.now()}@example.com`;
  const login = (audience = 'CLIENT', extra = {}) =>
    world.call(undefined, 'post', '/auth/google', {
      idToken: 'firebase-token-from-client-12345',
      audience,
      acceptTerms: true,
      device: { clientType: 'MOBILE' },
      ...extra,
    });
  beforeAll(async () => {
    world = await createOnboardingWorld();
    verifier = jest.spyOn(world.context.app.get(FirebaseGoogleVerifier), 'verify');
    verifier.mockResolvedValue({ uid: `google-${Date.now()}`, email, name: 'New Bus Owner' });
  }, 180_000);
  afterAll(async () => {
    verifier.mockRestore();
    await world.close();
  }, 60_000);

  it('creates a pending client in the existing users/session collections and blocks account features', async () => {
    owner = { tokens: dataOf<Tokens>(await login().expect(200)) };
    const user = await world.context.users.findById(owner.tokens.user.id).lean();
    expect(user?.userType).toBe('OPERATOR_STAFF');
    expect(user?.firebaseUid).toBeTruthy();
    operatorId = user!.operatorId!.toHexString();
    id = await world.companySubmissionId(operatorId);
    await world.call(owner, 'get', '/catalogue/buses').expect(403);
    // Calling the legacy submit endpoint cannot bypass the questions.
    await world.call(owner, 'post', `/onboarding/submissions/${id}/submit`).expect(400);
  });

  it('rejects invalid tokens and cross-app account use without a second user', async () => {
    verifier.mockRejectedValueOnce(
      new ApiException('INVALID_CREDENTIALS', 'Invalid Firebase token'),
    );
    await login().expect(401);
    await login('CUSTOMER').expect(403);
    expect(await world.context.users.countDocuments({ email })).toBe(1);
  });

  it('asks admin-configured questions and validates their answers before exposing conditional documents', async () => {
    const catalogue = dataOf<{ documents: Array<{ name: string; key: string }> }>(
      await world.call(world.superAdmin, 'get', '/settings/kyc-configuration').expect(200),
    );
    const keyOf = (name: string) => catalogue.documents.find((d) => d.name === name)!.key;
    await world
      .call(world.superAdmin, 'put', '/settings/kyc-configuration', {
        schemaVersion: 1,
        expectedVersion: 0,
        reason: 'Configure client onboarding',
        questions: [
          {
            key: 'gst_registered',
            label: 'Are you GST registered?',
            help: '',
            appliesTo: 'OPERATOR',
            type: 'BOOLEAN',
            options: [],
            required: true,
            active: true,
            sortOrder: 1,
          },
        ],
        rules: [
          {
            key: 'company_registration',
            name: 'Company registration',
            appliesTo: 'OPERATOR',
            documentKey: keyOf('REGISTRATION'),
            required: true,
            active: true,
            match: 'ALL',
            conditions: [],
          },
          {
            key: 'gst_certificate',
            name: 'GST certificate',
            appliesTo: 'OPERATOR',
            documentKey: keyOf('GST'),
            required: true,
            active: true,
            match: 'ALL',
            conditions: [{ questionKey: 'gst_registered', values: ['true'] }],
          },
          {
            key: 'optional_pan',
            name: 'Optional PAN',
            appliesTo: 'OPERATOR',
            documentKey: keyOf('PAN'),
            required: false,
            active: true,
            match: 'ALL',
            conditions: [],
          },
        ],
      })
      .expect(200);
    const initial = dataOf<{ kyc: { configuration: { questions: unknown[] } } }>(
      await world.call(owner, 'get', '/client/kyc').expect(200),
    );
    expect(initial.kyc.configuration.questions).toHaveLength(1);
    await world
      .call(owner, 'put', '/client/kyc', {
        companyName: 'Google Lines',
        introductionAccepted: true,
        answers: {},
      })
      .expect(400);
    await world
      .call(owner, 'put', '/client/kyc', {
        companyName: 'Google Lines',
        introductionAccepted: true,
        answers: { gst_registered: 'false' },
      })
      .expect(200);
    const view = await world.detail(owner, id);
    expect(view.checklist.map((d) => [d.name, d.isRequired])).toEqual([
      ['REGISTRATION', true],
      ['PAN', false],
    ]);
    expect(view.kyc?.answers).toEqual({ gst_registered: 'false' });
    expect(view.canSubmit).toBe(false);
    const file = await world.uploadFile(owner, world.regType.id, PDF);
    await world.setDocument(owner, id, world.regType.id, { fileIds: [file] }).expect(200);
    expect((await world.detail(owner, id)).canSubmit).toBe(true);
  });

  it('submits into admin review and creates a reviewer notification with the correct destination', async () => {
    await world.call(owner, 'post', `/onboarding/submissions/${id}/submit`).expect(200);
    await world
      .call(owner, 'put', '/client/kyc', {
        companyName: 'Changed company',
        introductionAccepted: true,
        answers: { gst_registered: 'true' },
      })
      .expect(409);
    const pending = dataOf<Array<{ id: string }>>(
      await world
        .call(world.superAdmin, 'get', '/onboarding/submissions?status=PENDING')
        .expect(200),
    );
    expect(pending.some((item) => item.id === id)).toBe(true);
    await world.context.app.get(OnboardingNotificationHandler).handle({
      eventId: `test-submitted-${id}`,
      type: 'onboarding.submitted',
      occurredAt: new Date().toISOString(),
      aggregateType: 'onboarding_submission',
      aggregateId: id,
      payload: {
        submissionId: id,
        operatorId,
        subjectType: 'OPERATOR',
        companyName: 'Google Lines',
      },
    });
    const notices = dataOf<Array<{ data: { route: string } }>>(
      await world.call(world.superAdmin, 'get', '/notifications').expect(200),
    );
    expect(notices.some((n) => n.data.route === `/onboarding/${id}`)).toBe(true);
  });

  it('admin approval unlocks the same client session and notifies that company owner', async () => {
    await world.review(id, world.regType.id, 'APPROVED').expect(200);
    await world.call(world.superAdmin, 'post', `/onboarding/submissions/${id}/approve`).expect(200);
    const view = dataOf<{ approved: boolean }>(
      await world.call(owner, 'get', '/client/kyc').expect(200),
    );
    expect(view.approved).toBe(true);
    await world.call(owner, 'get', '/catalogue/buses').expect(200);
    await world.context.app.get(OnboardingNotificationHandler).handle({
      eventId: `test-approved-${id}`,
      type: 'onboarding.approved',
      occurredAt: new Date().toISOString(),
      aggregateType: 'onboarding_submission',
      aggregateId: id,
      payload: {
        submissionId: id,
        operatorId,
        subjectType: 'OPERATOR',
        companyName: 'Google Lines',
      },
    });
    const notices = dataOf<Array<{ type: string; data: { route: string } }>>(
      await world.call(owner, 'get', '/notifications').expect(200),
    );
    expect(
      notices.some((n) => n.type === 'onboarding.approved' && n.data.route === `/onboarding/${id}`),
    ).toBe(true);
  });

  it('creates an ordinary customer without an operator or KYC requirement', async () => {
    verifier.mockResolvedValueOnce({
      uid: `customer-${Date.now()}`,
      email: `customer-${Date.now()}@example.com`,
    });
    const tokens = dataOf<Tokens>(await login('CUSTOMER').expect(200));
    expect(tokens.user.userType).toBe('CUSTOMER');
    expect((await world.context.users.findById(tokens.user.id).lean())?.operatorId).toBeUndefined();
  });
  it('requires the local password before linking an existing account and preserves its identity', async () => {
    const local = await world.onboardOwner('Local Account Lines');
    const uid = `linked-${Date.now()}`;
    verifier.mockResolvedValue({ uid, email: local.email, name: 'Google identity' });
    await login().expect(401);
    const before = await world.context.users.findOne({ email: local.email }).lean();
    expect(before?.firebaseUid).toBeUndefined();
    await login('CLIENT', { linkPassword: 'incorrect-password' }).expect(401);
    const linked = dataOf<Tokens>(
      await login('CLIENT', { linkPassword: OWNER_PASSWORD }).expect(200),
    );
    expect(linked.user.id).toBe(before?._id.toHexString());
    expect(await world.context.users.countDocuments({ email: local.email })).toBe(1);
    const repeated = dataOf<Tokens>(await login().expect(200));
    expect(repeated.user.id).toBe(linked.user.id);
    expect(
      (await world.context.users.findById(linked.user.id).lean())?.operatorId?.toHexString(),
    ).toBe(local.operatorId);
  });
  it('denies disabled accounts and rejects caller-supplied roles/profile data', async () => {
    const user = await world.context.users.findOne({ firebaseUid: /^linked-/ }).lean();
    await world.context.users.updateOne({ _id: user!._id }, { $set: { status: 'SUSPENDED' } });
    await login().expect(403);
    await login('CLIENT', { role: 'SUPER_ADMIN', email: 'untrusted@example.com' }).expect(400);
  });
  it('accepts optional-only KYC without forcing a document and still requires admin approval', async () => {
    const catalogue = dataOf<{ version: number; documents: Array<{ name: string; key: string }> }>(
      await world.call(world.superAdmin, 'get', '/settings/kyc-configuration').expect(200),
    );
    await world
      .call(world.superAdmin, 'put', '/settings/kyc-configuration', {
        schemaVersion: 1,
        expectedVersion: catalogue.version,
        reason: 'Optional company documents',
        questions: [],
        rules: [
          {
            key: 'optional_pan',
            name: 'Optional PAN',
            appliesTo: 'OPERATOR',
            documentKey: catalogue.documents.find((d) => d.name === 'PAN')!.key,
            required: false,
            active: true,
            match: 'ALL',
            conditions: [],
          },
        ],
      })
      .expect(200);
    verifier.mockResolvedValueOnce({
      uid: `optional-${Date.now()}`,
      email: `optional-${Date.now()}@example.com`,
    });
    const client = { tokens: dataOf<Tokens>(await login().expect(200)) };
    const view = dataOf<{ submissionId: string }>(
      await world.call(client, 'get', '/client/kyc').expect(200),
    );
    await world
      .call(client, 'put', '/client/kyc', {
        companyName: 'Optional Lines',
        introductionAccepted: true,
        answers: {},
      })
      .expect(200);
    await world
      .call(client, 'post', `/onboarding/submissions/${view.submissionId}/submit`)
      .expect(200);
    await world.call(client, 'get', '/catalogue/buses').expect(403);
    await world
      .call(world.superAdmin, 'post', `/onboarding/submissions/${view.submissionId}/approve`)
      .expect(200);
    await world.call(client, 'get', '/catalogue/buses').expect(200);
  });
  it('a draft started before the admin added rules picks up the rules; a submitted one keeps its snapshot', async () => {
    const before = dataOf<{ version: number; documents: Array<{ name: string; key: string }> }>(
      await world.call(world.superAdmin, 'get', '/settings/kyc-configuration').expect(200),
    );
    await world
      .call(world.superAdmin, 'put', '/settings/kyc-configuration', {
        schemaVersion: 1,
        expectedVersion: before.version,
        reason: 'Start with no document rules',
        questions: [],
        rules: [],
      })
      .expect(200);
    verifier.mockResolvedValueOnce({
      uid: `early-${Date.now()}`,
      email: `early-${Date.now()}@example.com`,
    });
    const early = { tokens: dataOf<Tokens>(await login().expect(200)) };
    const first = dataOf<{ submissionId: string; kyc: { requirements: unknown[] } }>(
      await world.call(early, 'get', '/client/kyc').expect(200),
    );
    expect(first.kyc.requirements).toHaveLength(0);

    const empty = dataOf<{ version: number }>(
      await world.call(world.superAdmin, 'get', '/settings/kyc-configuration').expect(200),
    );
    const panKey = before.documents.find((d) => d.name === 'PAN')!.key;
    await world
      .call(world.superAdmin, 'put', '/settings/kyc-configuration', {
        schemaVersion: 1,
        expectedVersion: empty.version,
        reason: 'Ask for PAN (optional, so the test can submit without a file)',
        questions: [],
        rules: [
          {
            key: 'pan_asked',
            name: 'PAN asked',
            appliesTo: 'OPERATOR',
            documentKey: panKey,
            required: false,
            active: true,
            match: 'ALL',
            conditions: [],
          },
        ],
      })
      .expect(200);

    // Still a draft: it now follows the new rule and can be saved.
    const refreshed = dataOf<{ kyc: { requirements: Array<{ key: string }> } }>(
      await world.call(early, 'get', '/client/kyc').expect(200),
    );
    expect(refreshed.kyc.requirements.map((d) => d.key)).toEqual([panKey]);
    await world
      .call(early, 'put', '/client/kyc', {
        companyName: 'Early Lines',
        introductionAccepted: true,
        answers: {},
      })
      .expect(200);
    await world
      .call(early, 'post', `/onboarding/submissions/${first.submissionId}/submit`)
      .expect(200);

    // Submitted: a later admin change does not move the goalposts.
    const latest = dataOf<{ version: number }>(
      await world.call(world.superAdmin, 'get', '/settings/kyc-configuration').expect(200),
    );
    await world
      .call(world.superAdmin, 'put', '/settings/kyc-configuration', {
        schemaVersion: 1,
        expectedVersion: latest.version,
        reason: 'Back to no rules',
        questions: [],
        rules: [],
      })
      .expect(200);
    const kept = dataOf<{ kyc: { requirements: Array<{ key: string }> } }>(
      await world.call(early, 'get', '/client/kyc').expect(200),
    );
    expect(kept.kyc.requirements.map((d) => d.key)).toEqual([panKey]);
  });
  it('uses the Apple verifier with audience-specific customer and client roles', async () => {
    verifier.mockResolvedValueOnce({
      uid: `apple-${Date.now()}`,
      email: `apple-${Date.now()}@privaterelay.appleid.com`,
    });
    const response = await world
      .call(undefined, 'post', '/auth/apple', {
        idToken: 'apple-firebase-token-123456',
        audience: 'CUSTOMER',
        acceptTerms: true,
        device: { clientType: 'MOBILE' },
      })
      .expect(200);
    const tokens = dataOf<Tokens>(response);
    expect(tokens.user.userType).toBe('CUSTOMER');
    expect(verifier).toHaveBeenLastCalledWith('apple-firebase-token-123456', 'apple.com');
    expect((await world.context.users.findById(tokens.user.id).lean())?.authProvider).toBe('apple');
    verifier.mockResolvedValueOnce({
      uid: `apple-client-${Date.now()}`,
      email: `apple-client-${Date.now()}@example.com`,
    });
    const clientResponse = await world
      .call(undefined, 'post', '/auth/apple', {
        idToken: 'apple-firebase-token-123456',
        audience: 'CLIENT',
        acceptTerms: true,
        device: { clientType: 'MOBILE' },
      })
      .expect(200);
    const appleClient = { tokens: dataOf<Tokens>(clientResponse) };
    expect(appleClient.tokens.user.userType).toBe('OPERATOR_STAFF');
    await world.call(appleClient, 'get', '/client/kyc').expect(200);
    await world.call(appleClient, 'get', '/catalogue/buses').expect(403);
  });
  it('new WhatsApp clients receive a company KYC and cannot skip approval', async () => {
    const phone = uniquePhone();
    await world.call(undefined, 'post', '/auth/otp/send', { phone }).expect(200);
    await world
      .call(undefined, 'post', '/auth/client/otp/verify', {
        phone,
        code: '000000',
        acceptTerms: true,
        device: { clientType: 'MOBILE' },
      })
      .expect(401);
    const response = await world
      .call(undefined, 'post', '/auth/client/otp/verify', {
        phone,
        code: lastOtp(world.context, phone),
        acceptTerms: true,
        device: { clientType: 'MOBILE' },
      })
      .expect(200);
    const client = { tokens: dataOf<Tokens>(response) };
    expect(client.tokens.user.userType).toBe('OPERATOR_STAFF');
    const user = await world.context.users.findById(client.tokens.user.id).lean();
    expect(user?.phoneVerifiedAt).toBeTruthy();
    expect(user?.firebaseUid).toBeUndefined();
    const view = dataOf<{ status: string }>(
      await world.call(client, 'get', '/client/kyc').expect(200),
    );
    expect(view.status).toBe('DRAFT');
    await world.call(client, 'get', '/catalogue/buses').expect(403);
    await world
      .call(undefined, 'post', '/auth/client/otp/verify', {
        phone,
        code: lastOtp(world.context, phone),
        acceptTerms: true,
        device: { clientType: 'MOBILE' },
      })
      .expect(401);
  });
  it('linked phone and password return the same approved owner and company', async () => {
    const phone = uniquePhone();
    await world.call(owner, 'get', '/client/kyc/login-methods').expect(200);
    await world.call(undefined, 'post', '/auth/otp/send', { phone }).expect(200);
    await world
      .call(owner, 'post', '/client/kyc/login-methods/phone', {
        phone,
        code: lastOtp(world.context, phone),
      })
      .expect(200);
    await world
      .call(owner, 'post', '/me/password', { newPassword: 'Verified-client-password-654' })
      .expect(200);
    const loginResponse = await world
      .call(undefined, 'post', '/auth/login', {
        identifier: phone,
        password: 'Verified-client-password-654',
        device: { clientType: 'MOBILE' },
      })
      .expect(200);
    const again = { tokens: dataOf<Tokens>(loginResponse) };
    expect(again.tokens.user.id).toBe(owner.tokens.user.id);
    const user = await world.context.users.findById(again.tokens.user.id).lean();
    expect(user?.operatorId?.toHexString()).toBe(operatorId);
    await world.call(again, 'get', '/catalogue/buses').expect(200);
    expect(
      dataOf<{ approved: boolean }>(await world.call(again, 'get', '/client/kyc').expect(200))
        .approved,
    ).toBe(true);
  });
  it('refuses linking an identity owned by another account', async () => {
    verifier.mockResolvedValueOnce({ uid: 'different-uid', email: 'other-owner@example.com' });
    const other = { tokens: dataOf<Tokens>(await login().expect(200)) };
    const user = await world.context.users.findById(owner.tokens.user.id).lean();
    verifier.mockResolvedValueOnce({ uid: user!.firebaseUid!, email: user!.email! });
    await world
      .call(other, 'post', '/client/kyc/login-methods/social', {
        idToken: 'another-firebase-token-12345',
        provider: 'google',
      })
      .expect(401);
    await world.call(undefined, 'get', '/client/kyc/login-methods').expect(401);
  });
  it('an approved owner can link Apple and sign in without repeating KYC',async()=>{
    const uid=`linked-apple-${Date.now()}`, email=`linked-apple-${Date.now()}@privaterelay.appleid.com`;
    verifier.mockResolvedValueOnce({uid,email});
    await world.call(owner,'post','/client/kyc/login-methods/social',{idToken:'apple-link-token-123456789',provider:'apple'}).expect(200);
    verifier.mockResolvedValueOnce({uid,email});
    const result=await world.call(undefined,'post','/auth/apple',{idToken:'apple-linked-sign-in-token-1234',audience:'CLIENT',acceptTerms:true,device:{clientType:'MOBILE'}}).expect(200);
    const again={tokens:dataOf<Tokens>(result)};
    expect(again.tokens.user.id).toBe(owner.tokens.user.id);
    await world.call(again,'get','/catalogue/buses').expect(200);
  });

  it('the email of a Google account and its password reach the same owner, with no second KYC', async () => {
    const result = await world
      .call(undefined, 'post', '/auth/login', {
        identifier: email,
        password: 'Verified-client-password-654',
        device: { clientType: 'MOBILE' },
      })
      .expect(200);
    const again = { tokens: dataOf<Tokens>(result) };
    expect(again.tokens.user.id).toBe(owner.tokens.user.id);
    expect(await world.context.users.countDocuments({ email })).toBe(1);
    expect(await world.context.connection.collection('onboarding_submissions').countDocuments({ operatorId: new Types.ObjectId(operatorId) })).toBe(1);
    await world.call(again, 'get', '/catalogue/buses').expect(200);
  });

  it('changing the linked phone moves phone sign-in to the new number, on the same account', async () => {
    const before = await world.context.users.findById(owner.tokens.user.id).lean();
    const oldPhone = before!.phone!;
    const newPhone = uniquePhone();
    // One number can be sent a code once every 30 seconds; a test does not wait, so it lifts the pause
    const limiter = world.context.app.get(RateLimiterService);
    const sendCode = async (phone: string) => {
      await limiter.clear(limiter.key('otp', 'cooldown', 'SIGN_IN', sha256Hex(phone).slice(0, 32)));
      return world.call(undefined, 'post', '/auth/otp/send', { phone }).expect(200);
    };
    const phoneSignIn = (phone: string) =>
      world.call(undefined, 'post', '/auth/client/otp/verify', {
        phone,
        code: lastOtp(world.context, phone),
        acceptTerms: true,
        device: { clientType: 'MOBILE' },
      });

    await sendCode(newPhone);
    await world
      .call(owner, 'post', '/client/kyc/login-methods/phone', { phone: newPhone, code: lastOtp(world.context, newPhone) })
      .expect(200);
    const methods = dataOf<{ phone: string }>(await world.call(owner, 'get', '/client/kyc/login-methods').expect(200));
    expect(methods.phone).toBe(newPhone);

    // The new number signs in to the same owner and company, with no second KYC
    await sendCode(newPhone);
    const viaNew = { tokens: dataOf<Tokens>(await phoneSignIn(newPhone).expect(200)) };
    expect(viaNew.tokens.user.id).toBe(owner.tokens.user.id);
    await world.call(viaNew, 'get', '/catalogue/buses').expect(200);
    expect(await world.context.connection.collection('onboarding_submissions').countDocuments({ operatorId: new Types.ObjectId(operatorId) })).toBe(1);

    // The password still works with the new number
    const viaPassword = await world
      .call(undefined, 'post', '/auth/login', {
        identifier: newPhone,
        password: 'Verified-client-password-654',
        device: { clientType: 'MOBILE' },
      })
      .expect(200);
    expect(dataOf<Tokens>(viaPassword).user.id).toBe(owner.tokens.user.id);

    // The old number no longer belongs to this account: signing in with it starts a new, unapproved one
    await sendCode(oldPhone);
    const viaOld = { tokens: dataOf<Tokens>(await phoneSignIn(oldPhone).expect(200)) };
    expect(viaOld.tokens.user.id).not.toBe(owner.tokens.user.id);
    await world.call(viaOld, 'get', '/catalogue/buses').expect(403);
  });

  it('a phone number that belongs to another account cannot be linked', async () => {
    const taken = (await world.context.users.findOne({ phone: { $exists: true }, _id: { $ne: owner.tokens.user.id } }).lean())!
      .phone!;
    await world.call(undefined, 'post', '/auth/otp/send', { phone: taken }).expect(200);
    const refused = await world.call(owner, 'post', '/client/kyc/login-methods/phone', {
      phone: taken,
      code: lastOtp(world.context, taken),
    });
    expect(refused.status).toBe(409);
  });
});
