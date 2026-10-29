import { Controller, HttpCode, Param, Post } from '@nestjs/common';
import { ApiOperation, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { CurrentActor } from '../../common/decorators/current-actor.decorator';
import { objectIdString } from '../../common/pipes/list-query';
import { createZodDto } from '../../common/pipes/zod-dto.factory';
import { type AuthenticatedUserActor } from '../../common/request-context/request-actor';
import { RequirePermission } from '../rbac/decorators/require-permission.decorator';
import {
  type CrewLoginCredentials,
  CrewLoginClientManageService,
  type CrewLoginState,
} from './crew_login_client_manage.service';

class CrewLoginParamDto extends createZodDto(z.object({ id: objectIdString })) {}

/** The driver app login of one person: create it, reset its password, switch it off or on. */
@ApiTags('Client Crew Login')
@Controller('client/crew')
export class CrewLoginClientController {
  constructor(private readonly service: CrewLoginClientManageService) {}

  @Post(':id/login')
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Create the driver app login of a driver or conductor' })
  create(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewLoginParamDto,
  ): Promise<CrewLoginCredentials> {
    return this.service.create(actor, params.id);
  }

  @Post(':id/login/reset-password')
  @HttpCode(200)
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Give the person a new temporary password' })
  resetPassword(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewLoginParamDto,
  ): Promise<CrewLoginCredentials> {
    return this.service.resetPassword(actor, params.id);
  }

  @Post(':id/login/disable')
  @HttpCode(200)
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Switch the driver app login off and sign the person out' })
  disable(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewLoginParamDto,
  ): Promise<{ state: CrewLoginState }> {
    return this.service.setActive(actor, params.id, false);
  }

  @Post(':id/login/enable')
  @HttpCode(200)
  @RequirePermission('buses.update')
  @ApiOperation({ summary: 'Switch the driver app login on again' })
  enable(
    @CurrentActor() actor: AuthenticatedUserActor,
    @Param() params: CrewLoginParamDto,
  ): Promise<{ state: CrewLoginState }> {
    return this.service.setActive(actor, params.id, true);
  }
}
