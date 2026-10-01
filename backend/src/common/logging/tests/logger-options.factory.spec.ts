import { type AppConfigService } from '../../../config/app-config.service';
import { createLoggerOptions, prettyPrinterInstalled } from '../logger-options.factory';

function config(nodeEnvironment: string): AppConfigService {
  const values: Record<string, unknown> = { NODE_ENV: nodeEnvironment, LOG_LEVEL: 'info' };
  return { get: (key: string) => values[key] } as unknown as AppConfigService;
}

function transportOf(options: ReturnType<typeof createLoggerOptions>): unknown {
  return (options.pinoHttp as { transport?: unknown }).transport;
}

describe('createLoggerOptions', () => {
  it('uses the pretty printer in development when it is installed', () => {
    expect(transportOf(createLoggerOptions(config('development'), true))).toMatchObject({
      target: 'pino-pretty',
    });
  });

  it('falls back to JSON in development when pino-pretty is not installed (production image)', () => {
    expect(transportOf(createLoggerOptions(config('development'), false))).toBeUndefined();
  });

  it('always logs JSON outside development', () => {
    expect(transportOf(createLoggerOptions(config('production'), true))).toBeUndefined();
    expect(transportOf(createLoggerOptions(config('test'), true))).toBeUndefined();
  });
});

describe('prettyPrinterInstalled', () => {
  it('is true when the module resolves and false when it does not', () => {
    expect(prettyPrinterInstalled(() => '/node_modules/pino-pretty/index.js')).toBe(true);
    expect(
      prettyPrinterInstalled(() => {
        throw new Error('Cannot find module');
      }),
    ).toBe(false);
  });

  it('finds the devDependency in this checkout', () => {
    expect(prettyPrinterInstalled()).toBe(true);
  });
});
