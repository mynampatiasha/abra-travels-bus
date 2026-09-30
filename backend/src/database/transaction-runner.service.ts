import { Injectable, Logger } from '@nestjs/common';
import { InjectConnection } from '@nestjs/mongoose';
import { type ClientSession, type Connection, type mongo } from 'mongoose';
import {
  hasErrorLabel,
  TRANSIENT_TRANSACTION_ERROR,
  TransactionCommitUnknownError,
  TransactionRetriesExhaustedError,
  UNKNOWN_TRANSACTION_COMMIT_RESULT,
} from './transaction-errors';

/** database-architecture.md §11: snapshot reads, majority writes, primary only. */
export const TRANSACTION_OPTIONS: mongo.TransactionOptions = {
  readConcern: { level: 'snapshot' },
  writeConcern: { w: 'majority' },
  readPreference: 'primary',
};

/** Whole-transaction attempts on TransientTransactionError (seat-locking.md: bounded, 3). */
export const DEFAULT_MAX_ATTEMPTS = 3;
/** Commit retries on UnknownTransactionCommitResult (commit is safe to repeat). */
export const MAX_COMMIT_ATTEMPTS = 3;

export interface RunInTransactionOptions {
  /** Overrides DEFAULT_MAX_ATTEMPTS. Must be >= 1. */
  maxAttempts?: number;
  /**
   * Join a transaction that is already running (a service called from inside another
   * transaction). The outer runner owns commit, abort and retries.
   */
  session?: ClientSession;
}

export type TransactionWork<T> = (session: ClientSession) => Promise<T>;

/**
 * Runs `work` inside one MongoDB multi-document transaction and retries the whole unit of work
 * when MongoDB labels the failure as transient. `work` must pass `{ session }` to every read and
 * write, and must be safe to run more than once (no side effects outside MongoDB — emit events
 * through the outbox inside the transaction instead).
 *
 * The driver's `withTransaction` retries for up to 120 s; this runner bounds retries by attempt
 * count so a hot seat fails fast instead of queueing requests.
 */
@Injectable()
export class TransactionRunner {
  private readonly logger = new Logger(TransactionRunner.name);

  constructor(@InjectConnection() private readonly connection: Connection) {}

  async run<T>(work: TransactionWork<T>, options: RunInTransactionOptions = {}): Promise<T> {
    if (options.session) {
      if (!options.session.inTransaction()) {
        throw new Error('The session passed to TransactionRunner.run is not in a transaction');
      }
      return work(options.session);
    }

    const maxAttempts = options.maxAttempts ?? DEFAULT_MAX_ATTEMPTS;
    if (!Number.isInteger(maxAttempts) || maxAttempts < 1) {
      throw new Error('maxAttempts must be a positive integer');
    }

    const session = await this.connection.startSession();
    try {
      return await this.runWithRetries(session, work, maxAttempts);
    } finally {
      await session.endSession();
    }
  }

  private async runWithRetries<T>(
    session: ClientSession,
    work: TransactionWork<T>,
    maxAttempts: number,
  ): Promise<T> {
    for (let attempt = 1; ; attempt++) {
      session.startTransaction(TRANSACTION_OPTIONS);
      try {
        const result = await work(session);
        await this.commitWithRetry(session);
        return result;
      } catch (error) {
        await this.abortIfActive(session);

        if (!hasErrorLabel(error, TRANSIENT_TRANSACTION_ERROR)) throw error;
        if (attempt >= maxAttempts) {
          throw new TransactionRetriesExhaustedError(attempt, { cause: error });
        }
        this.logger.warn(
          { attempt, maxAttempts, errorCode: (error as { code?: unknown }).code },
          'Transient transaction error; retrying',
        );
        await this.backoff(attempt);
      }
    }
  }

  private async commitWithRetry(session: ClientSession): Promise<void> {
    for (let commitAttempt = 1; ; commitAttempt++) {
      try {
        await session.commitTransaction();
        return;
      } catch (error) {
        // A transient commit failure aborts the transaction; the outer loop retries all of it
        if (!hasErrorLabel(error, UNKNOWN_TRANSACTION_COMMIT_RESULT)) throw error;
        if (commitAttempt >= MAX_COMMIT_ATTEMPTS) {
          throw new TransactionCommitUnknownError({ cause: error });
        }
        this.logger.warn({ commitAttempt }, 'Transaction commit result unknown; retrying commit');
      }
    }
  }

  private async abortIfActive(session: ClientSession): Promise<void> {
    if (!session.inTransaction()) return;
    try {
      await session.abortTransaction();
    } catch (abortError) {
      // The server discards the transaction on its own; keep the original error
      this.logger.warn(
        { errorMessage: abortError instanceof Error ? abortError.message : 'unknown' },
        'Transaction abort failed',
      );
    }
  }

  /** Short jittered back-off so competing transactions do not collide again immediately. */
  protected backoff(attempt: number): Promise<void> {
    const delayMs = 10 * 2 ** (attempt - 1) + Math.floor(Math.random() * 10);
    return new Promise((resolve) => setTimeout(resolve, delayMs));
  }
}
