import { Logger } from '@nestjs/common';
import { type ClientSession, type Connection } from 'mongoose';
import { ApiException } from '../../common/errors/api-exception';
import {
  TransactionCommitUnknownError,
  TransactionRetriesExhaustedError,
} from '../transaction-errors';
import { TransactionRunner } from '../transaction-runner.service';

function labelledError(label: string, code = 112): Error {
  return Object.assign(new Error(label), { code, errorLabels: [label] });
}
const transientError = (): Error => labelledError('TransientTransactionError');
const unknownCommitError = (): Error => labelledError('UnknownTransactionCommitResult', 50);

/** Records every session call; commit outcomes are scripted per test. */
class FakeSession {
  active = false;
  started = 0;
  commits = 0;
  commitCalls = 0;
  aborts = 0;
  ended = false;
  startOptions: unknown;
  readonly scriptedCommitErrors: Error[] = [];

  startTransaction(options: unknown): void {
    this.active = true;
    this.started++;
    this.startOptions = options;
  }
  inTransaction(): boolean {
    return this.active;
  }
  commitTransaction(): Promise<void> {
    this.commitCalls++;
    const error = this.scriptedCommitErrors.shift();
    if (error) {
      // A transient commit failure ends the transaction; an unknown result leaves it committable
      if (
        (error as { errorLabels?: string[] }).errorLabels?.includes('TransientTransactionError')
      ) {
        this.active = false;
      }
      return Promise.reject(error);
    }
    this.commits++;
    this.active = false;
    return Promise.resolve();
  }
  abortTransaction(): Promise<void> {
    this.aborts++;
    this.active = false;
    return Promise.resolve();
  }
  endSession(): Promise<void> {
    this.ended = true;
    return Promise.resolve();
  }
}

class ImmediateRetryRunner extends TransactionRunner {
  protected override backoff(): Promise<void> {
    return Promise.resolve();
  }
}

function setup(): { runner: TransactionRunner; session: FakeSession } {
  const session = new FakeSession();
  const connection = { startSession: () => Promise.resolve(session) } as unknown as Connection;
  return { runner: new ImmediateRetryRunner(connection), session };
}

describe('TransactionRunner', () => {
  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  it('commits a successful unit of work with snapshot / majority options', async () => {
    const { runner, session } = setup();
    const result = await runner.run(() => Promise.resolve('done'));

    expect(result).toBe('done');
    expect(session).toMatchObject({ started: 1, commits: 1, aborts: 0, ended: true });
    expect(session.startOptions).toEqual({
      readConcern: { level: 'snapshot' },
      writeConcern: { w: 'majority' },
      readPreference: 'primary',
    });
  });

  it('aborts and rethrows a non-transient error without retrying (rollback)', async () => {
    const { runner, session } = setup();
    const businessError = new ApiException('SEAT_NOT_AVAILABLE', 'Seat L-A1 is not available');
    const work = jest.fn(() => Promise.reject(businessError));

    await expect(runner.run(work)).rejects.toBe(businessError);
    expect(work).toHaveBeenCalledTimes(1);
    expect(session).toMatchObject({ started: 1, commits: 0, aborts: 1, ended: true });
  });

  it('retries the whole unit of work on TransientTransactionError, then commits', async () => {
    const { runner, session } = setup();
    const work = jest
      .fn<Promise<string>, [ClientSession]>()
      .mockRejectedValueOnce(transientError())
      .mockRejectedValueOnce(transientError())
      .mockResolvedValueOnce('committed');

    await expect(runner.run(work)).resolves.toBe('committed');
    expect(work).toHaveBeenCalledTimes(3);
    expect(session).toMatchObject({ started: 3, commits: 1, aborts: 2, ended: true });
  });

  it('gives up after the attempt limit with TransactionRetriesExhaustedError', async () => {
    const { runner, session } = setup();
    const lastError = transientError();
    const work = jest
      .fn<Promise<never>, [ClientSession]>()
      .mockRejectedValueOnce(transientError())
      .mockRejectedValueOnce(transientError())
      .mockRejectedValueOnce(lastError);

    const failure = runner.run(work);
    await expect(failure).rejects.toBeInstanceOf(TransactionRetriesExhaustedError);
    await expect(failure).rejects.toMatchObject({ attempts: 3, cause: lastError });
    expect(work).toHaveBeenCalledTimes(3);
    expect(session).toMatchObject({ commits: 0, aborts: 3, ended: true });
  });

  it('honours a custom maxAttempts', async () => {
    const { runner } = setup();
    const work = jest.fn(() => Promise.reject(transientError()));

    await expect(runner.run(work, { maxAttempts: 1 })).rejects.toMatchObject({ attempts: 1 });
    expect(work).toHaveBeenCalledTimes(1);
  });

  it('rejects an invalid maxAttempts', async () => {
    const { runner } = setup();
    await expect(runner.run(() => Promise.resolve(1), { maxAttempts: 0 })).rejects.toThrow(
      'maxAttempts must be a positive integer',
    );
  });

  it('retries the whole transaction when the commit fails transiently', async () => {
    const { runner, session } = setup();
    session.scriptedCommitErrors.push(transientError());
    const work = jest.fn(() => Promise.resolve('ok'));

    await expect(runner.run(work)).resolves.toBe('ok');
    expect(work).toHaveBeenCalledTimes(2);
    expect(session).toMatchObject({ started: 2, commits: 1 });
  });

  it('retries only the commit on UnknownTransactionCommitResult (work runs once)', async () => {
    const { runner, session } = setup();
    session.scriptedCommitErrors.push(unknownCommitError(), unknownCommitError());
    const work = jest.fn(() => Promise.resolve('ok'));

    await expect(runner.run(work)).resolves.toBe('ok');
    expect(work).toHaveBeenCalledTimes(1);
    expect(session).toMatchObject({ started: 1, commitCalls: 3, commits: 1 });
  });

  it('reports an unknown commit outcome after the commit retry limit', async () => {
    const { runner, session } = setup();
    session.scriptedCommitErrors.push(
      unknownCommitError(),
      unknownCommitError(),
      unknownCommitError(),
    );

    await expect(runner.run(() => Promise.resolve('ok'))).rejects.toBeInstanceOf(
      TransactionCommitUnknownError,
    );
    expect(session).toMatchObject({ commitCalls: 3, commits: 0, ended: true });
  });

  it('joins an existing transaction without starting or committing its own', async () => {
    const { runner, session } = setup();
    session.startTransaction({});
    const outer = session as unknown as ClientSession;

    await expect(
      runner.run((inner) => Promise.resolve(inner === outer), { session: outer }),
    ).resolves.toBe(true);
    expect(session).toMatchObject({ started: 1, commits: 0, aborts: 0 });
  });

  it('refuses to join a session that is not in a transaction', async () => {
    const { runner, session } = setup();
    await expect(
      runner.run(() => Promise.resolve(1), { session: session as unknown as ClientSession }),
    ).rejects.toThrow('not in a transaction');
  });
});
