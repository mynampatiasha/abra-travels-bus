import { EnvironmentValidationError, loadEnvironment } from './environment-loader';

/**
 * Validates configuration before anything connects (API and worker entry points). On failure it
 * prints the problems — key names only, never values — and exits with code 1.
 */
export function exitOnInvalidEnvironment(processName: string): void {
  try {
    loadEnvironment();
  } catch (error) {
    if (error instanceof EnvironmentValidationError) {
      process.stderr.write(`${error.message}\n\nThe ${processName} was not started.\n`);
      process.exit(1);
    }
    throw error;
  }
}
