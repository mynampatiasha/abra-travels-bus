/* eslint-disable max-lines -- One journey covers a bus's documents, reminders, usual crew and the driver's view. */
import { randomUUID } from 'node:crypto';
import { Types } from 'mongoose';
import {
  type AuthTestContext,
  bearer,
  client,
  createAuthTestApp,
  dataOf,
  type Tokens,
} from '../../authentication/tests/auth-e2e.harness';
import { EventRouter } from '../../notifications/event_router_core.service';
import { seedAndSignIn } from '../../rbac/tests/rbac-e2e.harness';
import {
  buildNetwork,
  catalogueApi,
  clearCatalogue,
  errorMessageOf,
  type Identified,
  type Network,
} from '../../trips/tests/catalogue-e2e.support';
import { runId } from '../../trips/tests/discovery-e2e.fixture';
import { BUS_DOCUMENT_EVENT_RULES } from '../../../workers/bus-document-reminder.worker';
import {
  BusDocumentsClientManageService,
  cleanRemindDays,
  reminderStageOf,
  statusOf,
} from '../bus_documents_client_manage.service';

const API = '/api/v1';
interface Caller {
  tokens: Tokens;
}
interface DocView {
  id: string;
  docType: string;
  docName: string;
  validTill: string;
  daysLeft: number;
  status: string;
  remindDaysBefore: number[];
  files: Array<{ id: string; originalName: string; mimeType: string }>;
}
interface DriverBus {
  id: string;
  registrationNumber: string;
  documentsExpiring: number;
  documentsExpired: number;
}
interface TripView {
  id: string;
  driver?: string;
  conductor?: string;
}

const PDF = Buffer.from('%PDF-1.4\n1 0 obj\n<<>>\nendobj\n');
const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.from('fake-image-data')]);
const day = (offset: number): string => new Date(Date.now() + offset * 86_400_000).toISOString().slice(0, 10);

describe('reminder rules (unit)', () => {
  it('cleans the days the owner chooses', () => {
    expect(cleanRemindDays(undefined)).toEqual([30, 15, 7, 1]);
    expect(cleanRemindDays([5, 20, 5])).toEqual([20, 5]);
    expect(() => cleanRemindDays([])).toThrow();
    expect(() => cleanRemindDays([0])).toThrow();
    expect(() => cleanRemindDays([400])).toThrow();
    expect(() => cleanRemindDays([1, 2, 3, 4, 5, 6, 7])).toThrow();
  });

  it('picks the smallest reminder day the document has reached, then expiry day, then expired', () => {
    expect(reminderStageOf(40, [30, 15, 7, 1])).toBeNull();
    expect(reminderStageOf(30, [30, 15, 7, 1])).toBe('30');
    expect(reminderStageOf(20, [30, 15, 7, 1])).toBe('30');
    expect(reminderStageOf(15, [30, 15, 7, 1])).toBe('15');
    expect(reminderStageOf(3, [30, 15, 7, 1])).toBe('7');
    expect(reminderStageOf(1, [30, 15, 7, 1])).toBe('1');
    expect(reminderStageOf(0, [30, 15, 7, 1])).toBe('DAY0');
    expect(reminderStageOf(-2, [30, 15, 7, 1])).toBe('EXPIRED');
  });

  it('calls a document expiring inside the widest reminder window', () => {
    expect(statusOf(10, [30, 15])).toBe('EXPIRING');
    expect(statusOf(31, [30, 15])).toBe('VALID');
    expect(statusOf(-1, [30, 15])).toBe('EXPIRED');
  });
});

