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
        kycStatus: 'APPROVED',
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

  // 3. Test Users
  const usersCol = db.collection('users');
  const adminUserId = new mongoose.Types.ObjectId('660000000000000000000003');
  const opUserId = new mongoose.Types.ObjectId('660000000000000000000004');

  // 3a. Super Admin user
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
        _id: adminUserId,
        createdAt: new Date(),
      },
    },
    { upsert: true }
  );
  const adminUser = await usersCol.findOne({ email: 'admin@abra.test' });

  // 3b. Operator Admin user
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
        _id: opUserId,
        createdAt: new Date(),
      },
    },
    { upsert: true }
  );
  const opUser = await usersCol.findOne({ email: 'operator@kaveri.test' });

  // 4. Operator Company KYC Approval
  const submissionsCol = db.collection('onboarding_submissions');
  await submissionsCol.updateOne(
    { operatorId: opId, subjectType: 'OPERATOR' },
    {
      $set: {
        operatorId: opId,
        subjectType: 'OPERATOR',
        status: 'APPROVED',
        kycRequired: false,
        submitCount: 1,
        submittedAt: new Date(),
        decidedAt: new Date(),
        decidedBy: adminUser._id,
        documents: [],
        history: [
          {
            at: new Date(),
            action: 'APPROVED',
            byUserId: adminUser._id,
            note: 'Company KYC approved for supply test environment',
          },
        ],
        updatedAt: new Date(),
      },
      $setOnInsert: {
        createdAt: new Date(),
      },
    },
    { upsert: true }
  );

  // 5. Bus Type
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
        isActive: true,
        updatedAt: new Date(),
      },
      $setOnInsert: {
        createdAt: new Date(),
      },
    },
    { upsert: true }
  );

  // 6. Cities (3)
  const citiesCol = db.collection('cities');
  const cityDefs = [
    {
      _id: new mongoose.Types.ObjectId('660000000000000000000010'),
      name: 'Bengaluru',
      slug: 'bengaluru',
      state: 'Karnataka',
      countryCode: 'IN',
      location: { type: 'Point', coordinates: [77.5946, 12.9716] },
      isPopular: true,
      sortOrder: 1,
      isActive: true,
    },
    {
      _id: new mongoose.Types.ObjectId('660000000000000000000011'),
      name: 'Hyderabad',
      slug: 'hyderabad',
      state: 'Telangana',
      countryCode: 'IN',
      location: { type: 'Point', coordinates: [78.4867, 17.3850] },
      isPopular: true,
      sortOrder: 2,
      isActive: true,
    },
    {
      _id: new mongoose.Types.ObjectId('660000000000000000000012'),
      name: 'Chennai',
      slug: 'chennai',
      state: 'Tamil Nadu',
      countryCode: 'IN',
      location: { type: 'Point', coordinates: [80.2707, 13.0827] },
      isPopular: true,
      sortOrder: 3,
      isActive: true,
    },
  ];

  for (const c of cityDefs) {
    await citiesCol.updateOne(
      { slug: c.slug },
      {
        $set: {
          name: c.name,
          slug: c.slug,
          state: c.state,
          countryCode: c.countryCode,
          location: c.location,
          isPopular: c.isPopular,
          sortOrder: c.sortOrder,
          isActive: c.isActive,
          updatedAt: new Date(),
        },
        $setOnInsert: {
          _id: c._id,
          createdAt: new Date(),
        },
      },
      { upsert: true }
    );
  }

  const citiesMap = new Map();
  for (const c of cityDefs) {
    const doc = await citiesCol.findOne({ slug: c.slug });
    citiesMap.set(c.slug, doc);
  }

  // 7. Approved Places (2 per city, 6 total)
  const locationsCol = db.collection('locations');
  const placeRequestsCol = db.collection('place_requests');

  const bengaluruDoc = citiesMap.get('bengaluru');
  const hyderabadDoc = citiesMap.get('hyderabad');
  const chennaiDoc = citiesMap.get('chennai');

  const placeDefs = [
    // Bengaluru
    {
      _id: new mongoose.Types.ObjectId('660000000000000000000021'),
      cityId: bengaluruDoc._id,
      cityName: bengaluruDoc.name,
      name: 'Majestic Bus Stand',
      address: 'Gubbi Thotadappa Rd, Kempegowda, Bengaluru',
      landmark: 'Opposite KSR Bengaluru Railway Station',
      location: { type: 'Point', coordinates: [77.5726, 12.9778] },
      usedFor: 'BOTH',
      source: 'ADMIN',
      isActive: true,
    },
    {
      _id: new mongoose.Types.ObjectId('660000000000000000000022'),
      cityId: bengaluruDoc._id,
      cityName: bengaluruDoc.name,
      name: 'Silk Board Junction',
      address: 'Hosur Road, Central Silk Board, Bengaluru',
      landmark: 'Near Silk Board Flyover',
      location: { type: 'Point', coordinates: [77.6229, 12.9172] },
      usedFor: 'BOTH',
      source: 'ADMIN',
      isActive: true,
    },
    // Hyderabad
    {
      _id: new mongoose.Types.ObjectId('660000000000000000000023'),
      cityId: hyderabadDoc._id,
      cityName: hyderabadDoc.name,
      name: 'MGBS Bus Stand',
      address: 'Mahatma Gandhi Bus Station, Gowliguda, Hyderabad',
      landmark: 'Central Hyderabad Bus Station',
      location: { type: 'Point', coordinates: [78.4812, 17.3786] },
      usedFor: 'BOTH',
      source: 'ADMIN',
      isActive: true,
    },
    {
      _id: new mongoose.Types.ObjectId('660000000000000000000024'),
      cityId: hyderabadDoc._id,
      cityName: hyderabadDoc.name,
      name: 'Miyapur Metro Pickup',
      address: 'National Highway 65, Miyapur, Hyderabad',
      landmark: 'Metro Station Gate 2',
      location: { type: 'Point', coordinates: [78.3614, 17.4968] },
      usedFor: 'BOTH',
      source: 'ADMIN',
      isActive: true,
    },
    // Chennai
    {
      _id: new mongoose.Types.ObjectId('660000000000000000000025'),
      cityId: chennaiDoc._id,
      cityName: chennaiDoc.name,
      name: 'Koyambedu CMBT',
      address: 'Chennai Mofussil Bus Terminus, Koyambedu, Chennai',
      landmark: 'Near Koyambedu Market',
      location: { type: 'Point', coordinates: [80.2057, 13.0694] },
      usedFor: 'BOTH',
      source: 'ADMIN',
      isActive: true,
    },
    {
      _id: new mongoose.Types.ObjectId('660000000000000000000026'),
      cityId: chennaiDoc._id,
      cityName: chennaiDoc.name,
      name: 'Tambaram Bus Stand',
      address: 'GST Road, East Tambaram, Chennai',
      landmark: 'Opposite Tambaram Railway Station',
      location: { type: 'Point', coordinates: [80.1200, 12.9249] },
      usedFor: 'BOTH',
      source: 'ADMIN',
      isActive: true,
    },
  ];

  for (const p of placeDefs) {
    await locationsCol.updateOne(
      { cityId: p.cityId, name: p.name },
      {
        $set: {
          cityId: p.cityId,
          name: p.name,
          address: p.address,
          landmark: p.landmark,
          location: p.location,
          usedFor: p.usedFor,
          source: p.source,
          isActive: p.isActive,
          status: 'APPROVED',
          updatedAt: new Date(),
        },
        $setOnInsert: {
          _id: p._id,
          createdAt: new Date(),
        },
      },
      { upsert: true }
    );

    const locDoc = await locationsCol.findOne({ cityId: p.cityId, name: p.name });

    await placeRequestsCol.updateOne(
      { cityId: p.cityId, name: p.name },
      {
        $set: {
          operatorId: opId,
          operatorName: 'Kaveri Travels Pvt Ltd',
          cityId: p.cityId,
          cityName: p.cityName,
          name: p.name,
          address: p.address,
          landmark: p.landmark,
          status: 'APPROVED',
          placeId: locDoc._id,
          requestedBy: opUser._id,
          decidedBy: adminUser._id,
          decidedAt: new Date(),
          updatedAt: new Date(),
        },
        $setOnInsert: {
          createdAt: new Date(),
        },
      },
      { upsert: true }
    );
  }

  console.log('Seeded successfully:');
  console.log('  Operator Company: Kaveri Travels Pvt Ltd (_id: 660000000000000000000001, status: ACTIVE, Company KYC: APPROVED)');
  console.log('  Cities (3): Bengaluru, Hyderabad, Chennai');
  console.log('  Approved Places (2 per city, 6 total):');
  console.log('    - Bengaluru: Majestic Bus Stand, Silk Board Junction');
  console.log('    - Hyderabad: MGBS Bus Stand, Miyapur Metro Pickup');
  console.log('    - Chennai: Koyambedu CMBT, Tambaram Bus Stand');
  console.log('  Bus Type: AC Sleeper 36-seater (_id: 660000000000000000000002)');
  console.log('  Admin User: admin@abra.test (Role: SUPER_ADMIN)');
  console.log('  Operator User: operator@kaveri.test (Role: OPERATOR_ADMIN)');
  console.log('  Note: Test passwords are in scripts/seed-supply-test.mjs');

  await mongoose.disconnect();
}

main().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
