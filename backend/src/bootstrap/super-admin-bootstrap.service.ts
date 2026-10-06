import { Injectable, Logger } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type Connection } from 'mongoose';
import { z } from 'zod';
import { emailSchema } from '../common/validation/contact-identifiers';
import { TransactionRunner } from '../database/transaction-runner.service';
import { AuditLogService } from '../modules/audit-logs/services/audit-log.service';
import { PasswordHasher } from '../modules/authentication/services/password-hasher.service';
import {
  assertPasswordAcceptable,
  newPasswordSchema,
} from '../modules/authentication/services/password-policy';
import { RoleRepository } from '../modules/rbac/repositories/role.repository';
import { UsersService } from '../modules/users/services/users.service';

/** Environment variables read by the bootstrap command, and by nothing else. */
export const BOOTSTRAP_VARIABLES = {
  email: 'BOOTSTRAP_SUPER_ADMIN_EMAIL',
  name: 'BOOTSTRAP_SUPER_ADMIN_NAME',
  password: 'BOOTSTRAP_SUPER_ADMIN_PASSWORD',
} as const;

const SUPER_ADMIN_ROLE = 'SUPER_ADMIN';
const MARKER_COLLECTION = 'system_markers';
const MARKER_ID = 'super-admin-bootstrap';

const inputSchema = z.object({
  email: emailSchema,
  name: z.string().trim().min(2).max(120),
  password: newPasswordSchema,
});

/** The bootstrap variables are missing or not acceptable. Never contains the password. */
export class BootstrapConfigurationError extends Error {
  constructor(readonly problems: string[]) {
    super(`Super Admin bootstrap is not configured correctly:\n- ${problems.join('\n- ')}`);
    this.name = 'BootstrapConfigurationError';
  }
}

export type BootstrapOutcome =
  | { created: true; userId: string; email: string }
  | { created: false; reason: 'SUPER_ADMIN_EXISTS' };

/**
 * Creates the first Super Admin of an installation (documentation/authorization.md §8).
 *
 * - Runs only from the command line (`npm run bootstrap:super-admin`); there is no HTTP endpoint.
 * - Does nothing when any account already holds the SUPER_ADMIN role, so it cannot be used to
 *   add a second administrator or to take over an installation.
 * - Two runs at the same time cannot both create an account: they write the same marker
 *   document inside their transactions, so one of them is retried and then finds the first.
 * - The account is created together with its audit entry, or not at all.
 */
@Injectable()
export class SuperAdminBootstrapService {
  private readonly logger = new Logger(SuperAdminBootstrapService.name);

  constructor(
    private readonly users: UsersService,
    private readonly roles: RoleRepository,
    private readonly hasher: PasswordHasher,
    private readonly audit: AuditLogService,
    private readonly transactions: TransactionRunner,
    @InjectConnection() private readonly connection: Connection,
  ) {}

  /** Reads and validates the bootstrap variables. Throws BootstrapConfigurationError. */
  static readInput(environment: Record<string, string | undefined>): z.output<typeof inputSchema> {
    const missing = Object.values(BOOTSTRAP_VARIABLES).filter((name) => !environment[name]);
    if (missing.length > 0) {
      throw new BootstrapConfigurationError(missing.map((name) => `${name} is required`));
    }
    const parsed = inputSchema.safeParse({
      email: environment[BOOTSTRAP_VARIABLES.email],
      name: environment[BOOTSTRAP_VARIABLES.name],
      password: environment[BOOTSTRAP_VARIABLES.password],
    });
    if (!parsed.success) {
      throw new BootstrapConfigurationError(
        parsed.error.issues.map(
          (issue) =>
            `${BOOTSTRAP_VARIABLES[issue.path[0] as keyof typeof BOOTSTRAP_VARIABLES]} ${issue.message}`,
        ),
      );
    }
    try {
      assertPasswordAcceptable(parsed.data.password, parsed.data);
    } catch (error) {
      throw new BootstrapConfigurationError([
        `${BOOTSTRAP_VARIABLES.password} ${error instanceof Error ? error.message : 'is not acceptable'}`,
      ]);
    }
    return parsed.data;
  }

  async run(environment: Record<string, string | undefined>): Promise<BootstrapOutcome> {
    const input = SuperAdminBootstrapService.readInput(environment);
    const [role] = await this.roles.findByKeys([SUPER_ADMIN_ROLE]);
    if (!role) throw new Error('The SUPER_ADMIN role does not exist; roles were not synchronised');
    const passwordHash = await this.hasher.hash(input.password);

    const outcome = await this.transactions.run<BootstrapOutcome>(async (session) => {
      // Serialises concurrent runs: both write this document, so one transaction is retried
      await this.connection
        .collection<{ _id: string }>(MARKER_COLLECTION)
        .updateOne(
          { _id: MARKER_ID },
          { $set: { lastRunAt: new Date() }, $inc: { runs: 1 } },
          { upsert: true, session },
        );
      if ((await this.users.countWithRole(role._id, session)) > 0) {
        return { created: false, reason: 'SUPER_ADMIN_EXISTS' };
      }
      const user = await this.users.createStaff(
        { name: input.name, email: input.email, passwordHash, roleIds: [role._id] },
        session,
      );
      await this.audit.record(
        {
          // The first administrator has nobody to be created by: it is recorded as its own actor
          actor: {
            actorType: 'USER',
            userId: user._id.toHexString(),
            userType: 'STAFF',
            sessionId: 'bootstrap',
            dataScope: { type: 'ALL', operatorIds: [] },
            permissionVersion: user.permissionVersion,
            roleIds: [role._id.toHexString()],
            mfaEnrollmentPending: false,
          },
          actorRoleKeys: [SUPER_ADMIN_ROLE],
          action: 'user.super-admin.bootstrapped',
          entityType: 'user',
          entityId: user._id,
          before: {},
          after: { email: input.email, name: input.name, roleKeys: [SUPER_ADMIN_ROLE] },
          reason: 'First administrator created by the bootstrap command',
        },
        session,
      );
      return { created: true, userId: user._id.toHexString(), email: input.email };
    });

    if (outcome.created) {
      this.logger.log({ userId: outcome.userId }, 'Super Admin created');
    } else {
      this.logger.warn('A Super Admin already exists; nothing was created');
    }
    return outcome;
  }
}
