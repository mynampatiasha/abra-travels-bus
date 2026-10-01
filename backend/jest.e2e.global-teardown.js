/**
 * Runs once after all e2e suites, whatever their order or outcome: drops the disposable e2e
 * database and deletes the test queue keys. Refuses to touch anything that is not a test
 * database / test prefix, so development data can never be removed by a misconfiguration.
 */
const mongoose = require('mongoose');
const { Redis } = require('ioredis');

const TEST_DATABASE_PATTERN = /_test$/;
const TEST_QUEUE_PREFIX_PATTERN = 'abra-test*';

module.exports = async function e2eGlobalTeardown() {
  const mongoUri =
    process.env.MONGODB_URI ?? 'mongodb://localhost:27017/abra_travels_test?directConnection=true';
  const connection = await mongoose
    .createConnection(mongoUri, { serverSelectionTimeoutMS: 5000 })
    .asPromise();
  try {
    if (!TEST_DATABASE_PATTERN.test(connection.name)) {
      throw new Error(`Refusing to drop "${connection.name}": not a test database`);
    }
    await connection.dropDatabase();
  } finally {
    await connection.close();
  }

  const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379', {
    maxRetriesPerRequest: 1,
  });
  redis.on('error', () => undefined);
  try {
    let cursor = '0';
    do {
      const [next, keys] = await redis.scan(
        cursor,
        'MATCH',
        TEST_QUEUE_PREFIX_PATTERN,
        'COUNT',
        500,
      );
      cursor = next;
      if (keys.length > 0) await redis.del(...keys);
    } while (cursor !== '0');
  } finally {
    redis.disconnect();
  }
};
