import { CLIENT_ROLE_NAMES } from '../staff_client_manage.service';

describe('StaffClientManageService unit checks', () => {
  it('maps client role keys correctly to demo display names', () => {
    expect(CLIENT_ROLE_NAMES.SUPER_ADMIN).toBe('Owner');
    expect(CLIENT_ROLE_NAMES.OPERATOR_ADMIN).toBe('Owner');
    expect(CLIENT_ROLE_NAMES.ADMIN).toBe('Manager');
    expect(CLIENT_ROLE_NAMES.OPERATOR_MANAGER).toBe('Manager');
    expect(CLIENT_ROLE_NAMES.SUPPORT).toBe('Booking staff');
    expect(CLIENT_ROLE_NAMES.BOOKING_STAFF).toBe('Booking staff');
    expect(CLIENT_ROLE_NAMES.ACCOUNTS).toBe('Accounts');
    expect(CLIENT_ROLE_NAMES.ACCOUNT_STAFF).toBe('Accounts');
  });
});
