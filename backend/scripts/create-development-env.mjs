// Creates backend/.env.development from .env.example with freshly generated local secrets.
// Usage (from backend/):  npm run env:create-development
// Never overwrites an existing file. The generated file is ignored by Git.
import { randomBytes } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const backendRoot = join(dirname(fileURLToPath(import.meta.url)), '..');
const target = join(backendRoot, '.env.development');

if (existsSync(target)) {
  process.stderr.write('.env.development already exists; not overwriting it.\n');
  process.exit(1);
}

const generated = {
  JWT_ACCESS_SECRET: randomBytes(64).toString('base64'),
  FIELD_ENCRYPTION_KEY: randomBytes(32).toString('base64'),
  OTP_HASH_SECRET: randomBytes(32).toString('base64'),
};

const content = readFileSync(join(backendRoot, '.env.example'), 'utf8')
  .split(/\r?\n/)
  .map((line) => {
    const key = line.split('=')[0];
    return key in generated && line === `${key}=` ? `${key}=${generated[key]}` : line;
  })
  .join('\n');

writeFileSync(target, content, { flag: 'wx' });
process.stdout.write(
  `Created .env.development with generated local secrets (${Object.keys(generated).join(', ')}).\n` +
    'Provider settings stay on their development adapters.\n',
);
