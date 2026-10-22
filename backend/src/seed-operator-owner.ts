import 'reflect-metadata';
import mongoose from 'mongoose';
import { PasswordHasher } from './modules/authentication/services/password-hasher.service';
import { SYSTEM_ROLES } from './modules/rbac/roles/system-roles';

/**
 * Local-only seed script to create or update an operator owner account for testing.
 * Refuses anything other than localhost / 127.0.0.1 and a database containing '_test'.
 *
 * Reads:
 *   - MONGODB_URI (default: mongodb://localhost:27017/abra_staff_test?directConnection=true)
 *   - SEED_OPERATOR_PASSWORD (required)
 *   - SEED_OPERATOR_EMAIL (default: owner@company.com)
 *   - SEED_OPERATOR_NAME (default: Acme Travels)
 */
export function validateLocalTestEnvironment(mongoUri: string): { isLocal: boolean; isTestDb: boolean; dbName: string } {
  const isLocal = mongoUri.includes('localhost') || mongoUri.includes('127.0.0.1');

  let dbName = '';
  try {
    const withoutProtocol = mongoUri.replace(/^mongodb(\+srv)?:\/\//, '');
    const slashIdx = withoutProtocol.indexOf('/');
    if (slashIdx !== -1) {
      const rest = withoutProtocol.slice(slashIdx + 1);
      dbName = rest.split('?')[0] ?? '';
    }
  } catch {
    dbName = '';
  }

  const isTestDb = dbName.toLowerCase().includes('_test');
  return { isLocal, isTestDb, dbName };
}

async function main(): Promise<void> {
  const mongoUri =
    process.env.MONGODB_URI ||
    'mongodb://localhost:27017/abra_staff_test?directConnection=true';

  const { isLocal, isTestDb, dbName } = validateLocalTestEnvironment(mongoUri);

  if (!isLocal || !isTestDb) {
    process.stderr.write(
      `Refusing to run: seed:operator-owner is local-only and requires localhost/127.0.0.1 and a database name containing '_test' (got db "${dbName}", URI: ${mongoUri}).\n`,
    );
    process.exit(1);
  }

  const password = process.env.SEED_OPERATOR_PASSWORD;
  if (!password || password.trim().length < 8) {
    process.stderr.write(
      'Error: SEED_OPERATOR_PASSWORD environment variable is required (min 8 characters).\nExample: $env:SEED_OPERATOR_PASSWORD="YourPassword123!"\n',
    );
    process.exit(1);
  }

  const email = (process.env.SEED_OPERATOR_EMAIL || 'owner@company.com').toLowerCase().trim();
  const operatorName = process.env.SEED_OPERATOR_NAME || 'Acme Travels';

  await mongoose.connect(mongoUri);

  try {
    const db = mongoose.connection.db;
    if (!db) throw new Error('Database connection failed');

    // 1. Ensure OPERATOR_ADMIN role exists
    const rolesColl = db.collection('roles');
    let role = await rolesColl.findOne({ key: 'OPERATOR_ADMIN' });
    if (!role) {
      const def = SYSTEM_ROLES.find((r) => r.key === 'OPERATOR_ADMIN');
      const insertResult = await rolesColl.insertOne({
        key: 'OPERATOR_ADMIN',
        name: def?.name ?? 'Owner',
        description: def?.description ?? 'Full operator portal access',
        permissionKeys: def?.permissionKeys ?? ['*'],
        isSystem: true,
        audience: 'OPERATOR',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      role = { _id: insertResult.insertedId, key: 'OPERATOR_ADMIN' };
    }

    // 2. Ensure active operator exists
    const operatorsColl = db.collection('operators');
    let operator = await operatorsColl.findOne({
      $or: [{ companyName: operatorName }, { status: 'ACTIVE' }],
    });
    if (!operator) {
      const opResult = await operatorsColl.insertOne({
        companyName: operatorName,
        displayName: operatorName,
        status: 'ACTIVE',
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      operator = { _id: opResult.insertedId, companyName: operatorName };
    }

    // 3. Upsert operator owner user
    const usersColl = db.collection('users');
    const hasher = new PasswordHasher();
    const passwordHash = await hasher.hash(password);

    const existingUser = await usersColl.findOne({ email });
    if (existingUser) {
      await usersColl.updateOne(
        { _id: existingUser._id },
        {
          $set: {
            passwordHash,
            operatorId: operator._id,
            userType: 'OPERATOR_STAFF',
            roleIds: [role._id],
            status: 'ACTIVE',
            emailVerifiedAt: new Date(),
            updatedAt: new Date(),
          },
        },
      );
      process.stdout.write(
        `Updated existing operator owner account for ${email} (Operator: ${operator.companyName}).\n`,
      );
    } else {
      await usersColl.insertOne({
        name: 'Company Owner',
        email,
        userType: 'OPERATOR_STAFF',
        operatorId: operator._id,
        roleIds: [role._id],
        dataScope: { type: 'OWN_OPERATOR', operatorIds: [operator._id] },
        status: 'ACTIVE',
        passwordHash,
        permissionVersion: 1,
        mfa: { enabled: false, recoveryCodeHashes: [] },
        preferredLanguage: 'en',
        emailVerifiedAt: new Date(),
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      process.stdout.write(
        `Created operator owner account for ${email} (Operator: ${operator.companyName}).\n`,
      );
    }
  } finally {
    await mongoose.disconnect();
  }
}

// Only invoke if running directly
if (require.main === module) {
  main().catch((err: unknown) => {
    process.stderr.write(
      `Failed to seed operator owner: ${err instanceof Error ? err.message : String(err)}\n`,
    );
    process.exit(1);
  });
}
