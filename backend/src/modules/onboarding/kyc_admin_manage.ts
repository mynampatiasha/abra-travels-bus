import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { SubmissionListQueryDto } from './dto/onboarding.dto';
import { type SubmissionSummaryView } from './services/submission-view.service';
import { SubmissionsService } from './services/submissions.service';

/** The KYC reviews list as a file. */
export const SUBMISSIONS_EXPORT_KIND: ExportKind<SubmissionSummaryView> = {
  key: 'kyc-reviews',
  columns: [
    { header: 'ID', value: (submission) => submission.id },
    { header: 'Operator', value: (submission) => submission.companyName },
    {
      header: 'Type',
      value: (submission) => (submission.subjectType === 'BUS' ? 'Bus' : 'Company'),
    },
    { header: 'Bus', value: (submission) => submission.busRegistrationNumber },
    { header: 'Status', value: (submission) => readable(submission.status) },
    { header: 'Times sent', value: (submission) => submission.submitCount },
    { header: 'Sent on', value: (submission) => timeOf(submission.submittedAt) },
    { header: 'Decided on', value: (submission) => timeOf(submission.decidedAt) },
  ],
};

/** `GET onboarding/submissions/export`. Register it before the module's other controllers. */
export const SubmissionsExportController = exportController({
  base: 'onboarding/submissions',
  permission: 'documents.export',
  kind: SUBMISSIONS_EXPORT_KIND,
  service: SubmissionsService,
  query: SubmissionListQueryDto,
  title: 'KYC reviews',
  load: (service, query) => service.list(query as never),
});
