import { Types } from 'mongoose';
import { bearer, client, dataOf, type Tokens } from '../../authentication/tests/auth-e2e.harness';
import { type SubmissionView } from '../services/submission-view.service';
import {
  API,
  PDF,
  PNG,
  JPEG,
  inDays,
  createOnboardingWorld,
  type OnboardingWorld,
} from './onboarding-e2e.support';

/** Bus onboarding: real application, MongoDB, Redis, a real SMTP server and storage folder. */
describe('Onboarding e2e: buses', () => {
  let world: OnboardingWorld;
  let context: OnboardingWorld['context'];
  let superAdmin: OnboardingWorld['superAdmin'];
  let plainAdmin: OnboardingWorld['plainAdmin'];
  let regType: OnboardingWorld['regType'];
  let gstType: OnboardingWorld['gstType'];
  let rcType: OnboardingWorld['rcType'];
  let photosType: OnboardingWorld['photosType'];
  let call: OnboardingWorld['call'];
  let detail: OnboardingWorld['detail'];
  let uploadFile: OnboardingWorld['uploadFile'];
  let setDocument: OnboardingWorld['setDocument'];
  let review: OnboardingWorld['review'];
  let onboardOwner: OnboardingWorld['onboardOwner'];
  let companySubmissionId: OnboardingWorld['companySubmissionId'];
  let submitCompany: OnboardingWorld['submitCompany'];
  let createBus: OnboardingWorld['createBus'];

  beforeAll(async () => {
    world = await createOnboardingWorld();
    ({
      context,
      superAdmin,
      plainAdmin,
      regType,
      gstType,
      rcType,
      photosType,
      call,
      detail,
      uploadFile,
      setDocument,
      review,
      onboardOwner,
      companySubmissionId,
      submitCompany,
      createBus,
    } = world);
  }, 180_000);

  afterAll(() => world.close(), 60_000);

  describe('bus onboarding', () => {
    let owner: { tokens: Tokens; operatorId: string; email: string };
    let busId: string;
    let id: string;

    beforeAll(async () => {
      owner = await onboardOwner('Delta Lines');
      await submitCompany(owner);
      const company = await companySubmissionId(owner.operatorId);
      await review(company, regType.id, 'APPROVED').expect(200);
      await review(company, gstType.id, 'APPROVED').expect(200);
      await call(superAdmin, 'post', `/onboarding/submissions/${company}/approve`).expect(200);
      busId = await createBus(owner, 'Delta Express');
    }, 120_000);

    it('a bus an owner adds waits for approval and gets its own file', async () => {
      const bus = await call(owner, 'get', `/catalogue/buses/${busId}`).expect(200);
      expect(dataOf<{ status: string }>(bus).status).toBe('PENDING_APPROVAL');

      const created = dataOf<SubmissionView>(
        await call(owner, 'post', '/onboarding/submissions', { busId }).expect(201),
      );
      id = created.id;
      expect(created).toMatchObject({ subjectType: 'BUS', busId, status: 'DRAFT' });
      expect(created.checklist.map((item) => item.name)).toEqual(['RC', 'PHOTOS']);

      // asking again returns the same file
      const again = dataOf<SubmissionView>(
        await call(owner, 'post', '/onboarding/submissions', { busId }).expect(201),
      );
      expect(again.id).toBe(id);
    });

    it('a bus of another operator does not exist for the caller', async () => {
      const other = await onboardOwner('Echo Lines');
      await call(other, 'post', '/onboarding/submissions', { busId }).expect(404);
      await call(other, 'get', `/onboarding/submissions/${id}`).expect(404);
    });

    it('documents that expire need a date that has not passed', async () => {
      const rc = await uploadFile(owner, rcType.id, PDF, 'rc.pdf');
      await setDocument(owner, id, rcType.id, { fileIds: [rc] }).expect(400);
      await setDocument(owner, id, rcType.id, { fileIds: [rc], expiryDate: '2020-01-01' }).expect(
        400,
      );
      await setDocument(owner, id, rcType.id, { fileIds: [rc], expiryDate: '2027-02-30' }).expect(
        400,
      );
      const done = dataOf<SubmissionView>(
        await setDocument(owner, id, rcType.id, { fileIds: [rc], expiryDate: inDays(200) }).expect(
          200,
        ),
      );
      expect(done.documents[0]?.expiryDate).toBe(inDays(200));
    });

    it('limits the number of photos and only takes images', async () => {
      const photo = () => uploadFile(owner, photosType.id, JPEG, 'bus.jpg');
      const four = [await photo(), await photo(), await photo(), await photo()];
      await setDocument(owner, id, photosType.id, { fileIds: four }).expect(400);
      // a PDF is not accepted for photos (the upload itself is refused)
      await client(context)
        .post(`${API}/files`)
        .set(...bearer(owner.tokens))
        .field('documentTypeId', photosType.id)
        .attach('file', PDF, { filename: 'x.jpg', contentType: 'image/jpeg' })
        .expect(415);
      const done = dataOf<SubmissionView>(
        await setDocument(owner, id, photosType.id, { fileIds: four.slice(0, 3) }).expect(200),
      );
      expect(done.canSubmit).toBe(true);
    });

    it('replacing files frees the old ones', async () => {
      const view = await detail(owner, id);
      const first = view.documents.find((item) => item.name === 'PHOTOS')?.files ?? [];
      expect(first).toHaveLength(3);
      const replacement = await uploadFile(owner, photosType.id, PNG, 'new.png');
      await setDocument(owner, id, photosType.id, { fileIds: [replacement] }).expect(200);
      const freed = await context.connection
        .collection('stored_files')
        .findOne({ _id: new Types.ObjectId(first[0]?.id) });
      expect(freed?.attachedToId).toBeNull();
      const kept = await context.connection
        .collection('stored_files')
        .findOne({ _id: new Types.ObjectId(replacement) });
      expect(String(kept?.attachedToId)).toBe(id);
    });

    it('a document that expired while it waited blocks the approval', async () => {
      await call(owner, 'post', `/onboarding/submissions/${id}/submit`).expect(200);
      await review(id, rcType.id, 'APPROVED').expect(200);
      await review(id, photosType.id, 'APPROVED').expect(200);

      await context.connection
        .collection('onboarding_submissions')
        .updateOne(
          { _id: new Types.ObjectId(id), 'documents.documentTypeKey': { $exists: true } },
          { $set: { 'documents.$[doc].expiryDate': new Date('2020-01-01T00:00:00.000Z') } },
          { arrayFilters: [{ 'doc.documentTypeId': new Types.ObjectId(rcType.id) }] },
        );
      const blocked = await call(
        superAdmin,
        'post',
        `/onboarding/submissions/${id}/approve`,
      ).expect(400);
      expect(JSON.stringify(blocked.body)).toContain('has expired');
      expect(
        dataOf<{ status: string }>(
          await call(owner, 'get', `/catalogue/buses/${busId}`).expect(200),
        ).status,
      ).toBe('PENDING_APPROVAL');

      await context.connection
        .collection('onboarding_submissions')
        .updateOne(
          { _id: new Types.ObjectId(id) },
          { $set: { 'documents.$[doc].expiryDate': new Date(`${inDays(200)}T00:00:00.000Z`) } },
          { arrayFilters: [{ 'doc.documentTypeId': new Types.ObjectId(rcType.id) }] },
        );
    });

    it('approving the bus makes it active, and then it can be put on sale', async () => {
      await call(plainAdmin, 'post', `/onboarding/submissions/${id}/approve`).expect(200);
      const bus = await call(owner, 'get', `/catalogue/buses/${busId}`).expect(200);
      expect(dataOf<{ status: string }>(bus).status).toBe('ACTIVE');
    });

    it('a bus cannot go live before its company is approved', async () => {
      const pendingOwner = await onboardOwner('Foxtrot Lines');
      // Pending clients cannot access bus/account features. Platform staff can
      // prepare a bus, but still cannot approve it before the company.
      const busInput = {
        operatorId: pendingOwner.operatorId,
        registrationNumber: `KA${Date.now()}`,
        name: 'Foxtrot Express',
        busTypeId: world.busTypeId,
        seatCapacity: 30,
      };
      await call(pendingOwner, 'post', '/catalogue/buses', busInput).expect(403);
      const pendingBus = dataOf<{ id: string }>(
        await call(superAdmin, 'post', '/catalogue/buses', busInput).expect(201),
      ).id;
      // Simulate an imported bus that still needs document approval.
      await context.connection
        .collection('buses')
        .updateOne(
          { _id: new Types.ObjectId(pendingBus) },
          { $set: { status: 'PENDING_APPROVAL' } },
        );
      // Bus KYC starts only after the company is approved (Phase 1 step 9)
      const early = await call(pendingOwner, 'post', '/onboarding/submissions', {
        busId: pendingBus,
      }).expect(409);
      expect(JSON.stringify(early.body)).toContain('must be approved');
      // A file made before that rule (or by an import) still cannot be approved early
      const inserted = await context.connection.collection('onboarding_submissions').insertOne({
        operatorId: new Types.ObjectId(pendingOwner.operatorId),
        subjectType: 'BUS',
        busId: new Types.ObjectId(pendingBus),
        status: 'DRAFT',
        documents: [],
        submitCount: 0,
        history: [],
        createdAt: new Date(),
        updatedAt: new Date(),
      });
      const busFile = { id: inserted.insertedId.toHexString() };
      await setDocument(pendingOwner, busFile.id, rcType.id, {
        fileIds: [await uploadFile(pendingOwner, rcType.id, PDF)],
        expiryDate: inDays(90),
      }).expect(200);
      await setDocument(pendingOwner, busFile.id, photosType.id, {
        fileIds: [await uploadFile(pendingOwner, photosType.id, JPEG, 'b.jpg')],
      }).expect(200);
      await call(pendingOwner, 'post', `/onboarding/submissions/${busFile.id}/submit`).expect(200);
      await review(busFile.id, rcType.id, 'APPROVED').expect(200);
      await review(busFile.id, photosType.id, 'APPROVED').expect(200);

      const refused = await call(
        superAdmin,
        'post',
        `/onboarding/submissions/${busFile.id}/approve`,
      ).expect(409);
      expect(JSON.stringify(refused.body)).toContain('Approve the company first');
    });
  });
});
