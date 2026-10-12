import { copyTitleOf, movedOrder } from '../banners_admin_manage.service';
import { bannerStatusOf, statusCondition } from '../admin-banners.model';

describe('copyTitleOf', () => {
  it('adds (copy)', () => {
    expect(copyTitleOf('Festive special')).toBe('Festive special (copy)');
  });
  it('stays within 80 characters', () => {
    const title = copyTitleOf('y'.repeat(80));
    expect(title).toHaveLength(80);
    expect(title.endsWith(' (copy)')).toBe(true);
  });
});

describe('movedOrder', () => {
  const ids = ['a', 'b', 'c'];
  it('moves one place', () => {
    expect(movedOrder(ids, 'a', 'down')).toEqual(['b', 'a', 'c']);
    expect(movedOrder(ids, 'c', 'up')).toEqual(['a', 'c', 'b']);
    expect(movedOrder(ids, 'b', 'up')).toEqual(['b', 'a', 'c']);
  });
  it('does nothing at the ends or for an unknown id', () => {
    expect(movedOrder(ids, 'a', 'up')).toBeNull();
    expect(movedOrder(ids, 'c', 'down')).toBeNull();
    expect(movedOrder(ids, 'zzz', 'down')).toBeNull();
  });
  it('does not change the list it was given', () => {
    movedOrder(ids, 'a', 'down');
    expect(ids).toEqual(['a', 'b', 'c']);
  });
});

describe('archived banners', () => {
  const now = new Date('2026-10-12T10:00:00Z');
  it('are ARCHIVED whatever else is true', () => {
    expect(
      bannerStatusOf({ isActive: true, startsAt: null, endsAt: null, archivedAt: now }, now),
    ).toBe('ARCHIVED');
  });
  it('every other status condition leaves archived banners out', () => {
    expect(statusCondition('INACTIVE', now)).toMatchObject({ archivedAt: null });
    expect(statusCondition('LIVE', now)).toMatchObject({ archivedAt: null });
    expect(statusCondition('SCHEDULED', now)).toMatchObject({ archivedAt: null });
    expect(statusCondition('EXPIRED', now)).toMatchObject({ archivedAt: null });
    expect(statusCondition('ARCHIVED', now)).toEqual({ archivedAt: { $ne: null } });
  });
});
