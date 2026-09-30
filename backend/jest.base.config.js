/**
 * Shared Jest settings. NestJS 12 ships as ES modules. On Node >= 24.9 Jest loads them through
 * native require(esm), so tests run as plain CommonJS exactly like the application. Jest's
 * require(esm) path uses node:vm module APIs that Node only exposes with --experimental-vm-modules,
 * which is why the package.json test scripts pass that flag (no other ESM configuration needed).
 */
/** @type {import('jest').Config} */
module.exports = {
  moduleFileExtensions: ['js', 'json', 'ts'],
  rootDir: '.',
  roots: ['<rootDir>/src'],
  transform: { '^.+\.ts$': 'ts-jest' },
  testEnvironment: 'node',
};
