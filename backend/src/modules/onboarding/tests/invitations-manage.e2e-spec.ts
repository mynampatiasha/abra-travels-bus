import { Types } from 'mongoose';
import request from 'supertest';
import { bearer, dataOf, uniqueEmail } from '../../authentication/tests/auth-e2e.harness';
import { type InvitationView } from '../services/invitations.service';
import { API, createOnboardingWorld, type OnboardingWorld } from './onboarding-e2e.support';

/** Phase 1 step 2: open one invitation, edit it, EXPIRED filter, search, delete and Undo. */
describe('Onboarding e2e: invitations page (open, edit, expired, delete)', () => {
  let world: OnboardingWorld;
  let { call, invite, tokenOf, superAdmin, support, context } = {} as OnboardingWorld;

  const patch = (id: string, body: object, who = superAdmin) =>
    request(context.server)
      .patch(`${API}/onboarding/invitations/${id}`)
      .set('X-Forwarded-For', '198.51.100.7')
      .set(...bearer(who.tokens))
      .send(body);
  const list = async (query: string) =>
    dataOf<InvitationView[]>(
      await call(superAdmin, 'get', `/onboarding/invitations?${query}`).expect(200),
    );
  const view = async (id: string) =>
    dataOf<InvitationView>(
      await call(superAdmin, 'get', `/onboarding/invitations/${id}`).expect(200),
    );

  beforeAll(async () => {
    world = await createOnboardingWorld();
    ({ call, invite, tokenOf, superAdmin, support, context } = world);
  }, 180_000);

  afterAll(() => world.close(), 60_000);

  it('opens one invitation, and refuses people without the permission and unknown ids', async () => {
    const invitation = await invite(uniqueEmail(), 'Open Lines');
    expect(await view(invitation.id)).toMatchObject({
      companyName: 'Open Lines',
      status: 'PENDING',
    });
    await call(support, 'get', `/onboarding/invitations/${invitation.id}`).expect(403);
    await call(undefined, 'get', `/onboarding/invitations/${invitation.id}`).expect(401);
    await call(
      superAdmin,
      'get',
      `/onboarding/invitations/${new Types.ObjectId().toHexString()}`,
    ).expect(404);
  });

  it('edits company, owner and phone; the company awaiting approval follows; audited', async () => {
    const invitation = await invite(uniqueEmail(), 'Before Lines');
    const edited = dataOf<InvitationView>(
      await patch(invitation.id, {
        companyName: 'After Lines',
        ownerName: 'New Owner',
        phone: '9876543210',
      }).expect(200),
    );
    expect(edited).toMatchObject({
      companyName: 'After Lines',
      ownerName: 'New Owner',
      phone: '+919876543210',
    });
    const operator = await context.connection
      .collection('operators')
      .findOne({ _id: new Types.ObjectId(invitation.operatorId) });
    expect(operator?.companyName).toBe('After Lines');

    const cleared = dataOf<InvitationView>(await patch(invitation.id, { phone: null }).expect(200));
    expect(cleared.phone).toBeNull();

    const audit = dataOf<{ action: string; before: object; after: object }[]>(
      await call(superAdmin, 'get', `/audit-logs?entityId=${invitation.id}&pageSize=50`).expect(
        200,
      ),
    );
    const entries = audit.filter((entry) => entry.action === 'onboarding.invitation-updated');
    expect(entries.length).toBe(2);
    expect(JSON.stringify(entries)).not.toMatch(/tokenHash/);
  });

  it('a new email kills the old link; the invitation must be sent again', async () => {
    const invitation = await invite(uniqueEmail(), 'Moved Lines');
    const oldToken = tokenOf(invitation);
    const newEmail = uniqueEmail();
    const edited = dataOf<InvitationView>(
      await patch(invitation.id, { email: newEmail }).expect(200),
    );
    expect(edited).toMatchObject({ email: newEmail, emailStatus: 'NOT_SENT' });
    await call(undefined, 'post', '/onboarding/invitations/inspect', { token: oldToken }).expect(
      404,
    );

    const resent = dataOf<InvitationView>(
      await call(superAdmin, 'post', `/onboarding/invitations/${invitation.id}/resend`).expect(200),
    );
    const preview = await call(undefined, 'post', '/onboarding/invitations/inspect', {
      token: tokenOf(resent),
    }).expect(200);
    expect(JSON.stringify(preview.body)).toContain(newEmail);
  });

  it('refuses an email that is invited already or has an account, and bad dates', async () => {
    const first = await invite(uniqueEmail(), 'First Lines');
    const second = await invite(uniqueEmail(), 'Second Lines');
    await patch(second.id, { email: first.email }).expect(409);
    await patch(second.id, { email: support.email }).expect(409);

    const tooFar = new Date(Date.now() + 40 * 24 * 3600 * 1000).toISOString();
    await patch(second.id, { expiresAt: tooFar }).expect(400);
    await patch(second.id, { expiresAt: new Date(Date.now() - 1000).toISOString() }).expect(400);
    await patch(second.id, {}).expect(200); // nothing to change is not an error
  });

  it('EXPIRED and PENDING filters, search, and reopening an expired invitation', async () => {
    const invitation = await invite(uniqueEmail(), 'Lapsed Findable Lines');
    await context.connection
      .collection('onboarding_invitations')
      .updateOne(
        { _id: new Types.ObjectId(invitation.id) },
        { $set: { expiresAt: new Date(Date.now() - 60_000) } },
      );
    const expired = await list('status=EXPIRED&pageSize=100');
    expect(expired.map((entry) => entry.id)).toContain(invitation.id);
    const pending = await list('status=PENDING&pageSize=100');
    expect(pending.map((entry) => entry.id)).not.toContain(invitation.id);

    const found = await list('search=lapsed%20findable');
    expect(found.map((entry) => entry.id)).toEqual([invitation.id]);

    const reopened = dataOf<InvitationView>(
      await patch(invitation.id, {
        expiresAt: new Date(Date.now() + 5 * 24 * 3600 * 1000).toISOString(),
      }).expect(200),
    );
    expect(reopened.expired).toBe(false);
    const pendingNow = await list('status=PENDING&pageSize=100');
    expect(pendingNow.map((entry) => entry.id)).toContain(invitation.id);
  });

  it('only a pending invitation can be edited', async () => {
    const invitation = await invite(uniqueEmail(), 'Revoked Lines');
    await call(superAdmin, 'post', `/onboarding/invitations/${invitation.id}/revoke`).expect(200);
    await patch(invitation.id, { ownerName: 'Late Edit' }).expect(409);
  });

  it('delete: a pending invitation is refused; a revoked one is deleted, hidden, and restorable', async () => {
    const invitation = await invite(uniqueEmail(), 'Delete Lines');
    const refused = await call(superAdmin, 'delete', `/onboarding/invitations/${invitation.id}`);
    expect(refused.status).toBe(409);
    expect(JSON.stringify(refused.body)).toMatch(/Revoke it first/);

    await call(superAdmin, 'post', `/onboarding/invitations/${invitation.id}/revoke`).expect(200);
    await call(superAdmin, 'delete', `/onboarding/invitations/${invitation.id}`).expect(200);
    await call(superAdmin, 'get', `/onboarding/invitations/${invitation.id}`).expect(404);
    expect((await list('pageSize=100')).map((entry) => entry.id)).not.toContain(invitation.id);

    await call(superAdmin, 'post', `/onboarding/invitations/${invitation.id}/restore`).expect(201);
    expect((await view(invitation.id)).status).toBe('REVOKED');
  });
});