describe('Bus documents e2e (abra_supply_test)', () => {
  let context: AuthTestContext;
  let network: Network;
  let operatorA: Caller;
  let operatorB: Caller;
  let driver: Caller & { id: string };
  let service: BusDocumentsClientManageService;
  let busId: string;
  let driverCrewId: string;
  let conductorCrewId: string;
  let insuranceId: string;
  let firstFileId: string;

  const auth = (caller: Caller) => bearer(caller.tokens);
  const docsOf = async (caller: Caller): Promise<DocView[]> =>
    dataOf<DocView[]>(await client(context).get(`${API}/client/buses/${busId}/documents`).set(...auth(caller)).expect(200));
  const outbox = () =>
    context.connection.collection('outbox_events').find({ type: 'bus.document-expiring', aggregateId: busId }).toArray();

  beforeAll(async () => {
    context = await createAuthTestApp({ MONGODB_URI: 'mongodb://localhost:27017/abra_supply_test?directConnection=true' });
    await clearCatalogue(context);
    service = context.app.get(BusDocumentsClientManageService);
    const superAdmin = await seedAndSignIn(context, { roleKeys: ['SUPER_ADMIN'] });
    network = await buildNetwork(catalogueApi(context, superAdmin), `${runId}bdoc`);
    busId = network.bus.id;
    operatorA = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId: new Types.ObjectId(network.operator.id) });
    const other = await catalogueApi(context, superAdmin).create<Identified>('/operators', {
      companyName: `Operator B ${runId} BusDocs Pvt Ltd`,
      displayName: `Operator B ${runId} BusDocs`,
    });
    await catalogueApi(context, superAdmin)
      .post(`/operators/${other.id}/status`, { status: 'ACTIVE', reason: 'KYC verified' })
      .expect(201);
    operatorB = await seedAndSignIn(context, { roleKeys: ['OPERATOR_ADMIN'], operatorId: new Types.ObjectId(other.id) });

    const phone = (tail: number) => `+9198${String(Date.now()).slice(-7)}${tail}`;
    const driverCrew = await client(context)
      .post(`${API}/client/crew`)
      .set(...auth(operatorA))
      .send({ name: 'Usual Driver', role: 'DRIVER', phone: phone(1) })
      .expect(201);
    driverCrewId = dataOf<{ id: string }>(driverCrew).id;
    const conductorCrew = await client(context)
      .post(`${API}/client/crew`)
      .set(...auth(operatorA))
      .send({ name: 'Usual Conductor', role: 'CONDUCTOR', phone: phone(2) })
      .expect(201);
    conductorCrewId = dataOf<{ id: string }>(conductorCrew).id;

    // The driver's own sign-in, linked to the crew record
    driver = await seedAndSignIn(context, { roleKeys: ['DRIVER'], operatorId: new Types.ObjectId(network.operator.id) });
    await context.connection
      .collection('operator_crew')
      .updateOne({ _id: new Types.ObjectId(driverCrewId) }, { $set: { userId: new Types.ObjectId(driver.id) } });
  }, 180_000);

  afterAll(async () => {
    await context.connection.collection('bus_documents').deleteMany({ busId: new Types.ObjectId(busId) });
    await context.connection.collection('bus_document_reminders').deleteMany({});
    await clearCatalogue(context);
    await context.close();
  }, 60_000);

  it('lists the kinds of document and which are required', async () => {
    const res = await client(context).get(`${API}/client/bus-document-types`).set(...auth(operatorA)).expect(200);
    const types = dataOf<Array<{ key: string; label: string; required: boolean }>>(res);
    expect(types.map((type) => type.key)).toEqual(['RC', 'INSURANCE', 'PERMIT', 'FITNESS', 'POLLUTION', 'ROAD_TAX', 'OTHER']);
    expect(types.filter((type) => type.required).map((type) => type.key)).toEqual(['RC', 'INSURANCE', 'PERMIT', 'FITNESS']);
  });

  it('adds several documents to one bus, each with two files, its own expiry and its own reminder days', async () => {
    const insurance = await client(context)
      .post(`${API}/client/buses/${busId}/documents`)
      .set(...auth(operatorA))
      .field('docType', 'INSURANCE')
      .field('validTill', day(25))
      .field('remindDaysBefore', '30, 10')
      .attach('files', PDF, 'policy.pdf')
      .attach('files', PNG, 'policy-back.png')
      .expect(201);
    const view = dataOf<DocView>(insurance);
    insuranceId = view.id;
    firstFileId = view.files[0]!.id;
    expect(view).toMatchObject({ docType: 'INSURANCE', docName: 'Insurance', validTill: day(25), remindDaysBefore: [30, 10], status: 'EXPIRING' });
    expect(view.daysLeft).toBe(25);
    expect(view.files.map((file) => file.originalName)).toEqual(['policy.pdf', 'policy-back.png']);

    await client(context)
      .post(`${API}/client/buses/${busId}/documents`)
      .set(...auth(operatorA))
      .field('docType', 'OTHER')
      .field('docName', 'Route permit, Tirupati')
      .field('validTill', day(400))
      .attach('files', PDF, 'route.pdf')
      .expect(201);

    const all = await docsOf(operatorA);
    expect(all.map((doc) => doc.docName).sort()).toEqual(['Insurance', 'Route permit, Tirupati']);
    // The default reminder days apply when the owner chose none
    expect(all.find((doc) => doc.docName.startsWith('Route'))?.remindDaysBefore).toEqual([30, 15, 7, 1]);
    expect(all.find((doc) => doc.docName.startsWith('Route'))?.status).toBe('VALID');
  });

  it('refuses a document with no expiry date, a bad file, no name for "Other", or bad reminder days', async () => {
    const post = () => client(context).post(`${API}/client/buses/${busId}/documents`).set(...auth(operatorA));
    const noDate = await post().field('docType', 'RC').attach('files', PDF, 'rc.pdf');
    expect(noDate.status).toBe(400);
    expect(errorMessageOf(noDate)).toMatch(/Valid till/);
    await post().field('docType', 'RC').field('validTill', day(10)).attach('files', Buffer.from('MZ not a document'), 'virus.pdf').expect(415);
    await post().field('docType', 'RC').field('validTill', day(10)).expect(400);
    await post().field('docType', 'OTHER').field('validTill', day(10)).attach('files', PDF, 'x.pdf').expect(400);
    await post().field('docType', 'RC').field('validTill', day(10)).field('remindDaysBefore', '0').attach('files', PDF, 'x.pdf').expect(400);
    await post().field('docType', 'RC').field('validTill', '2027-02-30').attach('files', PDF, 'x.pdf').expect(400);
  });

  it('lets the owner rename any document, change its date and its reminder days', async () => {
    const res = await client(context)
      .patch(`${API}/client/buses/${busId}/documents/${insuranceId}`)
      .set(...auth(operatorA))
      .send({ docName: 'Insurance 2026-27 (New India)', validTill: day(60), remindDaysBefore: [45, 20, 3] })
      .expect(200);
    expect(dataOf<DocView>(res)).toMatchObject({
      docName: 'Insurance 2026-27 (New India)',
      validTill: day(60),
      remindDaysBefore: [45, 20, 3],
      status: 'VALID',
    });
    await client(context).patch(`${API}/client/buses/${busId}/documents/${insuranceId}`).set(...auth(operatorA)).send({ docName: '  ' }).expect(400);
    await client(context).patch(`${API}/client/buses/${busId}/documents/${insuranceId}`).set(...auth(operatorA)).send({}).expect(400);
  });

  it('adds and removes files, keeps at least one, and serves the file back', async () => {
    const added = await client(context)
      .post(`${API}/client/buses/${busId}/documents/${insuranceId}/files`)
      .set(...auth(operatorA))
      .attach('files', PNG, 'page3.png')
      .expect(201);
    expect(dataOf<DocView>(added).files).toHaveLength(3);

    const file = await client(context)
      .get(`${API}/client/buses/${busId}/documents/${insuranceId}/files/${firstFileId}`)
      .set(...auth(operatorA))
      .expect(200);
    expect(file.headers['content-type']).toContain('application/pdf');
    expect(file.headers['x-content-type-options']).toBe('nosniff');

    const removed = await client(context)
      .delete(`${API}/client/buses/${busId}/documents/${insuranceId}/files/${firstFileId}`)
      .set(...auth(operatorA))
      .expect(200);
    expect(dataOf<DocView>(removed).files).toHaveLength(2);
    const [left] = dataOf<DocView>(removed).files;
    const last = await client(context)
      .post(`${API}/client/buses/${busId}/documents`)
      .set(...auth(operatorA))
      .field('docType', 'PERMIT')
      .field('validTill', day(90))
      .attach('files', PDF, 'permit.pdf')
      .expect(201);
    const single = dataOf<DocView>(last);
    const refused = await client(context)
      .delete(`${API}/client/buses/${busId}/documents/${single.id}/files/${single.files[0]!.id}`)
      .set(...auth(operatorA));
    expect(refused.status).toBe(400);
    expect(left).toBeDefined();
  });

  it('keeps one operator out of another operator\'s bus documents', async () => {
    await client(context).get(`${API}/client/buses/${busId}/documents`).set(...auth(operatorB)).expect(404);
    await client(context)
      .patch(`${API}/client/buses/${busId}/documents/${insuranceId}`)
      .set(...auth(operatorB))
      .send({ docName: 'Hijacked' })
      .expect(404);
    await client(context).delete(`${API}/client/buses/${busId}/documents/${insuranceId}`).set(...auth(operatorB)).expect(404);
  });

  it('records who added, changed and removed a document', async () => {
    const temporary = await client(context)
      .post(`${API}/client/buses/${busId}/documents`)
      .set(...auth(operatorA))
      .field('docType', 'POLLUTION')
      .field('validTill', day(120))
      .attach('files', PDF, 'puc.pdf')
      .expect(201);
    const id = dataOf<DocView>(temporary).id;
    await client(context).delete(`${API}/client/buses/${busId}/documents/${id}`).set(...auth(operatorA)).expect(200);
    const audit = await context.connection
      .collection('audit_logs')
      .find({ entityId: new Types.ObjectId(id) })
      .toArray();
    expect(audit.map((entry) => String(entry.action))).toEqual(['bus-document.added', 'bus-document.removed']);
    expect((await docsOf(operatorA)).map((doc) => doc.id)).not.toContain(id);
  });

  it('sets the usual driver and conductor of the bus, and refuses the wrong kind of person', async () => {
    const wrong = await client(context)
      .patch(`${API}/client/buses/${busId}`)
      .set(...auth(operatorA))
      .send({ defaultDriverId: conductorCrewId });
    expect(wrong.status).toBe(400);
    expect(errorMessageOf(wrong)).toMatch(/not a driver/);
    const ok = await client(context)
      .patch(`${API}/client/buses/${busId}`)
      .set(...auth(operatorA))
      .send({ defaultDriverId: driverCrewId, defaultConductorId: conductorCrewId })
      .expect(200);
    expect(dataOf<{ defaultDriverName: string; defaultConductorName: string }>(ok)).toMatchObject({
      defaultDriverName: 'Usual Driver',
      defaultConductorName: 'Usual Conductor',
    });
  });

  it('starts a new trip with the usual driver and conductor of the bus', async () => {
    const res = await client(context)
      .post(`${API}/client/trips`)
      .set(...auth(operatorA))
      .send({ routeId: network.route.id, busId, travelDate: '2099-07-01', departureTime: '21:00', startingFarePaise: 90000 })
      .expect(201);
    expect(dataOf<TripView>(res)).toMatchObject({ driver: 'Usual Driver', conductor: 'Usual Conductor' });
  });

  it('sends one reminder for each stage, to the owner, the staff and the people who run the bus', async () => {
    const soon = await client(context)
      .post(`${API}/client/buses/${busId}/documents`)
      .set(...auth(operatorA))
      .field('docType', 'FITNESS')
      .field('docName', 'Fitness certificate')
      .field('validTill', day(5))
      .field('remindDaysBefore', '20, 5')
      .attach('files', PDF, 'fitness.pdf')
      .expect(201);
    const fitnessId = dataOf<DocView>(soon).id;

    const first = await service.scanExpiries(new Date());
    expect(first.sent).toBeGreaterThanOrEqual(1);
    const events = (await outbox()).filter((event) => (event.payload as { documentName: string }).documentName === 'Fitness certificate');
    expect(events).toHaveLength(1);
    const payload = events[0]!.payload as {
      stage: string;
      daysLeft: number;
      crewUserIds: string[];
      driverName: string;
      conductorName: string;
      busRegistration: string;
    };
    expect(payload).toMatchObject({ stage: '5', daysLeft: 5, driverName: 'Usual Driver', conductorName: 'Usual Conductor' });
    // The driver has an account, so the driver is told in the app
    expect(payload.crewUserIds).toContain(driver.id);

    // The same day again sends nothing more
    await service.scanExpiries(new Date());
    expect((await outbox()).filter((event) => (event.payload as { documentName: string }).documentName === 'Fitness certificate')).toHaveLength(1);

    // A later day reaches the next stage, once
    await service.scanExpiries(new Date(Date.now() + 5 * 86_400_000));
    const later = (await outbox()).filter((event) => (event.payload as { documentName: string }).documentName === 'Fitness certificate');
    expect(later.map((event) => (event.payload as { stage: string }).stage).sort()).toEqual(['5', 'DAY0']);

    // Renewing the document (a new date) starts its reminders again
    await client(context)
      .patch(`${API}/client/buses/${busId}/documents/${fitnessId}`)
      .set(...auth(operatorA))
      .send({ validTill: day(15) })
      .expect(200);
    await service.scanExpiries(new Date());
    const renewed = (await outbox()).filter((event) => (event.payload as { documentName: string }).documentName === 'Fitness certificate');
    expect(renewed.map((event) => (event.payload as { stage: string }).stage).sort()).toEqual(['20', '5', 'DAY0']);
  });

  it('delivers the reminder as a notification to the driver and to the owner', async () => {
    // The worker registers these rules in production; the router then turns the recorded event into notifications
    const router = context.app.get(EventRouter);
    router.addRules(BUS_DOCUMENT_EVENT_RULES);
    const recorded = (await outbox()).find(
      (event) => (event.payload as { documentName: string }).documentName === 'Fitness certificate',
    )!;
    const eventId = randomUUID();
    await router.handle({
      eventId,
      type: 'bus.document-expiring',
      aggregateType: 'bus',
      aggregateId: busId,
      occurredAt: new Date().toISOString(),
      payload: recorded.payload as Record<string, unknown>,
    });

    const notices = await context.connection.collection('notifications').find({ eventId }).toArray();
    const forDriver = notices.filter((notice) => String(notice.userId) === driver.id);
    expect(forDriver).toHaveLength(1);
    expect(forDriver[0]).toMatchObject({ type: 'bus.document-expiring' });
    expect(String(forDriver[0]!.title)).toMatch(/^Bus document/);
    expect(String(forDriver[0]!.body)).toContain('Fitness certificate');
    expect(String(forDriver[0]!.body)).toContain('Please remind your operator');
    // The owner of the company is told too, in other words
    const ownerNotices = notices.filter((notice) => String(notice.userId) !== driver.id);
    expect(ownerNotices.length).toBeGreaterThanOrEqual(1);
    expect(ownerNotices.every((notice) => !String(notice.body).includes('Please remind your operator'))).toBe(true);
    // Nothing shows a database id
    for (const notice of notices) {
      expect(String(notice.body)).not.toMatch(/[0-9a-f]{24}/);
    }
  });

  it('lets the driver of the bus see and download its documents, and nobody else', async () => {
    const buses = dataOf<DriverBus[]>(await client(context).get(`${API}/driver/buses`).set(...auth(driver)).expect(200));
    expect(buses).toHaveLength(1);
    expect(buses[0]).toMatchObject({ id: busId, documentsExpired: 0 });
    expect(buses[0]!.documentsExpiring).toBeGreaterThanOrEqual(1);

    const docs = dataOf<DocView[]>(await client(context).get(`${API}/driver/buses/${busId}/documents`).set(...auth(driver)).expect(200));
    expect(docs.map((doc) => doc.docName)).toContain('Fitness certificate');
    // The reminder settings are the owner's
    expect(docs.every((doc) => doc.remindDaysBefore.length === 0)).toBe(true);
    const withFile = docs.find((doc) => doc.docName.startsWith('Route'))!;
    const file = await client(context)
      .get(`${API}/driver/buses/${busId}/documents/${withFile.id}/files/${withFile.files[0]!.id}`)
      .set(...auth(driver))
      .expect(200);
    expect(file.headers['content-type']).toContain('application/pdf');

    // A driver cannot change anything, and an owner is not a driver
    await client(context).delete(`${API}/client/buses/${busId}/documents/${withFile.id}`).set(...auth(driver)).expect(403);
    await client(context).get(`${API}/driver/buses`).set(...auth(operatorA)).expect(403);
    // A bus that is not theirs is "not found"
    await client(context)
      .get(`${API}/driver/buses/${new Types.ObjectId().toHexString()}/documents`)
      .set(...auth(driver))
      .expect(404);
  });

  it('stops a trip going on sale when a required document ended before it, until it is renewed', async () => {
    const expired = await client(context)
      .post(`${API}/client/buses/${busId}/documents`)
      .set(...auth(operatorA))
      .field('docType', 'RC')
      .field('validTill', day(-3))
      .attach('files', PDF, 'rc.pdf')
      .expect(201);
    const rcId = dataOf<DocView>(expired).id;
    expect(dataOf<DocView>(expired).status).toBe('EXPIRED');

    const draft = await client(context)
      .post(`${API}/client/trips`)
      .set(...auth(operatorA))
      .send({ routeId: network.route.id, busId, travelDate: '2099-07-02', departureTime: '21:00', startingFarePaise: 90000 })
      .expect(201);
    const tripId = dataOf<TripView>(draft).id;
    const blocked = await client(context).post(`${API}/client/trips/${tripId}/publish`).set(...auth(operatorA));
    expect(blocked.status).toBe(400);
    expect(errorMessageOf(blocked)).toMatch(/Registration certificate \(RC\) of bus .* ended on .*Renew it first/);

    // The owner renews it: the trip can go on sale
    await client(context)
      .patch(`${API}/client/buses/${busId}/documents/${rcId}`)
      .set(...auth(operatorA))
      .send({ validTill: '2100-01-01' })
      .expect(200);
    // The other required documents on this bus also end before 2099? They end in 2026/27, so renew them too
    for (const doc of await docsOf(operatorA)) {
      if (['INSURANCE', 'PERMIT', 'FITNESS'].includes(doc.docType)) {
        await client(context)
          .patch(`${API}/client/buses/${busId}/documents/${doc.id}`)
          .set(...auth(operatorA))
          .send({ validTill: '2100-01-01' })
          .expect(200);
      }
    }
    const published = await client(context).post(`${API}/client/trips/${tripId}/publish`).set(...auth(operatorA));
    expect([200, 201]).toContain(published.status);
  });
});
