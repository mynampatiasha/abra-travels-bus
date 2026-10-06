import { ApiException } from './api-exception';

/** True for MongoDB's "duplicate key" error (a unique index refused the write). */
export function isDuplicateKeyError(error: unknown): boolean {
  return (
    typeof error === 'object' && error !== null && (error as { code?: unknown }).code === 11000
  );
}

/** Runs `write`; a unique-index violation becomes ALREADY_REGISTERED with `message`. */
export async function rejectDuplicates<T>(message: string, write: () => Promise<T>): Promise<T> {
  try {
    return await write();
  } catch (error) {
    if (isDuplicateKeyError(error)) throw new ApiException('ALREADY_REGISTERED', message);
    throw error;
  }
}
