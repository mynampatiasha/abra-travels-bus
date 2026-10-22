import { CLIENT_ROLE_NAMES, StaffClientManageService } from '../staff_client_manage.service';

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

  it('builds permission matrix dynamically from real system role keys', async () => {
    const mockRoleRepo = {
      findByKey: jest.fn().mockResolvedValue(null),
    };

    const service = new StaffClientManageService(
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      mockRoleRepo as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
      {} as never,
    );

    const matrix = await service.permissionMatrix();

    expect(matrix.roles).toHaveLength(4);
    expect(matrix.pages.length).toBeGreaterThan(15);

    // Verify Booking staff has NONE on routes (does not have routes.* key)
    const routesRow = matrix.pages.find((p) => p.id === 'routes');
    expect(routesRow).toBeDefined();
    expect(routesRow?.levels.booking).toBe('NONE');

    // Verify Manager has NONE on offers (does not have offers.* key)
    const offersRow = matrix.pages.find((p) => p.id === 'offers');
    expect(offersRow).toBeDefined();
    expect(offersRow?.levels.manager).toBe('NONE');

    // Verify Fleet & Buses
    const busesRow = matrix.pages.find((p) => p.id === 'buses');
    expect(busesRow).toBeDefined();
    expect(busesRow?.levels.owner).toBe('FULL');
    expect(busesRow?.levels.manager).toBe('EDIT');
    expect(busesRow?.levels.booking).toBe('VIEW');
    expect(busesRow?.levels.accounts).toBe('NONE');
  });
});
