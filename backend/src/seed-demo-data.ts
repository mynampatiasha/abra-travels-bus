import 'reflect-metadata';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { NestFactory } from '@nestjs/core';
import { exitOnInvalidEnvironment } from './config/exit-on-invalid-environment';
import { loadEnvironment } from './config/environment-loader';
import { SeedDemoDataModule } from './seed/seed-demo-data.module';
import {
  type DemoData,
  SEED_SETS,
  type SeedSet,
  SeedDemoDataService,
} from './seed/seed-demo-data.service';

/**
 * Loads the demos' sample data into MongoDB (`npm run seed:demo`), for development and demos.
 *
 *   npm run seed:demo                       everything, after asking nothing: it only adds
 *   npm run seed:demo -- --dry-run          counts what would be added and writes nothing
 *   npm run seed:demo -- --only=catalogue   one set: catalogue (cities, places, bus types) or
 *                                           companies (operators and their buses)
 *
 * It refuses to run in production, never changes a record that already exists, and prints how
 * many records it created, found and skipped. Exit code 0: done. Exit code 1: refused or failed.
 */
async function main(): Promise<void> {
  exitOnInvalidEnvironment('seed command');
  if (loadEnvironment().NODE_ENV === 'production') {
    process.stderr.write('The demo seed is for development only and will not run in production.\n');
    process.exit(1);
  }
  const args = process.argv.slice(2);
  const dryRun = args.includes('--dry-run');
  const only = args.find((arg) => arg.startsWith('--only='))?.slice('--only='.length);
  const sets: readonly SeedSet[] = only
    ? only.split(',').map((name) => {
        if (!(SEED_SETS as readonly string[]).includes(name)) {
          throw new Error(`Unknown set "${name}". Choose from: ${SEED_SETS.join(', ')}.`);
        }
        return name as SeedSet;
      })
    : SEED_SETS;

  const data = JSON.parse(
    readFileSync(join(process.cwd(), 'seed', 'demo-data.json'), 'utf8'),
  ) as DemoData;
  const app = await NestFactory.createApplicationContext(SeedDemoDataModule, {
    logger: ['error', 'warn'],
  });
  try {
    const report = await app.get(SeedDemoDataService).run(data, { sets, dryRun });
    process.stdout.write(
      `${dryRun ? 'Dry run: nothing was written.' : 'Seed finished.'} Source: ${data.source}\n`,
    );
    for (const [name, count] of Object.entries(report)) {
      process.stdout.write(
        `  ${name.padEnd(10)} ${dryRun ? 'would create' : 'created'} ${count.created}, already there ${count.existing}, skipped ${count.skipped}\n`,
      );
    }
  } finally {
    await app.close();
  }
}

main().catch((error: unknown) => {
  process.stderr.write(`Seed failed: ${error instanceof Error ? error.message : String(error)}\n`);
  process.exit(1);
});
