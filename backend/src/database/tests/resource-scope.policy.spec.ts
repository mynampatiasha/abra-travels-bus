import {
  type DataScopeType,
  type RequestActor,
  systemActor,
  type UserActor,
} from '../../common/request-context/request-actor';
import { isResourceWithinScope, type ResourceOwnership } from '../data-scope.policy';

const OPERATOR_A = 'aaaaaaaaaaaaaaaaaaaaaaaa';
const OPERATOR_B = 'bbbbbbbbbbbbbbbbbbbbbbbb';
const OPERATOR_C = 'cccccccccccccccccccccccc';
const PARTNER_A = '111111111111111111111111';
const PARTNER_B = '222222222222222222222222';
const USER = '999999999999999999999999';
const OTHER_USER = '888888888888888888888888';

function actor(
  type: DataScopeType,
  operatorIds: string[] = [],
  extra: Partial<UserActor> = {},
): UserActor {
  return { actorType: 'USER', userId: USER, dataScope: { type, operatorIds }, ...extra };
}

const RESOURCES: Record<string, ResourceOwnership> = {
  operatorA: { operatorId: OPERATOR_A },
  operatorB: { operatorId: OPERATOR_B },
  partnerA: { operatorId: OPERATOR_A, partnerId: PARTNER_A },
  partnerB: { operatorId: OPERATOR_A, partnerId: PARTNER_B },
  mine: { operatorId: OPERATOR_A, ownerUserId: USER },
  someoneElses: { operatorId: OPERATOR_A, ownerUserId: OTHER_USER },
  assignedToMe: { operatorId: OPERATOR_A, assignedUserIds: [OTHER_USER, USER] },
  assignedToOthers: { operatorId: OPERATOR_A, assignedUserIds: [OTHER_USER] },
  noFacts: {},
};

function visibleTo(who: RequestActor): string[] {
  return Object.entries(RESOURCES)
    .filter(([, resource]) => isResourceWithinScope(who, resource))
    .map(([name]) => name);
}

describe('isResourceWithinScope (data scope applied to one resource)', () => {
  it('ALL reaches everything', () => {
    expect(visibleTo(actor('ALL'))).toEqual(Object.keys(RESOURCES));
  });

  it('SYSTEM (background jobs) reaches everything', () => {
    expect(visibleTo(systemActor('outbox relay'))).toEqual(Object.keys(RESOURCES));
  });

  it('OWN_OPERATOR reaches only its operator — operator isolation', () => {
    const operatorA = actor('OWN_OPERATOR', [OPERATOR_A]);
    expect(isResourceWithinScope(operatorA, RESOURCES.operatorA!)).toBe(true);
    expect(isResourceWithinScope(operatorA, RESOURCES.operatorB!)).toBe(false);
    expect(isResourceWithinScope(actor('OWN_OPERATOR', [OPERATOR_B]), RESOURCES.operatorA!)).toBe(
      false,
    );
  });

  it('SELECTED_OPERATORS reaches exactly the selected operators', () => {
    const selected = actor('SELECTED_OPERATORS', [OPERATOR_A, OPERATOR_C]);
    expect(isResourceWithinScope(selected, { operatorId: OPERATOR_A })).toBe(true);
    expect(isResourceWithinScope(selected, { operatorId: OPERATOR_C })).toBe(true);
    expect(isResourceWithinScope(selected, { operatorId: OPERATOR_B })).toBe(false);
  });

  it('an operator scope with no operators reaches nothing', () => {
    expect(visibleTo(actor('OWN_OPERATOR', []))).toEqual([]);
    expect(visibleTo(actor('SELECTED_OPERATORS', []))).toEqual([]);
  });

  it('OWN_PARTNER reaches only its partner — partner isolation', () => {
    const partnerA = actor('OWN_PARTNER', [], { partnerId: PARTNER_A });
    expect(visibleTo(partnerA)).toEqual(['partnerA']);
    expect(visibleTo(actor('OWN_PARTNER', [], { partnerId: PARTNER_B }))).toEqual(['partnerB']);
  });

  it('OWN_PARTNER without a partner on the actor reaches nothing', () => {
    expect(visibleTo(actor('OWN_PARTNER'))).toEqual([]);
  });

  it('OWN_RECORDS reaches only records owned by the actor', () => {
    expect(visibleTo(actor('OWN_RECORDS'))).toEqual(['mine']);
  });

  it('ASSIGNED_RECORDS reaches only records assigned to the actor', () => {
    expect(visibleTo(actor('ASSIGNED_RECORDS'))).toEqual(['assignedToMe']);
  });

  it('fails closed when the resource does not state the fact the scope needs', () => {
    for (const type of [
      'OWN_OPERATOR',
      'SELECTED_OPERATORS',
      'OWN_PARTNER',
      'OWN_RECORDS',
      'ASSIGNED_RECORDS',
    ] as const) {
      const who = actor(type, [OPERATOR_A], { partnerId: PARTNER_A });
      expect(isResourceWithinScope(who, {})).toBe(false);
      expect(
        isResourceWithinScope(who, { operatorId: null, partnerId: null, ownerUserId: null }),
      ).toBe(false);
    }
  });

  it('fails closed for an unknown scope type', () => {
    const tampered = actor('EVERYTHING' as DataScopeType, [OPERATOR_A]);
    expect(visibleTo(tampered)).toEqual([]);
  });
});
