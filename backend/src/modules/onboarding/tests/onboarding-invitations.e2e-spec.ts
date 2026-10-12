import { type AddressInfo } from 'node:net';
import { Types } from 'mongoose';
import { EmailSettingsStore } from '../../../integrations/email/email-settings.store';
import { dataOf, type Tokens, uniqueEmail } from '../../authentication/tests/auth-e2e.harness';
import { type InvitationView } from '../services/invitations.service';
import {
  OWNER_PASSWORD,
  createOnboardingWorld,
  type OnboardingWorld,
} from './onboarding-e2e.support';

/** Inviting a bus owner: real application, MongoDB, Redis, a real SMTP server and storage folder. */
describe('Onboarding e2e: invitations', () => {
  let world: OnboardingWorld;
  let context: OnboardingWorld['context'];
  let smtp: OnboardingWorld['smtp'];
  let mails: OnboardingWorld['mails'];
  let superAdmin: OnboardingWorld['superAdmin'];
  let support: OnboardingWorld['support'];
  let call: OnboardingWorld['call'];
  let detail: OnboardingWorld['detail'];
  let tokenInMail: OnboardingWorld['tokenInMail'];
  let invite: OnboardingWorld['invite'];
  let tokenOf: OnboardingWorld['tokenOf'];
  let companySubmissionId: OnboardingWorld['companySubmissionId'];

  beforeAll(async () => {
    world = await createOnboardingWorld();
    ({
      context,
      smtp,
      mails,
      superAdmin,
      support,
      call,
      detail,
      tokenInMail,
      invite,
      tokenOf,
      companySubmissionId,
    } = world);
  }, 180_000);

  afterAll(() => world.close(), 60_000);

  describe('inviting a bus owner', () => {
    let ownerEmail: string;
    let invitation: InvitationView;

    it('is closed without a token and to people without the permission', async () => {
      const body = { companyName: 'X Travels', ownerName: 'Xavier', email: uniqueEmail() };
      await call(undefined, 'post', '/onboarding/invitations', body).expect(401);
      await call(undefined, 'get', '/onboarding/invitations').expect(401);
      await call(support, 'post', '/onboarding/invitations', body).expect(403);
      await call(support, 'get', '/onboarding/invitations').expect(403);
    });

    it('creates the company awaiting approval and emails the link', async () => {
      ownerEmail = uniqueEmail();
      mails.length = 0;
      invitation = await invite(ownerEmail, 'Alpha Lines');

      expect(invitation).toMatchObject({
        companyName: 'Alpha Lines',
        email: ownerEmail,
        status: 'PENDING',
        emailStatus: 'SENT',
        emailProblem: null,
        expired: false,
      });
      expect(invitation.inviteUrl).toContain('/accept-invite?token=');

      // the same link is in the email that went to the owner
      expect(mails).toHaveLength(1);
      expect(mails[0]?.to).toEqual([ownerEmail]);
      expect(tokenInMail(mails[0]?.data ?? '')).toBe(tokenOf(invitation));

      // the company exists, awaiting approval, with an empty onboarding file
      const operator = await call(
        superAdmin,
        'get',
        `/catalogue/operators/${invitation.operatorId}`,
      ).expect(200);
      expect(dataOf<{ status: string }>(operator).status).toBe('PENDING_APPROVAL');
      const submissionId = await companySubmissionId(invitation.operatorId);
      expect((await detail(superAdmin, submissionId)).status).toBe('DRAFT');

      // only a hash of the token is stored
      const stored = await context.connection
        .collection('onboarding_invitations')
        .findOne({ email: ownerEmail });
      expect(stored?.tokenHash).toMatch(/^[0-9a-f]{64}$/);
      expect(JSON.stringify(stored)).not.toContain(tokenOf(invitation));
    });

    it('does not invite the same address twice, nor an address that has an account', async () => {
      await call(superAdmin, 'post', '/onboarding/invitations', {
        companyName: 'Again',
        ownerName: 'Again',
        email: ownerEmail,
      }).expect(409);
      await call(superAdmin, 'post', '/onboarding/invitations', {
        companyName: 'Has account',
        ownerName: 'Has account',
        email: support.email,
      }).expect(409);
    });

    it('a failed email does not lose the invitation, and says why', async () => {
      await call(superAdmin, 'put', '/settings/integrations/email', {
        port: 1,
        reason: 'Break the mail server',
      }).expect(200);
      const broken = await invite(uniqueEmail(), 'No Mail Travels');
      expect(broken).toMatchObject({ status: 'PENDING', emailStatus: 'FAILED' });
      expect(broken.emailProblem).toBeTruthy();
      expect(broken.inviteUrl).toBeTruthy();
      await call(superAdmin, 'put', '/settings/integrations/email', {
        port: (smtp.server.address() as AddressInfo).port,
        reason: 'Fix the mail server',
      }).expect(200);
      context.app.get(EmailSettingsStore).invalidate();
      const resent = dataOf<InvitationView>(
        await call(superAdmin, 'post', `/onboarding/invitations/${broken.id}/resend`).expect(200),
      );
      expect(resent.emailStatus).toBe('SENT');
    });

    it('shows who the link is for, and says nothing about a bad link', async () => {
      const preview = await call(undefined, 'post', '/onboarding/invitations/inspect', {
        token: tokenOf(invitation),
      }).expect(200);
      expect(dataOf(preview)).toEqual({
        companyName: 'Alpha Lines',
        ownerName: 'Owner of Alpha Lines',
        email: ownerEmail,
      });
      await call(undefined, 'post', '/onboarding/invitations/inspect', {
        token: 'x'.repeat(43),
      }).expect(404);
    });

    it('a new link replaces the old one; a withdrawn one stops working', async () => {
      const other = await invite(uniqueEmail(), 'Resend Travels');
      const oldToken = tokenOf(other);
      const resent = dataOf<InvitationView>(
        await call(superAdmin, 'post', `/onboarding/invitations/${other.id}/resend`).expect(200),
      );
      const newToken = tokenOf(resent);
      expect(newToken).not.toBe(oldToken);
      await call(undefined, 'post', '/onboarding/invitations/inspect', { token: oldToken }).expect(
        404,
      );
      await call(undefined, 'post', '/onboarding/invitations/inspect', { token: newToken }).expect(
        200,
      );

      await call(superAdmin, 'post', `/onboarding/invitations/${other.id}/revoke`).expect(200);
      await call(undefined, 'post', '/onboarding/invitations/inspect', { token: newToken }).expect(
        404,
      );
      await call(superAdmin, 'post', `/onboarding/invitations/${other.id}/resend`).expect(409);
      await call(superAdmin, 'post', `/onboarding/invitations/${other.id}/revoke`).expect(409);
    });

    it('an expired link cannot be used', async () => {
      const old = await invite(uniqueEmail(), 'Late Travels');
      await context.connection
        .collection('onboarding_invitations')
        .updateOne(
          { _id: new Types.ObjectId(old.id) },
          { $set: { expiresAt: new Date(Date.now() - 1000) } },
        );
      await call(undefined, 'post', '/onboarding/invitations/inspect', {
        token: tokenOf(old),
      }).expect(404);
      await call(undefined, 'post', '/onboarding/invitations/accept', {
        token: tokenOf(old),
        password: OWNER_PASSWORD,
      }).expect(404);
    });

    it('the owner sets a password once; that creates an account for that company only', async () => {
      const token = tokenOf(invitation);
      await call(undefined, 'post', '/onboarding/invitations/accept', {
        token,
        password: 'short',
      }).expect(400);
      await call(undefined, 'post', '/onboarding/invitations/accept', {
        token,
        password: OWNER_PASSWORD,
      }).expect(200);
      // the link works once
      await call(undefined, 'post', '/onboarding/invitations/accept', {
        token,
        password: OWNER_PASSWORD,
      }).expect(404);

      const login = await call(undefined, 'post', '/auth/login', {
        identifier: ownerEmail,
        password: OWNER_PASSWORD,
      }).expect(200);
      const me = dataOf<{
        userType: string;
        operatorId: string;
        permissions: string[];
        dataScope: { type: string };
      }>(await call({ tokens: dataOf<Tokens>(login) }, 'get', '/me/permissions').expect(200));
      expect(me).toMatchObject({
        userType: 'OPERATOR_STAFF',
        operatorId: invitation.operatorId,
        dataScope: { type: 'OWN_OPERATOR' },
      });
      expect(me.permissions).toEqual(
        expect.arrayContaining(['documents.upload', 'documents.view', 'buses.create']),
      );
      expect(me.permissions).not.toContain('documents.review');
      expect(me.permissions).not.toContain('operators.create');

      const listed = await call(
        superAdmin,
        'get',
        '/onboarding/invitations?status=ACCEPTED',
      ).expect(200);
      expect(
        (listed.body as { data: InvitationView[] }).data.some((item) => item.id === invitation.id),
      ).toBe(true);
    });

    it('can be limited to the days people were invited', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const rows = async (query: string) =>
        (
          (await call(superAdmin, 'get', `/onboarding/invitations?${query}`).expect(200)).body as {
            data: unknown[];
          }
        ).data;
      expect((await rows(`from=${today}&to=${today}&pageSize=100`)).length).toBeGreaterThan(0);
      expect(await rows('from=2099-01-01')).toEqual([]);
      expect(await rows('to=2000-01-01')).toEqual([]);
      await call(superAdmin, 'get', '/onboarding/invitations?from=31-12-2026').expect(400);
    });
  });
});
