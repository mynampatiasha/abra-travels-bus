import { type DomainEventMessage } from '../../../events/domain-event.types';
import { operatorNotice } from '../operators_admin_manage.service';

function event(type: string, payload: Record<string, unknown>): DomainEventMessage {
  return {
    eventId: 'e1',
    type,
    aggregateType: 'operator',
    aggregateId: 'a1',
    occurredAt: '2026-10-13T10:00:00.000Z',
    payload,
  };
}

describe('operatorNotice', () => {
  it('tells the owner a suspension stops new sales and gives the reason', () => {
    const notice = operatorNotice(event('operator.suspended', { reason: 'Forged documents' }));
    expect(notice?.title).toBe('Your company is suspended');
    expect(notice?.body).toContain('New sales are stopped');
    expect(notice?.body).toContain('Trips already sold still run');
    expect(notice?.body).toContain('Forged documents');
  });

  it('never carries the proof note, which stays with Abra', () => {
    const notice = operatorNotice(
      event('operator.suspended', { reason: 'Forged documents', proofNote: 'RTO said so' }),
    );
    expect(notice?.body).not.toContain('RTO said so');
  });

  it('tells the owner the company can sell again', () => {
    const notice = operatorNotice(event('operator.reactivated', { companyName: 'Kaveri Express' }));
    expect(notice?.title).toBe('Your company is active again');
    expect(notice?.body).toContain('Kaveri Express');
  });

  it('passes a message from Abra as it is', () => {
    expect(
      operatorNotice(event('operator.messaged', { message: 'Renew your insurance.' })),
    ).toEqual({
      title: 'Message from Abra Travels',
      body: 'Renew your insurance.',
    });
  });

  it('says nothing for another event', () => {
    expect(operatorNotice(event('operator.something-else', {}))).toBeUndefined();
  });
});
