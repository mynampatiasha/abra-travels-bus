import { ApiException } from '../../common/errors/api-exception';
import {
  type DataScopeType,
  type RequestActor,
  systemActor,
} from '../../common/request-context/request-actor';
import {
  assertDocumentWithinScope,
  assertUpdateKeepsScope,
  MATCH_NOTHING,
  type ScopeFields,
  scopeFilterFor,
} from '../data-scope.policy';

const FIELDS: ScopeFields = { operator: 'operatorId', partner: 'partnerId', owner: 'customerId' };

function user(type: DataScopeType, operatorIds: string[] = [], partnerId?: string): RequestActor {
  return {
    actorType: 'USER',
    userId: 'user-1',
    ...(partnerId ? { partnerId } : {}),
    dataScope: { type, operatorIds },
  };
}

describe('scopeFilterFor', () => {
  it('is unrestricted for ALL and for SYSTEM actors', () => {
    expect(scopeFilterFor(user('ALL'), FIELDS)).toEqual({});
    expect(scopeFilterFor(systemActor('outbox relay'), FIELDS)).toEqual({});
  });

  it('limits operator scopes to their operator ids', () => {
    expect(scopeFilterFor(user('OWN_OPERATOR', ['op-a']), FIELDS)).toEqual({
      operatorId: { $in: ['op-a'] },
    });
    expect(scopeFilterFor(user('SELECTED_OPERATORS', ['op-a', 'op-b']), FIELDS)).toEqual({
      operatorId: { $in: ['op-a', 'op-b'] },
    });
  });

  it('matches nothing for an operator scope with no operator ids', () => {
    expect(scopeFilterFor(user('OWN_OPERATOR', []), FIELDS)).toEqual({
      operatorId: { $in: [] },
    });
  });

  it('limits partners to their partner and customers to their own records', () => {
    expect(scopeFilterFor(user('OWN_PARTNER', [], 'partner-9'), FIELDS)).toEqual({
      partnerId: 'partner-9',
    });
    expect(scopeFilterFor(user('OWN_RECORDS'), FIELDS)).toEqual({ customerId: 'user-1' });
  });

  it('limits ASSIGNED_RECORDS to the assigned ids (none by default)', () => {
    expect(scopeFilterFor(user('ASSIGNED_RECORDS'), FIELDS, ['trip-1'])).toEqual({
      _id: { $in: ['trip-1'] },
    });
    expect(scopeFilterFor(user('ASSIGNED_RECORDS'), FIELDS)).toEqual({ _id: { $in: [] } });
  });

  it('fails closed when the collection lacks the field the scope needs', () => {
    expect(scopeFilterFor(user('OWN_OPERATOR', ['op-a']), {})).toEqual(MATCH_NOTHING);
    expect(scopeFilterFor(user('OWN_PARTNER', [], 'p'), { operator: 'operatorId' })).toEqual(
      MATCH_NOTHING,
    );
    expect(scopeFilterFor(user('OWN_PARTNER'), FIELDS)).toEqual(MATCH_NOTHING); // no partnerId
    expect(scopeFilterFor(user('OWN_RECORDS'), { operator: 'operatorId' })).toEqual(MATCH_NOTHING);
  });
});

describe('assertDocumentWithinScope', () => {
  const denied = (fn: () => void): void => {
    expect(fn).toThrow(ApiException);
    expect(fn).toThrow('outside your data scope');
  };

  it('allows documents inside the scope', () => {
    expect(() =>
      assertDocumentWithinScope(user('OWN_OPERATOR', ['op-a']), FIELDS, { operatorId: 'op-a' }),
    ).not.toThrow();
    expect(() =>
      assertDocumentWithinScope(user('OWN_RECORDS'), FIELDS, { customerId: 'user-1' }),
    ).not.toThrow();
    expect(() =>
      assertDocumentWithinScope(user('OWN_PARTNER', [], 'p-1'), FIELDS, { partnerId: 'p-1' }),
    ).not.toThrow();
    expect(() =>
      assertDocumentWithinScope(systemActor('seeder'), FIELDS, { operatorId: 'any' }),
    ).not.toThrow();
  });

  it('compares ObjectId values by their hex string, and never matches other objects', () => {
    expect(() =>
      assertDocumentWithinScope(user('OWN_OPERATOR', ['[object Object]']), FIELDS, {
        operatorId: {},
      }),
    ).toThrow(ApiException);
    const objectIdLike = { toHexString: () => 'op-a' };
    expect(() =>
      assertDocumentWithinScope(user('OWN_OPERATOR', ['op-a']), FIELDS, {
        operatorId: objectIdLike,
      }),
    ).not.toThrow();
  });

  it('rejects documents for another tenant, missing ownership, or assigned-records actors', () => {
    denied(() =>
      assertDocumentWithinScope(user('OWN_OPERATOR', ['op-a']), FIELDS, { operatorId: 'op-b' }),
    );
    denied(() => assertDocumentWithinScope(user('OWN_OPERATOR', ['op-a']), FIELDS, {}));
    denied(() => assertDocumentWithinScope(user('OWN_RECORDS'), FIELDS, { customerId: 'user-2' }));
    denied(() => assertDocumentWithinScope(user('ASSIGNED_RECORDS'), FIELDS, { operatorId: 'x' }));
  });
});

describe('assertUpdateKeepsScope', () => {
  const scoped = user('OWN_OPERATOR', ['op-a']);

  it('allows updates that do not touch ownership fields', () => {
    expect(() =>
      assertUpdateKeepsScope(scoped, FIELDS, { $set: { name: 'x' }, $inc: { counter: 1 } }),
    ).not.toThrow();
  });

  it.each([
    ['$set', { $set: { operatorId: 'op-b' } }],
    ['bare key', { operatorId: 'op-b' }],
    ['$unset', { $unset: { customerId: '' } }],
    ['nested path', { $set: { 'partnerId.value': 'x' } }],
    ['$rename target', { $rename: { otherField: 'operatorId' } }],
    ['$setOnInsert', { $setOnInsert: { operatorId: 'op-b' } }],
  ])('rejects ownership changes via %s', (_label, update) => {
    expect(() => assertUpdateKeepsScope(scoped, FIELDS, update)).toThrow(
      'Ownership fields cannot be changed',
    );
  });

  it('lets unrestricted actors reassign ownership', () => {
    expect(() =>
      assertUpdateKeepsScope(user('ALL'), FIELDS, { $set: { operatorId: 'op-b' } }),
    ).not.toThrow();
  });

  it('rejects aggregation pipeline updates for every actor', () => {
    expect(() => assertUpdateKeepsScope(user('ALL'), FIELDS, [{ $set: { a: 1 } }])).toThrow(
      'Aggregation pipeline updates are not supported',
    );
  });
});
