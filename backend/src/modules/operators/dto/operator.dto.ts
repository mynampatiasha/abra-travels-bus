import { z } from 'zod';
import { changeReason, pagingShape } from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { OPERATOR_STATUSES } from '../schemas/operator.schema';

const companyName = z.string().trim().min(2).max(160);
const displayName = z.string().trim().min(2).max(80);

export class CreateOperatorDto extends createZodDto(
  z.object({ companyName, displayName: displayName.optional() }),
) {}

export class UpdateOperatorDto extends createZodDto(
  z.object({ companyName: companyName.optional(), displayName: displayName.nullable().optional() }),
) {}

export class OperatorListQueryDto extends createZodDto(
  z.object({ status: z.enum(OPERATOR_STATUSES).optional(), ...pagingShape }),
) {}

export class ChangeOperatorStatusDto extends createZodDto(
  z.object({ status: z.enum(['ACTIVE', 'REJECTED', 'SUSPENDED']), reason: changeReason }),
) {}
