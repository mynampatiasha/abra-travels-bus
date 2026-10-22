import { hashToken, STAFF_INVITATION_DAYS } from '../staff_admin_manage.service';

describe('StaffAdminManageService unit checks', () => {
  it('hashToken creates consistent sha256 hash', () => {
    const token = 'sample-random-token-12345';
    const hash1 = hashToken(token);
    const hash2 = hashToken(token);
    expect(hash1).toBe(hash2);
    expect(hash1).toHaveLength(64);
  });

  it('invitation validity is 7 days', () => {
    expect(STAFF_INVITATION_DAYS).toBe(7);
  });
});
