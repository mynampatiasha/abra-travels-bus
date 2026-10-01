import { Module } from '@nestjs/common';
import { RateLimiterService } from './rate-limiter.service';

/** Redis-backed counters. Needs the global RedisModule in the root module. */
@Module({ providers: [RateLimiterService], exports: [RateLimiterService] })
export class RateLimitModule {}
