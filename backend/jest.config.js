/** Unit tests: *.spec.ts in module `tests/` folders. No database or Redis needed. */
const baseConfig = require('./jest.base.config');

/** @type {import('jest').Config} */
module.exports = {
  ...baseConfig,
  testRegex: '.*\.spec\.ts$',
  testPathIgnorePatterns: ['\.e2e-spec\.ts$'],
  collectCoverageFrom: ['src/**/*.ts', '!src/**/tests/**', '!src/main.ts'],
  coverageDirectory: './coverage',
};
