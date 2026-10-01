import { z } from 'zod';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { AUDIT_ACTIONS } from '../schemas/audit-log.schema';

const objectId = z.string().regex(/^[0-9a-f]{24}$/i, 'must be a 24-character id');

export class AuditLogQueryDto extends createZodDto(
  z.object({
    action: z.enum(AUDIT_ACTIONS).optional(),
    entityId: objectId.optional(),
    actorUserId: objectId.optional(),
    operatorId: objectId.optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20),
  }),
) {}
