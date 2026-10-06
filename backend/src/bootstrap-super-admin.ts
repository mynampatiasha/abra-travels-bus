import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import {
  BootstrapConfigurationError,
  SuperAdminBootstrapService,
} from './bootstrap/super-admin-bootstrap.service';
import { SuperAdminBootstrapModule } from './bootstrap/super-admin-bootstrap.module';
import { exitOnInvalidEnvironment } from './config/exit-on-invalid-environment';

/**
 * Creates the first Super Admin (`npm run bootstrap:super-admin`, or
 * `node dist/bootstrap-super-admin.js` in a deployed image). Reads BOOTSTRAP_SUPER_ADMIN_EMAIL,
 * BOOTSTRAP_SUPER_ADMIN_NAME and BOOTSTRAP_SUPER_ADMIN_PASSWORD from the environment of this
 * command only. Exit code 0: created, or an administrator already exists. Exit code 1: failed.
 */
async function main(): Promise<void> {
  exitOnInvalidEnvironment('Super Admin bootstrap');
  // Fail on configuration before connecting to anything
  SuperAdminBootstrapService.readInput(process.env);

  const app = await NestFactory.createApplicationContext(SuperAdminBootstrapModule, {
    logger: ['error', 'warn'],
  });
  try {
    const outcome = await app.get(SuperAdminBootstrapService).run(process.env);
    process.stdout.write(
      outcome.created
        ? `Super Admin created for ${outcome.email}. Sign in, then remove the BOOTSTRAP_SUPER_ADMIN_* variables.\n`
        : 'A Super Admin already exists. Nothing was created.\n',
    );
  } finally {
    await app.close();
  }
}

main().catch((error: unknown) => {
  const message =
    error instanceof BootstrapConfigurationError
      ? error.message
      : `Super Admin bootstrap failed: ${error instanceof Error ? error.message : String(error)}`;
  process.stderr.write(`${message}\n`);
  process.exit(1);
});
