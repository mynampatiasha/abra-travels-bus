import { type DomainEventMessage } from '../../../events/domain-event.types';
import { placeRequestNotice } from '../places_admin_manage.service';

const event = (type: string, payload: Record<string, unknown> = {}): DomainEventMessage => ({
  eventId: 'e1',
  type,
  aggregateType: 'place_request',
  aggregateId: 'r1',
  occurredAt: '2026-10-13T10:00:00.000Z',
  payload: {
    requestId: 'r1',
    operatorName: 'Kaveri Express',
    name: 'Hosur Bus Stand Gate 2',
    cityName: 'Hosur',
    ...payload,
  },
});

describe('placeRequestNotice', () => {
  it('tells Abra staff about a new request, as the demo words it', () => {
    expect(placeRequestNotice(event('place-request.created'))).toEqual({
      audience: 'REVIEWERS',
      title: 'Place request',
      body: 'Kaveri Express wants to add Hosur Bus Stand Gate 2, Hosur.',
      route: '/places?tab=requests',
    });
  });

  it('tells the operator about the decision, with the reason of a rejection', () => {
    expect(placeRequestNotice(event('place-request.approved'))).toMatchObject({
      audience: 'OPERATOR',
      title: 'Place approved',
    });
    expect(
      placeRequestNotice(event('place-request.rejected', { reason: 'Too close to Gate 1' }))?.body,
    ).toBe('Hosur Bus Stand Gate 2, Hosur was not added. Reason: Too close to Gate 1');
  });

  it('ignores other events', () => {
    expect(placeRequestNotice(event('onboarding.approved'))).toBeUndefined();
  });
});
