/**
 * API e2e tests: *.e2e-spec.ts. They boot the real application against the local
 * Docker MongoDB replica set and Redis (infrastructure/docker-compose.development.yml).
 */
const baseConfig = require('./jest.base.config');

/** @type {import('jest').Config} */
module.exports = {
  ...baseConfig,
  testRegex: '.*\.e2e-spec\.ts$',
  testTimeout: 30000,
};
