import {
  CATALOGUE_KINDS,
  summaryOf,
  usageSentence,
  type UsageRule,
} from '../catalogue_shared_manage.service';
import { DELETION_ROUTES } from '../catalogue_shared_manage';

const route: UsageRule = { one: 'route', many: 'routes', model: 'Route', filter: () => ({}) };
const trip: UsageRule = { one: 'trip', many: 'trips', model: 'Trip', filter: () => ({}) };
const place: UsageRule = { one: 'place', many: 'places', model: 'Location', filter: () => ({}) };

describe('usageSentence', () => {
  it('is null when nothing uses the record', () => {
    expect(
      usageSentence('city', [
        { rule: route, count: 0 },
        { rule: trip, count: 0 },
      ]),
    ).toBeNull();
  });

  it('names one kind of user, singular and plural', () => {
    expect(usageSentence('city', [{ rule: route, count: 1 }])).toBe(
      'This city is used by 1 route, so it cannot be deleted. Disable it instead.',
    );
    expect(usageSentence('city', [{ rule: route, count: 3 }])).toBe(
      'This city is used by 3 routes, so it cannot be deleted. Disable it instead.',
    );
  });

  it('lists several kinds and skips the ones at zero', () => {
    expect(
      usageSentence('city', [
        { rule: place, count: 2 },
        { rule: route, count: 0 },
        { rule: trip, count: 5 },
      ]),
    ).toBe(
      'This city is used by 2 places and 5 trips, so it cannot be deleted. Disable it instead.',
    );
    expect(
      usageSentence('bus type', [
        { rule: place, count: 2 },
        { rule: route, count: 1 },
        { rule: trip, count: 5 },
      ]),
    ).toContain('2 places, 1 route and 5 trips');
  });
});

describe('summaryOf', () => {
  it('keeps only the fields a person would look for in the audit trail', () => {
    expect(
      summaryOf({
        _id: 'x',
        name: 'Hyderabad',
        state: 'Telangana',
        status: 'ACTIVE',
        tokenHash: 'secret',
      }),
    ).toEqual({ name: 'Hyderabad', status: 'ACTIVE' });
  });
});

describe('the deletion routes', () => {
  it('cover every kind exactly once, each with a delete permission', () => {
    const kinds = DELETION_ROUTES.map((entry) => entry.kind).sort();
    expect(kinds).toEqual(Object.keys(CATALOGUE_KINDS).sort());
    for (const entry of DELETION_ROUTES) expect(entry.permission).toMatch(/\.delete$/);
  });

  it('refuse to delete a pending or accepted invitation, but not a revoked one', () => {
    const refusal = CATALOGUE_KINDS.invitation.refusal;
    expect(refusal({ status: 'PENDING' })).toMatch(/Revoke it first/);
    expect(refusal({ status: 'ACCEPTED' })).toMatch(/cannot be deleted/);
    expect(refusal({ status: 'REVOKED' })).toBeNull();
  });
});
