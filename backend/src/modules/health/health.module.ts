import { Module } from '@nestjs/common';
import { HealthController } from './controllers/health.controller';
import { ReadinessCheckService } from './services/readiness-check.service';

@Module({
  controllers: [HealthController],
  providers: [ReadinessCheckService],
})
export class HealthModule {}
