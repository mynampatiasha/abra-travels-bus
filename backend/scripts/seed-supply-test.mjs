// Seed local test database (abra_supply_test) with test operator, company and admin
import { argon2, randomBytes } from 'node:crypto';
import { promisify } from 'node:util';
import mongoose from 'mongoose';

const argon2Async = promisify(argon2);

const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/abra_supply_test?directConnection=true';

try {
  const parsed = new URL(uri);
  const host = parsed.hostname;
  const dbName = parsed.pathname.replace(/^\//, '').split('?')[0];
  if ((host !== 'localhost' && host !== '127.0.0.1') || !dbName.endsWith('_test')) {
    console.error(`Refusing to run: MongoDB host must be localhost or 127.0.0.1 and database name must end with _test (got host="${host}", db="${dbName}").`);
    process.exit(1);
  }
} catch {
  console.error('Refusing to run: Invalid MongoDB URI');
  process.exit(1);
}

async function hashPassword(password) {
  const salt = randomBytes(16);
  const hash = await argon2Async('argon2id', {
    message: password,
    nonce: salt,
    memory: 19456,
    passes: 2,
    parallelism: 1,
    tagLength: 32,
  });
  const toPhc = (b) => b.toString('base64').replace(/=+$/, '');
  return `$argon2id$v=19$m=19456,t=2,p=1$${toPhc(salt)}$${toPhc(hash)}`;
}

async function main() {
  console.log(`Connecting to ${uri}...`);
  await mongoose.connect(uri);
  const db = mongoose.connection.db;

  // 1. Roles
  const rolesCol = db.collection('roles');
  let superAdminRole = await rolesCol.findOne({ key: 'SUPER_ADMIN' });
  if (!superAdminRole) {
    const res = await rolesCol.insertOne({
      key: 'SUPER_ADMIN',
      name: 'Super administrator',
      description: 'Full platform access',
      userType: 'STAFF',
      dataScopeType: 'ALL',
      permissionKeys: ['*'],
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    superAdminRole = { _id: res.insertedId };
  }

  let opAdminRole = await rolesCol.findOne({ key: 'OPERATOR_ADMIN' });
  if (!opAdminRole) {
    const res = await rolesCol.insertOne({
      key: 'OPERATOR_ADMIN',
      name: 'Operator administrator',
      description: 'Operator fleet and company management',
      userType: 'OPERATOR_STAFF',
      dataScopeType: 'OWN_OPERATOR',
      permissionKeys: ['buses.*', 'trips.*', 'crew.*', 'fares.*', 'schedules.*'],
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    opAdminRole = { _id: res.insertedId };
  }

  // 2. Company / Operator
  const operatorsCol = db.collection('operators');
  const opId = new mongoose.Types.ObjectId('660000000000000000000001');
  await operatorsCol.updateOne(
    { _id: opId },
    {
      $set: {
        companyName: 'Kaveri Travels Pvt Ltd',
        displayName: 'Kaveri Travels',
        status: 'ACTIVE',
        pan: 'ABCDE1234F',
        gstin: '29ABCDE1234F1Z5',
        contactEmail: 'kaveri@example.com',
        contactPhone: '+919876543210',
        updatedAt: new Date(),
      },
      $setOnInsert: {
        createdAt: new Date(),
      },
    },
    { upsert: true }
  );
  const company = await operatorsCol.findOne({ _id: opId });

  // 3. Bus Type
  const busTypesCol = db.collection('bus_types');
  const busTypeId = new mongoose.Types.ObjectId('660000000000000000000002');
  await busTypesCol.updateOne(
    { _id: busTypeId },
    {
      $set: {
        name: 'AC Sleeper 36-seater',
        code: 'AC_SLEEPER_36',
        seatCapacity: 36,
        layoutType: '2+1 Sleeper',
        status: 'ACTIVE',
        updatedAt: new Date(),
      },
      $setOnInsert: {
        createdAt: new Date(),
      },
    },
    { upsert: true }
  );

  // 4. Test Users
  const usersCol = db.collection('users');

  // 4a. Super Admin user
  const adminPasswordHash = await hashPassword('AbraAdmin2026!');
  await usersCol.updateOne(
    { email: 'admin@abra.test' },
    {
      $set: {
        name: 'Platform Super Admin',
        phone: '+919999900001',
        passwordHash: adminPasswordHash,
        passwordChangedAt: new Date(),
        userType: 'STAFF',
        roleIds: [superAdminRole._id],
        dataScope: { type: 'ALL', operatorIds: [] },
        status: 'ACTIVE',
        permissionVersion: 1,
        updatedAt: new Date(),
      },
      $setOnInsert: {
        createdAt: new Date(),
      },
    },
    { upsert: true }
  );

  // 4b. Operator Admin user
  const opPasswordHash = await hashPassword('AbraOperator2026!');
  await usersCol.updateOne(
    { email: 'operator@kaveri.test' },
    {
      $set: {
        name: 'Kaveri Operator Admin',
        phone: '+919999900002',
        passwordHash: opPasswordHash,
        passwordChangedAt: new Date(),
        userType: 'OPERATOR_STAFF',
        operatorId: company._id,
        roleIds: [opAdminRole._id],
        dataScope: { type: 'OWN_OPERATOR', operatorIds: [company._id] },
        status: 'ACTIVE',
        permissionVersion: 1,
        updatedAt: new Date(),
      },
      $setOnInsert: {
        createdAt: new Date(),
      },
    },
    { upsert: true }
  );

  console.log('Seeded successfully:');
  console.log('  Operator Company: Kaveri Travels Pvt Ltd (_id: 660000000000000000000001, status: ACTIVE)');
  console.log('  Bus Type: AC Sleeper 36-seater (_id: 660000000000000000000002)');
  console.log('  Admin User: admin@abra.test / AbraAdmin2026! (Role: SUPER_ADMIN)');
  console.log('  Operator User: operator@kaveri.test / AbraOperator2026! (Role: OPERATOR_ADMIN)');

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
