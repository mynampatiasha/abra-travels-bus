import { type INestApplication } from '@nestjs/common';
import { getConnectionToken, getModelToken } from '@nestjs/mongoose';
import { type Connection, type Model, Schema, Types } from 'mongoose';
import { IndexBootstrapService } from '../index-bootstrap.service';
import { TransactionRetriesExhaustedError } from '../transaction-errors';
import { TransactionRunner } from '../transaction-runner.service';
import {
  createDatabaseTestApplication,
  SCOPE_PROBE_COLLECTION,
  SCOPE_PROBE_MODEL,
  type ScopeProbe,
} from './scope-probe.fixture';

/** Real multi-document transactions against the Docker replica set (rs0). */
describe('Transaction layer (e2e, real MongoDB replica set)', () => {
  let app: INestApplication;
  let connection: Connection;
  let runner: TransactionRunner;
  let probes: Model<ScopeProbe>;
  const operatorId = new Types.ObjectId();

  beforeAll(async () => {
    app = await createDatabaseTestApplication();
    connection = app.get<Connection>(getConnectionToken());
    runner = app.get(TransactionRunner);
    probes = app.get<Model<ScopeProbe>>(getModelToken(SCOPE_PROBE_MODEL));
  });

  afterAll(async () => {
    await connection?.dropDatabase();
    await app?.close();
  });

  beforeEach(async () => {
    await probes.deleteMany({});
  });

  it('runs against the abra_travels_test database on a replica set', async () => {
    expect(connection.name).toBe('abra_travels_test');
    const hello = await connection.db!.admin().command({ hello: 1 });
    expect(hello.setName).toBe('rs0');
  });

  it('commits all writes of a transaction together', async () => {
    await runner.run(async (session) => {
      await probes.create([{ operatorId, code: 'commit-1' }], { session });
      await probes.create([{ operatorId, code: 'commit-2' }], { session });
    });
    expect(await probes.countDocuments({ code: /^commit-/ })).toBe(2);
  });

  it('rolls back every write when the unit of work throws', async () => {
    await expect(
      runner.run(async (session) => {
        await probes.create([{ operatorId, code: 'rollback-1' }], { session });
        await probes.create([{ operatorId, code: 'rollback-2' }], { session });
        throw new Error('business rule failed');
      }),
    ).rejects.toThrow('business rule failed');
    expect(await probes.countDocuments({ code: /^rollback-/ })).toBe(0);
  });

  it('rolls back when a unique index is violated mid-transaction', async () => {
    await probes.create({ operatorId, code: 'taken' });
    await expect(
      runner.run(async (session) => {
        await probes.create([{ operatorId, code: 'first-write' }], { session });
        await probes.create([{ operatorId, code: 'taken' }], { session });
      }),
    ).rejects.toMatchObject({ code: 11000 });
    expect(await probes.countDocuments({ code: 'first-write' })).toBe(0);
  });

  it('retries a real WriteConflict and applies both concurrent increments exactly once', async () => {
    const { _id } = await probes.create({ operatorId, code: 'hot-row', counter: 0 });
    let attempts = 0;
    let firstWriteDone!: () => void;
    const firstWrite = new Promise<void>((resolve) => (firstWriteDone = resolve));
    let conflictSeen!: () => void;
    const conflict = new Promise<void>((resolve) => (conflictSeen = resolve));

    // Holder keeps its write uncommitted until the contender has hit the WriteConflict
    const holder = runner.run(async (session) => {
      await probes.updateOne({ _id }, { $inc: { counter: 1 } }, { session });
      firstWriteDone();
      await conflict;
    });
    await firstWrite;
    const contender = runner.run(async (session) => {
      attempts++;
      try {
        await probes.updateOne({ _id }, { $inc: { counter: 1 } }, { session });
      } catch (error) {
        conflictSeen();
        throw error;
      }
    });

    await Promise.all([holder, contender]);
    expect(attempts).toBeGreaterThan(1); // the first attempt hit WriteConflict and was retried
    expect((await probes.findById(_id).lean())?.counter).toBe(2);
  });

  it('stops after the attempt limit with TransactionRetriesExhaustedError', async () => {
    const { _id } = await probes.create({ operatorId, code: 'locked-row' });
    let release!: () => void;
    let firstWriteDone!: () => void;
    const firstWrite = new Promise<void>((resolve) => (firstWriteDone = resolve));

    const holder = runner.run(async (session) => {
      await probes.updateOne({ _id }, { $set: { counter: 1 } }, { session });
      firstWriteDone();
      await new Promise<void>((resolve) => (release = resolve));
    });
    await firstWrite;

    const contender = runner.run(
      (session) => probes.updateOne({ _id }, { $set: { counter: 99 } }, { session }),
      { maxAttempts: 2 },
    );
    await expect(contender).rejects.toBeInstanceOf(TransactionRetriesExhaustedError);
    await expect(contender).rejects.toMatchObject({ attempts: 2, cause: { code: 112 } });

    release();
    await holder;
    expect((await probes.findById(_id).lean())?.counter).toBe(1);
  });
});

describe('Index bootstrap (e2e, real MongoDB)', () => {
  let app: INestApplication;
  let connection: Connection;

  beforeAll(async () => {
    app = await createDatabaseTestApplication();
    connection = app.get<Connection>(getConnectionToken());
  });

  afterAll(async () => {
    await connection?.dropDatabase();
    await app?.close();
  });

  it('created the declared indexes during application start-up', async () => {
    const indexes = (await connection.db!.collection(SCOPE_PROBE_COLLECTION).indexes()) as Array<{
      name?: string;
      key: Record<string, number>;
      unique?: boolean;
    }>;
    const byName = new Map(indexes.map((index) => [index.name ?? '', index]));
    expect(byName.get('operatorId_1_createdAt_-1')?.key).toEqual({ operatorId: 1, createdAt: -1 });
    expect(byName.get('code_1')).toMatchObject({ key: { code: 1 }, unique: true });
  });

  it('refuses to proceed when existing duplicates block a unique index', async () => {
    const collectionName = 'test_duplicate_probes';
    await connection.db!.collection(collectionName).insertMany([{ ref: 'A1' }, { ref: 'A1' }]);
    const schema = new Schema({ ref: String }, { collection: collectionName });
    schema.index({ ref: 1 }, { unique: true });
    connection.model('DuplicateProbe', schema);

    try {
      await expect(app.get(IndexBootstrapService).ensureIndexes()).rejects.toThrow(
        /Index creation failed for model DuplicateProbe: .*E11000/,
      );
    } finally {
      connection.deleteModel('DuplicateProbe');
    }
  });
});
