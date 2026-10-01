import { Controller, Get, Query } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { RequirePermission } from '../../rbac/decorators/require-permission.decorator';
import { type UserDirectoryEntry, UserDirectoryService } from '../services/user-directory.service';
import { USER_STATUSES, USER_TYPES } from '../schemas/user.schema';

const objectId = z.string().regex(/^[0-9a-f]{24}$/i, 'must be a 24-character id');

export class UserDirectoryQueryDto extends createZodDto(
  z.object({
    userType: z.enum(USER_TYPES).optional(),
    status: z.enum(USER_STATUSES).optional(),
    operatorId: objectId.optional(),
    partnerId: objectId.optional(),
    page: z.coerce.number().int().min(1).default(1),
    pageSize: z.coerce.number().int().min(1).max(100).default(20),
  }),
) {}

@ApiTags('users')
@Controller('users')
export class UserDirectoryController {
  constructor(private readonly directory: UserDirectoryService) {}

  @Get()
  @RequirePermission('users.read')
  @ApiOperation({
    summary: 'User directory',
    description:
      "Requires users.read. Users inside the caller's data scope: an operator administrator " +
      "sees only their operator's users, a partner user only their partner's. The filters " +
      '(userType, status, operatorId, partnerId) narrow the result and cannot widen the scope. ' +
      'Never returns credentials.',
  })
  @ApiResponse({ status: 200, description: 'Users (paginated: meta.page, pageSize, total)' })
  list(@Query() query: UserDirectoryQueryDto): Promise<PaginatedResult<UserDirectoryEntry>> {
    return this.directory.list(query);
  }
}
