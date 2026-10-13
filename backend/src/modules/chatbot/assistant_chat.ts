import { Body, Controller, Get, HttpCode, Module, Param, Post, Req } from '@nestjs/common';
import { MongooseModule } from '@nestjs/mongoose';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { type Request } from 'express';
import { z } from 'zod';
import { AuthenticatedOnly } from '../../common/decorators/authenticated-only.decorator';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { clientRequestInfo } from '../../common/http/client-request-info';
import { ZodApiBody } from '../../common/openapi/zod-api-body';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { RateLimitModule } from '../../common/rate-limit/rate-limit.module';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { AuthenticationModule } from '../authentication/authentication.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { RbacModule } from '../rbac/rbac.module';
import { SystemSettingsModule } from '../system-settings/system-settings.module';
import { UsersModule } from '../users/users.module';
import {
  ASSISTANT_ACTION_MODEL,
  ASSISTANT_TURN_MODEL,
  type ActionStatus,
  AssistantBuiltinTools,
  AssistantChatService,
  AssistantToolRegistry,
  type ChatResult,
  GroqChatClient,
  LANGUAGES,
  assistantActionSchema,
  assistantTurnSchema,
} from './assistant_chat.service';

// ===== 1. REQUEST TYPES =============================================================
// The schemas of the data live in assistant_chat.service.ts (`assistant_turns`, `assistant_actions`).

export class ChatDto extends createZodDto(
  z.object({
    /** The conversation so far, oldest first; the last message must be the person's. */
    messages: z
      .array(
        z.object({
          role: z.enum(['user', 'assistant']),
          content: z.string().trim().min(1).max(2000),
        }),
      )
      .min(1)
      .max(20)
      .refine(
        (messages) => messages.at(-1)?.role === 'user',
        'the last message must be from the person',
      ),
    /** The language of the app; the assistant answers in it. */
    language: z.enum(Object.keys(LANGUAGES) as [string, ...string[]]).default('en'),
  }),
) {}

export class ActionIdParamDto extends createZodDto(z.object({ id: objectIdString })) {}
export class TurnIdParamDto extends createZodDto(z.object({ turnId: objectIdString })) {}
export class FeedbackDto extends createZodDto(z.object({ value: z.enum(['UP', 'DOWN']) })) {}

// ===== 2. CONTROLLER ================================================================

/**
 * The assistant for every app (admin, operator, customer, driver). No permission key: it works
 * for the signed-in person and can only use the tools their own role allows. It answers from
 * those tools, never from other people's data, and cannot change anything without the person's
 * confirmation.
 */
@ApiTags('assistant')
@Controller('assistant')
@AuthenticatedOnly()
export class AssistantChatController {
  constructor(private readonly assistant: AssistantChatService) {}

  // access: signed-in person | audit: none (a turn is logged without its text) | rate limit: 20 a minute
  @Get('status')
  @ApiOperation({
    summary: 'Is the assistant available?',
    description: 'Lets an app show or hide the assistant: it is off, or not set up, or ready.',
  })
  status(
    @CurrentActor() actor: AuthenticatedUserActor,
  ): Promise<{ available: boolean; provider: string }> {
    return this.assistant.status(actor);
  }

  // access: signed-in person | audit: none | rate limit: 20 a minute
  @Post('chat')
  @HttpCode(200)
  @ZodApiBody(ChatDto)
  @ApiOperation({
    summary: 'Ask the assistant',
    description:
      'Send the conversation so far (the last message is the new question) and the app language. ' +
      'Returns the answer, the changes it proposes (each waits for confirm or decline) and a ' +
      'turn id for thumbs up or down. 20 questions a minute per person.',
  })
  @ApiResponse({ status: 429, description: 'RATE_LIMITED (details.retryAfterSeconds)' })
  @ApiResponse({
    status: 503,
    description: 'SERVICE_UNAVAILABLE: switched off, not set up, or the AI service is busy',
  })
  chat(@CurrentActor() actor: AuthenticatedUserActor, @Body() body: ChatDto): Promise<ChatResult> {
    return this.assistant.chat(actor, body);
  }

  // access: the person who was offered the change | audit: assistant.action.confirmed
  @Post('actions/:id/confirm')
  @HttpCode(200)
  @ApiOperation({
    summary: 'Confirm a change the assistant proposed',
    description:
      'Checks again that the person may still do it, makes the change and writes an audit entry. ' +
      'A change that was proposed to someone else, or has expired (15 minutes), answers 404.',
  })
  confirm(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ActionIdParamDto,
    @Req() request: Request,
  ): Promise<{ status: ActionStatus; message: string }> {
    return this.assistant.confirm(actor, params.id, clientRequestInfo(request));
  }

  // access: the person who was offered the change | audit: assistant.action.declined
  @Post('actions/:id/decline')
  @HttpCode(200)
  @ApiOperation({ summary: 'Decline a change the assistant proposed' })
  decline(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: ActionIdParamDto,
    @Req() request: Request,
  ): Promise<{ status: ActionStatus }> {
    return this.assistant.decline(actor, params.id, clientRequestInfo(request));
  }

  // access: the person who got the answer | audit: none
  @Post('messages/:turnId/feedback')
  @HttpCode(200)
  @ZodApiBody(FeedbackDto)
  @ApiOperation({ summary: 'Thumbs up or down on an answer' })
  feedback(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: TurnIdParamDto,
    @Body() body: FeedbackDto,
  ): Promise<{ saved: true }> {
    return this.assistant.feedback(actor, params.turnId, body.value);
  }
}

// ===== 3. MODULE ====================================================================

/**
 * `chatbot`: the assistant. Other modules add tools by injecting `AssistantToolRegistry` and
 * calling `register` when they start (for example bookings for customers, trips for operators).
 */
@Module({
  imports: [
    MongooseModule.forFeature([
      { name: ASSISTANT_TURN_MODEL, schema: assistantTurnSchema },
      { name: ASSISTANT_ACTION_MODEL, schema: assistantActionSchema },
    ]),
    SystemSettingsModule,
    RbacModule,
    UsersModule,
    NotificationsModule,
    RateLimitModule,
    AuthenticationModule,
  ],
  controllers: [AssistantChatController],
  providers: [AssistantToolRegistry, AssistantBuiltinTools, GroqChatClient, AssistantChatService],
  exports: [AssistantToolRegistry],
})
export class ChatbotModule {}
