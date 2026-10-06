import {
  BOOTSTRAP_VARIABLES,
  BootstrapConfigurationError,
  SuperAdminBootstrapService,
} from '../super-admin-bootstrap.service';

const valid = {
  BOOTSTRAP_SUPER_ADMIN_EMAIL: '  Asha.Admin@Example.com ',
  BOOTSTRAP_SUPER_ADMIN_NAME: ' Asha Admin ',
  BOOTSTRAP_SUPER_ADMIN_PASSWORD: 'first-admin-lantern-quartz',
};

const problemsOf = (environment: Record<string, string | undefined>): string[] => {
  try {
    SuperAdminBootstrapService.readInput(environment);
  } catch (error) {
    if (error instanceof BootstrapConfigurationError) return error.problems;
    throw error;
  }
  return [];
};

describe('Super Admin bootstrap configuration', () => {
  it('reads and normalises the three variables', () => {
    expect(SuperAdminBootstrapService.readInput(valid)).toEqual({
      email: 'asha.admin@example.com',
      name: 'Asha Admin',
      password: 'first-admin-lantern-quartz',
    });
  });

  it('names every missing variable', () => {
    expect(problemsOf({})).toEqual(
      Object.values(BOOTSTRAP_VARIABLES).map((name) => `${name} is required`),
    );
    expect(problemsOf({ ...valid, BOOTSTRAP_SUPER_ADMIN_NAME: '' })).toEqual([
      'BOOTSTRAP_SUPER_ADMIN_NAME is required',
    ]);
  });

  it.each([
    ['an invalid email', { BOOTSTRAP_SUPER_ADMIN_EMAIL: 'admin-at-example' }, 'EMAIL'],
    ['a one-letter name', { BOOTSTRAP_SUPER_ADMIN_NAME: 'A' }, 'NAME'],
    ['a short password', { BOOTSTRAP_SUPER_ADMIN_PASSWORD: 'nine-char' }, 'PASSWORD'],
    [
      'a repeated-character password',
      { BOOTSTRAP_SUPER_ADMIN_PASSWORD: 'aaaaaaaaaaaa' },
      'PASSWORD',
    ],
    [
      'a password containing the email',
      { BOOTSTRAP_SUPER_ADMIN_PASSWORD: 'asha.admin@example.com' },
      'PASSWORD',
    ],
  ])('rejects %s', (_name, change, variable) => {
    const problems = problemsOf({ ...valid, ...change });
    expect(problems).toHaveLength(1);
    expect(problems[0]).toContain(`BOOTSTRAP_SUPER_ADMIN_${variable}`);
  });

  it('never repeats the password in an error', () => {
    const secret = 'aaaaaaaaaaaa';
    try {
      SuperAdminBootstrapService.readInput({ ...valid, BOOTSTRAP_SUPER_ADMIN_PASSWORD: secret });
      throw new Error('expected a rejection');
    } catch (error) {
      expect((error as Error).message).not.toContain(secret);
    }
  });
});
