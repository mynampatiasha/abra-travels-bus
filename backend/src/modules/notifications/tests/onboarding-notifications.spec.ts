import { type DomainEventMessage } from '../../../events/domain-event.types';
import { onboardingNotice } from '../services/onboarding-notifications';

function event(type: string, payload: Record<string, unknown>): DomainEventMessage {
  return {
    eventId: 'e1',
    type,
    aggregateType: 'onboarding_submission',
    aggregateId: 's1',
    payload: { submissionId: 's1', operatorId: 'o1', subjectType: 'OPERATOR', ...payload },
    occurredAt: '2026-10-07T10:00:00.000Z',
  };
}

describe('onboardingNotice', () => {
  it('tells reviewers that a company sent documents', () => {
    expect(onboardingNotice(event('onboarding.submitted', { companyName: 'Alpha Lines' }))).toEqual(
      {
        audience: 'REVIEWERS',
        type: 'onboarding.submitted',
        title: 'New documents to review',
        body: 'Alpha Lines sent documents for review.',
        data: { submissionId: 's1', subjectType: 'OPERATOR', route: '/onboarding/s1' },
      },
    );
  });

  it('says corrected documents when a file is sent again, and names the bus', () => {
    const notice = onboardingNotice(
      event('onboarding.submitted', {
        companyName: 'Alpha Lines',
        subjectType: 'BUS',
        busId: 'b1',
        busRegistrationNumber: 'KA01AB1234',
        resubmission: true,
      }),
    );
    expect(notice).toMatchObject({
      audience: 'REVIEWERS',
      title: 'Corrected documents to review',
      body: 'Alpha Lines, bus KA01AB1234 sent corrected documents for review.',
      data: { busId: 'b1' },
    });
  });

  it('tells the owner a company or a bus was approved', () => {
    expect(
      onboardingNotice(event('onboarding.approved', { companyName: 'Alpha Lines' })),
    ).toMatchObject({
      audience: 'OWNERS',
      title: 'Company approved',
      body: 'Alpha Lines has been approved. You can now add buses and trips.',
    });
    expect(
      onboardingNotice(
        event('onboarding.approved', {
          companyName: 'Alpha Lines',
          subjectType: 'BUS',
          busRegistrationNumber: 'KA01AB1234',
        }),
      ),
    ).toMatchObject({
      title: 'Bus approved',
      body: 'Alpha Lines, bus KA01AB1234 has been approved and is ready for trips.',
    });
  });

  it('puts the reviewer’s reasons in the rejection, so the owner can act without opening the app', () => {
    const notice = onboardingNotice(
      event('onboarding.rejected', {
        companyName: 'Alpha Lines',
        note: 'Please fix the GST certificate',
        rejectedDocuments: [
          { name: 'GST', reason: 'The image is blurred' },
          { name: 'PAN', reason: null },
        ],
      }),
    );
    expect(notice?.audience).toBe('OWNERS');
    expect(notice?.title).toBe('Documents need fixing');
    expect(notice?.body).toBe(
      'Alpha Lines: please fix and send again. GST: The image is blurred; PAN. Please fix the GST certificate',
    );
  });

  it('keeps a very long list of reasons short enough for a push', () => {
    const rejectedDocuments = Array.from({ length: 30 }, (_, index) => ({
      name: `Document ${index}`,
      reason: 'The photo is not clear enough to read',
    }));
    const body = onboardingNotice(event('onboarding.rejected', { rejectedDocuments }))?.body ?? '';
    expect(body.length).toBeLessThan(520);
    expect(body).toContain('...');
  });

  it('ignores other events and events without a submission', () => {
    expect(onboardingNotice(event('booking.confirmed', {}))).toBeUndefined();
    expect(
      onboardingNotice({ ...event('onboarding.submitted', {}), payload: { operatorId: 'o1' } }),
    ).toBeUndefined();
  });
});
