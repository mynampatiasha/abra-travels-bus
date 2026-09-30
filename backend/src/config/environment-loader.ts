import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { parseEnv } from 'node:util';
import { type AppEnvironment, environmentSchema } from './environment.schema';

export class EnvironmentValidationError extends Error {
  constructor(readonly problems: readonly string[]) {
    super(`Invalid backend configuration:\n  - ${problems.join('\n  - ')}`);
    this.name = 'EnvironmentValidationError';
  }
}

/**
 * Validates raw variables. Error messages name the variable and the rule only — never the value,
 * so secrets cannot leak into start-up logs.
 */
export function validateEnvironment(raw: Record<string, string | undefined>): AppEnvironment {
  // `KEY=` in a .env file means "not set"
  const cleaned = Object.fromEntries(
    Object.entries(raw).filter(([, value]) => value !== undefined && value.trim() !== ''),
  );
  const result = environmentSchema.safeParse(cleaned);
  if (result.success) return result.data;

  const problems = result.error.issues.map((issue) => {
    const key = issue.path.join('.') || '(root)';
    const missing = issue.input === undefined && issue.code !== 'custom';
    return `${key}: ${missing ? 'is required' : issue.message}`;
  });
  throw new EnvironmentValidationError(problems);
}

/**
 * Reads `backend/.env.<NODE_ENV>` when present (development and test only; staging and
 * production receive variables from the secret manager), then validates.
 * Real process environment variables win over the file.
 */
export function loadEnvironment(
  processEnvironment: NodeJS.ProcessEnv = process.env,
  backendRoot: string = process.cwd(),
): AppEnvironment {
  const nodeEnvironment = processEnvironment.NODE_ENV ?? 'development';
  const environmentFile = join(backendRoot, `.env.${nodeEnvironment}`);
  const readsFile =
    (nodeEnvironment === 'development' || nodeEnvironment === 'test') &&
    existsSync(environmentFile);
  const fileValues = readsFile ? parseEnv(readFileSync(environmentFile, 'utf8')) : {};

  return validateEnvironment({ NODE_ENV: nodeEnvironment, ...fileValues, ...processEnvironment });
}
