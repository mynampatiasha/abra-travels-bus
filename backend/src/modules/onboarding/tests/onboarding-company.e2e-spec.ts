import { Types } from 'mongoose';
import { dataOf, type Tokens } from '../../authentication/tests/auth-e2e.harness';
import { type SubmissionView } from '../services/submission-view.service';
import {
  PDF,
  PNG,
  inDays,
  type Identified,
  createOnboardingWorld,
  type OnboardingWorld,
} from './onboarding-e2e.support';

/** Company onboarding: documents, review, rejection, fix, approval: real application, MongoDB, Redis, a real SMTP server and storage folder. */
describe('Onboarding e2e: company', () => {
  let world: OnboardingWorld;
  let context: OnboardingWorld['context'];
  let superAdmin: OnboardingWorld['superAdmin'];
  let plainAdmin: OnboardingWorld['plainAdmin'];
  let support: OnboardingWorld['support'];
  let regType: OnboardingWorld['regType'];
  let gstType: OnboardingWorld['gstType'];
  let optionalType: OnboardingWorld['optionalType'];
  let rcType: OnboardingWorld['rcType'];
  let call: OnboardingWorld['call'];
  let detail: OnboardingWorld['detail'];
  let uploadFile: OnboardingWorld['uploadFile'];
  let setDocument: OnboardingWorld['setDocument'];
  let review: OnboardingWorld['review'];
  let onboardOwner: OnboardingWorld['onboardOwner'];
  let companySubmissionId: OnboardingWorld['companySubmissionId'];

  beforeAll(async () => {
    world = await createOnboardingWorld();
    ({
      context,
      superAdmin,
      plainAdmin,
      support,
      regType,
      gstType,
      optionalType,
      rcType,
      call,
      detail,
      uploadFile,
      setDocument,
      review,
      onboardOwner,
      companySubmissionId,
    } = world);
  }, 180_000);

  afterAll(() => world.close(), 60_000);

  describe('company onboarding: documents, review, rejection, fix, approval', () => {
    let owner: { tokens: Tokens; operatorId: string; email: string };
    let stranger: { tokens: Tokens; operatorId: string; email: string };
    let id: string;
    let regFile: string;
    let gstFile: string;

    beforeAll(async () => {
      owner = await onboardOwner('Bravo Lines');
      stranger = await onboardOwner('Charlie Lines');
      id = await companySubmissionId(owner.operatorId);
    }, 60_000);

    it('the owner sees only their own file, with what is asked for', async () => {
      const list = await call(owner, 'get', '/onboarding/submissions').expect(200);
      const rows = (
        list.body as { data: Array<{ id: string; subjectType: string; status: string }> }
      ).data;
      expect(rows).toHaveLength(1);
      expect(rows[0]).toMatchObject({ id, subjectType: 'OPERATOR', status: 'DRAFT' });

      const view = await detail(owner, id);
      expect(view.checklist.map((item) => [item.name, item.isRequired, item.state])).toEqual([
        ['REGISTRATION', true, 'MISSING'],
        ['GST', true, 'MISSING'],
        ['PAN', false, 'MISSING'],
      ]);
      expect(view.problems).toEqual(['"REGISTRATION" is missing.', '"GST" is missing.']);
      expect(view.canSubmit).toBe(false);
    });

    it('cannot be sent while a required document is missing', async () => {
      const response = await call(owner, 'post', `/onboarding/submissions/${id}/submit`).expect(
        400,
      );
      expect(JSON.stringify(response.body)).toContain('is missing');
    });

    it('checks the files put into a document', async () => {
      regFile = await uploadFile(owner, regType.id, PDF);
      gstFile = await uploadFile(owner, gstType.id, PNG, 'gst.png');

      // a file uploaded for another document
      await setDocument(owner, id, regType.id, { fileIds: [gstFile] }).expect(400);
      // more files than the document allows (one)
      const second = await uploadFile(owner, regType.id, PDF);
      await setDocument(owner, id, regType.id, { fileIds: [regFile, second] }).expect(400);
      // a document that does not expire has no date
      await setDocument(owner, id, regType.id, {
        fileIds: [regFile],
        expiryDate: inDays(30),
      }).expect(400);
      // a bus document is not asked for on a company file
      await setDocument(owner, id, rcType.id, { fileIds: [regFile] }).expect(404);
      // someone else's file
      const strangerFile = await uploadFile(stranger, regType.id, PDF);
      await setDocument(owner, id, regType.id, { fileIds: [strangerFile] }).expect(400);
      // a file that does not exist
      await setDocument(owner, id, regType.id, {
        fileIds: [new Types.ObjectId().toHexString()],
      }).expect(400);
    });

    it('accepts the documents and then the file can be sent', async () => {
      const afterReg = dataOf<SubmissionView>(
        await setDocument(owner, id, regType.id, { fileIds: [regFile] }).expect(200),
      );
      expect(afterReg.documents[0]?.files[0]).toMatchObject({
        id: regFile,
        mimeType: 'application/pdf',
      });
      const afterGst = dataOf<SubmissionView>(
        await setDocument(owner, id, gstType.id, { fileIds: [gstFile] }).expect(200),
      );
      expect(afterGst.problems).toEqual([]);
      expect(afterGst.canSubmit).toBe(true);
      expect(afterGst.checklist.find((item) => item.name === 'GST')?.state).toBe('PENDING');
    });

    it('a file belongs to one submission only', async () => {
      // the PAN document would take the GST file, but it is in use and was uploaded for GST anyway
      await setDocument(owner, id, optionalType.id, { fileIds: [gstFile] }).expect(400);
    });

    it('the owner cannot review their own documents', async () => {
      await call(owner, 'post', `/onboarding/submissions/${id}/approve`).expect(403);
      await call(owner, 'post', `/onboarding/submissions/${id}/reject`, {}).expect(403);
      await call(owner, 'post', `/onboarding/submissions/${id}/documents/${regType.id}/review`, {
        decision: 'APPROVED',
      }).expect(403);
    });

    it('nothing to review until the owner sends it', async () => {
      await call(superAdmin, 'post', `/onboarding/submissions/${id}/approve`).expect(409);
      await review(id, regType.id, 'APPROVED').expect(409);
    });

    it('sending locks the file and puts it in the review queue', async () => {
      const sent = dataOf<SubmissionView>(
        await call(owner, 'post', `/onboarding/submissions/${id}/submit`).expect(200),
      );
      expect(sent).toMatchObject({ status: 'PENDING', submitCount: 1 });
      expect(sent.history.map((entry) => entry.action)).toEqual(['CREATED', 'SUBMITTED']);

      await setDocument(owner, id, regType.id, { fileIds: [regFile] }).expect(409);
      await call(owner, 'delete', `/onboarding/submissions/${id}/documents/${regType.id}`).expect(
        409,
      );
      await call(owner, 'post', `/onboarding/submissions/${id}/submit`).expect(409);

      const queue = await call(
        superAdmin,
        'get',
        `/onboarding/submissions?status=PENDING&operatorId=${owner.operatorId}`,
      ).expect(200);
      const rows = (queue.body as { data: Array<{ id: string; companyName: string }> }).data;
      expect(rows.map((row) => row.id)).toEqual([id]);
      expect(rows[0]?.companyName).toBe('Bravo Lines');
      await call(support, 'get', '/onboarding/submissions?status=PENDING').expect(403);
    });

    it('a reviewer rejects one document with a reason, and cannot finish with one unreviewed', async () => {
      await review(id, gstType.id, 'REJECTED').expect(400); // reason required
      await review(id, gstType.id, 'REJECTED', 'ok').expect(400); // too short
      await review(id, gstType.id, 'REJECTED', 'The image is blurred, upload a clear scan').expect(
        200,
      );

      await call(superAdmin, 'post', `/onboarding/submissions/${id}/approve`).expect(400);
      const unreviewed = await call(
        superAdmin,
        'post',
        `/onboarding/submissions/${id}/reject`,
        {},
      ).expect(400);
      expect(JSON.stringify(unreviewed.body)).toContain('Review every document first');

      await review(id, regType.id, 'APPROVED').expect(200);
      // still not approvable: one document is rejected
      const approval = await call(
        superAdmin,
        'post',
        `/onboarding/submissions/${id}/approve`,
      ).expect(400);
      expect(JSON.stringify(approval.body)).toContain('is rejected');
    });

    it('sends the file back with the reasons', async () => {
      const rejected = dataOf<SubmissionView>(
        await call(plainAdmin, 'post', `/onboarding/submissions/${id}/reject`, {
          note: 'Please fix the GST certificate',
        }).expect(200),
      );
      expect(rejected).toMatchObject({
        status: 'REJECTED',
        decisionNote: 'Please fix the GST certificate',
      });
      await call(plainAdmin, 'post', `/onboarding/submissions/${id}/reject`, {}).expect(409);
    });

    it('the owner reads what to fix and corrects only the rejected document', async () => {
      const view = await detail(owner, id);
      expect(view.status).toBe('REJECTED');
      expect(view.documents.find((item) => item.name === 'GST')).toMatchObject({
        status: 'REJECTED',
        rejectionReason: 'The image is blurred, upload a clear scan',
      });
      expect(view.documents.find((item) => item.name === 'REGISTRATION')?.status).toBe('APPROVED');
      expect(view.problems.join(' ')).toContain('The image is blurred');
      expect(view.canSubmit).toBe(false);
      await call(owner, 'post', `/onboarding/submissions/${id}/submit`).expect(400);

      // an approved document stays as approved
      await setDocument(owner, id, regType.id, {
        fileIds: [await uploadFile(owner, regType.id, PDF)],
      }).expect(409);

      const fixed = dataOf<SubmissionView>(
        await setDocument(owner, id, gstType.id, {
          fileIds: [await uploadFile(owner, gstType.id, PDF, 'gst-clear.pdf')],
        }).expect(200),
      );
      expect(fixed.documents.find((item) => item.name === 'GST')).toMatchObject({
        status: 'PENDING',
        rejectionReason: null,
      });
      expect(fixed.canSubmit).toBe(true);
    });

    it('sending it again shows only what changed, and clears the old rejection', async () => {
      const again = dataOf<SubmissionView>(
        await call(owner, 'post', `/onboarding/submissions/${id}/submit`).expect(200),
      );
      expect(again).toMatchObject({ status: 'PENDING', submitCount: 2, decisionNote: null });
      expect(again.history.map((entry) => entry.action)).toEqual([
        'CREATED',
        'SUBMITTED',
        'DOCUMENT_REJECTED',
        'DOCUMENT_APPROVED',
        'REJECTED',
        'RESUBMITTED',
      ]);
      // the document that was already approved is not asked about again
      expect(again.documents.find((item) => item.name === 'REGISTRATION')?.status).toBe('APPROVED');
    });

    it('approving makes the company live and tells the owner', async () => {
      await review(id, gstType.id, 'APPROVED').expect(200);
      const approved = dataOf<SubmissionView>(
        await call(superAdmin, 'post', `/onboarding/submissions/${id}/approve`).expect(200),
      );
      expect(approved.status).toBe('APPROVED');
      await call(superAdmin, 'post', `/onboarding/submissions/${id}/approve`).expect(409);

      const operator = await call(owner, 'get', `/catalogue/operators/${owner.operatorId}`).expect(
        200,
      );
      expect(dataOf<{ status: string }>(operator).status).toBe('ACTIVE');

      // nothing can be edited after approval
      await setDocument(owner, id, gstType.id, {
        fileIds: [await uploadFile(owner, gstType.id, PDF)],
      }).expect(409);
    });

    it('records events for the notification engine, with no secrets in them', async () => {
      const events = await context.connection
        .collection('outbox_events')
        .find({ aggregateId: id })
        .sort({ occurredAt: 1 })
        .toArray();
      expect(events.map((event) => String(event.type))).toEqual([
        'onboarding.submitted',
        'onboarding.rejected',
        'onboarding.submitted',
        'onboarding.approved',
      ]);
      expect(events[0]?.payload).toMatchObject({ resubmission: false, subjectType: 'OPERATOR' });
      expect(events[1]?.payload).toMatchObject({
        note: 'Please fix the GST certificate',
        rejectedDocuments: [{ name: 'GST', reason: 'The image is blurred, upload a clear scan' }],
      });
      expect(events[2]?.payload).toMatchObject({ resubmission: true });
    });

    it('is audited', async () => {
      const entries = dataOf<Array<{ action: string; reason: string | null }>>(
        await call(superAdmin, 'get', `/audit-logs?entityId=${id}&pageSize=100`).expect(200),
      );
      expect(entries.map((entry) => entry.action).sort()).toEqual([
        'onboarding.approved',
        'onboarding.rejected',
        'onboarding.submitted',
        'onboarding.submitted',
      ]);
      expect(entries.find((entry) => entry.action === 'onboarding.rejected')?.reason).toBe(
        'Please fix the GST certificate',
      );
    });

    it('another operator cannot see or touch this file, but platform staff can', async () => {
      await call(stranger, 'get', `/onboarding/submissions/${id}`).expect(404);
      await setDocument(stranger, id, regType.id, { fileIds: [regFile] }).expect(404);
      await call(stranger, 'post', `/onboarding/submissions/${id}/submit`).expect(404);
      await call(stranger, 'get', `/files/${regFile}`).expect(404);
      const list = await call(stranger, 'get', '/onboarding/submissions').expect(200);
      expect((list.body as { data: Identified[] }).data.map((row) => row.id)).not.toContain(id);
      await call(superAdmin, 'get', `/onboarding/submissions/${id}`).expect(200);
    });

    it('the review queue can be limited to the days files were sent', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const ids = async (query: string) =>
        (
          (
            await call(
              superAdmin,
              'get',
              `/onboarding/submissions?operatorId=${owner.operatorId}&${query}`,
            ).expect(200)
          ).body as { data: Identified[] }
        ).data.map((row) => row.id);
      expect(await ids(`from=${today}&to=${today}`)).toContain(id);
      expect(await ids('from=2099-01-01')).toEqual([]);
    });
  });
});
