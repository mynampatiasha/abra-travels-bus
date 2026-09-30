import { Controller, Get } from '@nestjs/common';
import { ApiOperation, ApiResponse, ApiTags } from '@nestjs/swagger';
import { ApiException } from '../../../common/errors/api-exception';
import { ReadinessCheckService, type ReadinessReport } from '../services/readiness-check.service';

/**
 * Load-balancer and orchestrator probes (deployment.md). Served at `/health/*`, outside the
 * `/api/v1` prefix. Public: they expose dependency status only, never configuration.
 */
@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(private readonly readinessCheck: ReadinessCheckService) {}

  @Get('live')
  @ApiOperation({
    summary: 'Liveness probe',
    description: 'Public. The process is running and serving HTTP. Does not touch dependencies.',
  })
  @ApiResponse({ status: 200, description: 'Process is alive' })
  live(): { status: 'ok' } {
    return { status: 'ok' };
  }

  @Get('ready')
  @ApiOperation({
    summary: 'Readiness probe',
    description: 'Public. MongoDB and Redis are reachable. Returns 503 SERVICE_UNAVAILABLE if not.',
  })
  @ApiResponse({ status: 200, description: 'All dependencies are up' })
  @ApiResponse({ status: 503, description: 'At least one dependency is down' })
  async ready(): Promise<ReadinessReport> {
    const report = await this.readinessCheck.check();
    if (!report.ready) {
      throw new ApiException('SERVICE_UNAVAILABLE', 'Service is not ready', {
        checks: report.checks,
      });
    }
    return report;
  }
}
