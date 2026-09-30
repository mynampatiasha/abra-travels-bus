import { Logger } from '@nestjs/common';
import { type Connection } from 'mongoose';
import { DatabaseStartupService } from '../database-startup.service';
import { IndexBootstrapService } from '../index-bootstrap.service';
import { type MongoReplicaSetVerifier } from '../mongo-replica-set.verifier';

interface FakeModel {
  modelName: string;
  createIndexes: jest.Mock<Promise<void>, []>;
  diffIndexes: jest.Mock<Promise<{ toDrop: string[]; toCreate: unknown[] }>, []>;
}

function fakeModel(name: string, toDrop: string[] = [], createError?: Error): FakeModel {
  return {
    modelName: name,
    createIndexes: jest.fn(() => (createError ? Promise.reject(createError) : Promise.resolve())),
    diffIndexes: jest.fn(() => Promise.resolve({ toDrop, toCreate: [] })),
  };
}

function serviceFor(...models: FakeModel[]): IndexBootstrapService {
  const connection = {
    models: Object.fromEntries(models.map((model) => [model.modelName, model])),
  } as unknown as Connection;
  return new IndexBootstrapService(connection);
}

describe('IndexBootstrapService', () => {
  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  it('creates indexes for every registered model', async () => {
    const trips = fakeModel('Trip');
    const seats = fakeModel('TripSeatInventory');
    const report = await serviceFor(trips, seats).ensureIndexes();

    expect(trips.createIndexes).toHaveBeenCalledTimes(1);
    expect(seats.createIndexes).toHaveBeenCalledTimes(1);
    expect(report.models).toEqual(['Trip', 'TripSeatInventory']);
  });

  it('succeeds with no registered models (no business schemas exist yet)', async () => {
    await expect(serviceFor().ensureIndexes()).resolves.toEqual({
      models: [],
      undeclaredIndexes: {},
    });
  });

  it('reports undeclared indexes and never drops them', async () => {
    const model = fakeModel('Booking', ['legacy_index_1']);
    const report = await serviceFor(model).ensureIndexes();

    expect(report.undeclaredIndexes).toEqual({ Booking: ['legacy_index_1'] });
    expect(model).not.toHaveProperty('syncIndexes');
  });

  it('fails start-up, naming the model, when an index cannot be built', async () => {
    const duplicateKey = new Error('E11000 duplicate key error');
    const failing = fakeModel('BookingSeat', [], duplicateKey);

    await expect(serviceFor(failing).ensureIndexes()).rejects.toThrow(
      'Index creation failed for model BookingSeat: E11000 duplicate key error',
    );
  });
});

describe('DatabaseStartupService', () => {
  it('verifies the replica set before building indexes', async () => {
    const calls: string[] = [];
    const verifier = { verify: jest.fn(() => (calls.push('verify'), Promise.resolve())) };
    const indexes = {
      ensureIndexes: jest.fn(() => (calls.push('indexes'), Promise.resolve())),
    };
    const service = new DatabaseStartupService(
      verifier as unknown as MongoReplicaSetVerifier,
      indexes as unknown as IndexBootstrapService,
    );

    await service.onApplicationBootstrap();
    expect(calls).toEqual(['verify', 'indexes']);
  });

  it('does not build indexes when the replica-set check fails', async () => {
    const verifier = { verify: jest.fn(() => Promise.reject(new Error('not a replica set'))) };
    const indexes = { ensureIndexes: jest.fn() };
    const service = new DatabaseStartupService(
      verifier as unknown as MongoReplicaSetVerifier,
      indexes as unknown as IndexBootstrapService,
    );

    await expect(service.onApplicationBootstrap()).rejects.toThrow('not a replica set');
    expect(indexes.ensureIndexes).not.toHaveBeenCalled();
  });
});
