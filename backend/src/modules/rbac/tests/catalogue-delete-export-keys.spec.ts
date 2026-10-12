import { findPage, keysForPageLevel } from '../permissions/access-pages';

/**
 * Phase 1: the matrix must tell Edit from Edit+Delete on the catalogue pages, and let every role
 * that can open a page export its list (the demos show Export CSV to viewers).
 */
describe('delete and export keys on the Phase 1 admin pages', () => {
  const cases: ReadonlyArray<[pageId: string, module: string]> = [
    ['places', 'catalogue'],
    ['bustypes', 'catalogue'],
    ['documents', 'documents'],
    ['questions', 'documents'],
    ['operators', 'operators'],
    ['invitations', 'operators'],
    ['banners', 'banners'],
  ];

  it.each(cases)('page %s: View exports, Edit cannot delete, Full can', (pageId, module) => {
    const page = findPage('ADMIN', pageId);
    expect(page).toBeDefined();
    const view = keysForPageLevel(page!, 'VIEW');
    const edit = keysForPageLevel(page!, 'EDIT');
    const full = keysForPageLevel(page!, 'FULL');

    expect(view).toContain(`${module}.export`);
    expect(edit).toContain(`${module}.export`);
    expect(edit).not.toContain(`${module}.delete`);
    expect(view).not.toContain(`${module}.delete`);
    expect(full).toContain(`${module}.delete`);
    expect(full).toContain(`${module}.export`);
  });

  it('banners can be opened at View level without being changed', () => {
    const page = findPage('ADMIN', 'banners')!;
    expect(keysForPageLevel(page, 'VIEW')).toContain('banners.read');
    expect(keysForPageLevel(page, 'VIEW')).not.toContain('banners.manage');
    expect(keysForPageLevel(page, 'EDIT')).toContain('banners.manage');
  });
});
