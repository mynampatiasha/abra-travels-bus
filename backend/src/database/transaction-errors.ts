/** MongoDB error labels that make a transaction (or its commit) safe to retry. */
export const TRANSIENT_TRANSACTION_ERROR = 'TransientTransactionError';
export const UNKNOWN_TRANSACTION_COMMIT_RESULT = 'UnknownTransactionCommitResult';

/** Works for driver errors (hasErrorLabel) and plain objects carrying `errorLabels`. */
export function hasErrorLabel(error: unknown, label: string): boolean {
  if (typeof error !== 'object' || error === null) return false;
  const candidate = error as { hasErrorLabel?: unknown; errorLabels?: unknown };
  if (typeof candidate.hasErrorLabel === 'function') {
    return (candidate.hasErrorLabel as (value: string) => boolean).call(error, label);
  }
  return Array.isArray(candidate.errorLabels) && candidate.errorLabels.includes(label);
}

/**
 * The transaction kept failing with transient errors (e.g. write conflicts) until the attempt
 * limit. Nothing was committed. Domain services map this to their own code, e.g. the seat lock
 * maps it to SEAT_NOT_AVAILABLE (seat-locking.md step 6).
 */
export class TransactionRetriesExhaustedError extends Error {
  constructor(
    readonly attempts: number,
    options: { cause: unknown },
  ) {
    super(`Transaction aborted after ${attempts} attempts with transient errors`, options);
    this.name = 'TransactionRetriesExhaustedError';
  }
}

/**
 * The commit outcome stayed unknown after retrying the commit. The transaction may or may not
 * have been applied; callers must re-read state instead of assuming either result.
 */
export class TransactionCommitUnknownError extends Error {
  constructor(options: { cause: unknown }) {
    super('Transaction commit result is unknown after retries', options);
    this.name = 'TransactionCommitUnknownError';
  }
}
