import { z } from 'zod';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { DATA_SCOPE_TYPES } from '../../users/schemas/user.schema';
import { PERMISSION_KEY_PATTERN } from '../permissions/permission-definition';
import { OVERRIDE_EFFECTS } from '../schemas/permission-override.schema';

const objectId = z.string().regex(/^[0-9a-f]{24}$/i, 'must be a 24-character id');
const reason = z.string().trim().min(3).max(300);

export class UserIdParamDto extends createZodDto(z.object({ userId: objectId })) {}

export class UserPermissionParamDto extends createZodDto(
  z.object({
    userId: objectId,
    permissionKey: z.string().max(80).regex(PERMISSION_KEY_PATTERN, 'must be a permission key'),
  }),
) {}

export class AssignRolesDto extends createZodDto(
  z.object({
    /** Role keys such as `BOOKING_STAFF`. An empty list removes every role. */
    roleKeys: z.array(z.string().regex(/^[A-Z][A-Z_]{1,63}$/, 'must be a role key')).max(5),
    reason: reason.optional(),
  }),
) {}

export class SetPermissionOverrideDto extends createZodDto(
  z.object({ effect: z.enum(OVERRIDE_EFFECTS), reason }),
) {}

export class RemovePermissionOverrideDto extends createZodDto(
  z.object({ reason: reason.optional() }),
) {}

export class ChangeDataScopeDto extends createZodDto(
  z.object({
    type: z.enum(DATA_SCOPE_TYPES),
    operatorIds: z.array(objectId).max(200).default([]),
    reason,
  }),
) {}
