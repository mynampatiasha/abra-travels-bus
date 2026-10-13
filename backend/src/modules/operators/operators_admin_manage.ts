import { exportController } from '../catalogue-shared/catalogue_export_manage';
import {
  type ExportKind,
  readable,
  timeOf,
} from '../catalogue-shared/catalogue_export_manage.service';
import { OperatorListQueryDto } from './dto/operator.dto';
import { type OperatorView, OperatorsService } from './services/operators.service';

/** The operators list as a file. */
export const OPERATORS_EXPORT_KIND: ExportKind<OperatorView> = {
  key: 'operators',
  columns: [
    { header: 'ID', value: (operator) => operator.id },
    { header: 'Operator', value: (operator) => operator.companyName },
    { header: 'Display name', value: (operator) => operator.displayName },
    { header: 'Status', value: (operator) => readable(operator.status) },
    { header: 'Updated', value: (operator) => timeOf(operator.updatedAt) },
  ],
};

/** `GET catalogue/operators/export`. Register it before the module's other controllers. */
export const OperatorsExportController = exportController({
  base: 'catalogue/operators',
  permission: 'operators.export',
  kind: OPERATORS_EXPORT_KIND,
  service: OperatorsService,
  query: OperatorListQueryDto,
  title: 'operators',
  load: (service, query) => service.list(query as never),
});
