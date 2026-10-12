import { Body, Controller, Get, HttpCode, Param, Post, Query } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../../common/decorators/current-actor.decorator';
import { type PaginatedResult } from '../../../common/interceptors/response-envelope.interceptor';
import { ZodApiBody } from '../../../common/openapi/zod-api-body';
import { activeFlag, objectIdString, pagingShape } from '../../../common/pipes/list-query';
import { createZodDto } from '../../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../../common/request-context/request-actor';
import { PUSH_PLATFORMS } from '../schemas/notification.schema';
import { type NotificationView, NotificationsService } from '../services/notifications.service';

class NotificationListQueryDto extends createZodDto(
  z.object({ unread: activeFlag, ...pagingShape }),
) {}

class NotificationIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}

class RegisterDeviceDto extends createZodDto(
  z.object({
    /** The token the Firebase SDK gives the browser or phone. */
    token: z.string().min(20).max(4096),
    platform: z.enum(PUSH_PLATFORMS),
  }),
) {}

class RemoveDeviceDto extends createZodDto(z.object({ token: z.string().min(20).max(4096) })) {}

/** The signed-in person's own notifications. No permission key: the person comes from the token. */
@ApiTags('notifications')
@Controller('notifications')
@AuthenticatedOnly()
export class NotificationsController {
  constructor(private readonly notifications: NotificationsService) {}

  @Get()
  @ApiOperation({
    summary: 'My notifications',
    description: 'Newest first. `unread=true` lists only the unread. Paginated.',
  })
  list(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Query() query: NotificationListQueryDto,
  ): Promise<PaginatedResult<NotificationView>> {
    return this.notifications.list(actor, {
      unreadOnly: query.unread === true,
      page: query.page,
      pageSize: query.pageSize,
    });
  }

  @Get('unread-count')
  @ApiOperation({ summary: 'How many notifications I have not read' })
  unreadCount(@CurrentActor() actor: AuthenticatedUserActor): Promise<{ count: number }> {
    return this.notifications.unreadCount(actor);
  }

  @Post('read-all')
  @HttpCode(200)
  @ApiOperation({ summary: 'Mark all my notifications as read' })
  readAll(@CurrentActor() actor: AuthenticatedUserActor): Promise<{ count: number }> {
    return this.notifications.markAllRead(actor);
  }

  @Post('devices')
  @HttpCode(200)
  @ZodApiBody(RegisterDeviceDto)
  @ApiOperation({
    summary: 'Register this browser or phone for push',
    description:
      'Send the Firebase token after the person allowed notifications. Safe to repeat; the token ' +
      'moves to whoever signed in last.',
  })
  async registerDevice(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: RegisterDeviceDto,
  ): Promise<{ registered: true }> {
    await this.notifications.registerDevice(actor, body.token, body.platform);
    return { registered: true };
  }

  @Post('devices/remove')
  @HttpCode(200)
  @ZodApiBody(RemoveDeviceDto)
  @ApiOperation({
    summary: 'Stop push on this browser or phone',
    description: 'Call at sign-out so the next person on the same computer is not notified.',
  })
  async removeDevice(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Body() body: RemoveDeviceDto,
  ): Promise<{ removed: true }> {
    await this.notifications.removeDevice(actor, body.token);
    return { removed: true };
  }

  @Post(':id/read')
  @HttpCode(200)
  @ApiOperation({ summary: 'Mark one notification as read; returns the unread count' })
  read(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: NotificationIdParamDto,
  ): Promise<{ count: number }> {
    return this.notifications.markRead(actor, params.id);
  }
}
