import { type DomainEventMessage } from '../../../events/domain-event.types';
import { busTypeKeyOf, busTypeRequestNotice } from '../bus_type_requests_admin_manage.service';

const event = (type: string, payload: Record<string, unknown> = {}): DomainEventMessage => ({
  eventId: 'e1',
  type,
  aggregateType: 'bus_type_request',
  aggregateId: 'r1',
  occurredAt: '2026-10-13T10:00:00.000Z',
  payload: { requestId: 'r1', operatorName: 'Kaveri Express', name: 'Mini Coach', ...payload },
});

describe('busTypeRequestNotice', () => {
  it('tells Abra staff about a new request', () => {
    expect(busTypeRequestNotice(event('bus-type-request.created'))).toEqual({
      audience: 'REVIEWERS',
      title: 'Bus type request',
      body: 'Kaveri Express wants to add the bus type Mini Coach.',
      route: '/bus-types?tab=requests',
    });
  });

  it('tells the operator about the decision, with the reason of a rejection', () => {
    expect(busTypeRequestNotice(event('bus-type-request.approved'))).toMatchObject({
      audience: 'OPERATOR',
      title: 'Bus type approved',
    });
    expect(
      busTypeRequestNotice(event('bus-type-request.rejected', { reason: 'Use AC Sleeper' }))?.body,
    ).toBe('Mini Coach was not added. Reason: Use AC Sleeper');
  });

  it('ignores other events', () => {
    expect(busTypeRequestNotice(event('place-request.approved'))).toBeUndefined();
  });
});

describe('busTypeKeyOf', () => {
  it('makes an upper snake case key from the name', () => {
    expect(busTypeKeyOf('Mini Coach')).toBe('MINI_COACH');
    expect(busTypeKeyOf('  Non-AC  Seater + Sleeper ')).toBe('NON_AC_SEATER_SLEEPER');
  });

  it('starts with a letter and stays within 40 characters', () => {
    expect(busTypeKeyOf('12 Seater')).toBe('T_12_SEATER');
    expect(busTypeKeyOf('A'.repeat(80))).toHaveLength(40);
  });
});
