import { Logger } from '@nestjs/common';
import { type AppConfigService } from '../../config/app-config.service';
import { type OutboxRelayService, type RelayBatchResult } from '../../events/outbox-relay.service';
import { OutboxRelayWorker } from '../outbox-relay.worker';

const EMPTY: RelayBatchResult = { published: 0, retried: 0, failed: 0, leaseLost: 0 };

function workerWith(relayBatch: jest.Mock<Promise<RelayBatchResult>, []>, pollMs = 10) {
  const values: Record<string, number> = { OUTBOX_BATCH_SIZE: 5, OUTBOX_POLL_INTERVAL_MS: pollMs };
  const relay = { relayBatch, relayId: 'test-relay' } as unknown as OutboxRelayService;
  const config = { get: (key: string) => values[key] } as unknown as AppConfigService;
  return new OutboxRelayWorker(relay, config);
}

const waitFor = async (condition: () => boolean, timeoutMs = 2_000): Promise<void> => {
  const started = Date.now();
  while (!condition()) {
    if (Date.now() - started > timeoutMs) throw new Error('condition not met');
    await new Promise((resolve) => setTimeout(resolve, 5));
  }
};

describe('OutboxRelayWorker', () => {
  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  it('polls repeatedly while running', async () => {
    const relayBatch = jest.fn(() => Promise.resolve(EMPTY));
    const worker = workerWith(relayBatch);
    worker.start();
    await waitFor(() => relayBatch.mock.calls.length >= 3);
    await worker.stop();
    expect(worker.isRunning).toBe(false);
  });

  it('runs the next pass immediately after a full batch', async () => {
    const relayBatch = jest
      .fn<Promise<RelayBatchResult>, []>()
      .mockResolvedValueOnce({ ...EMPTY, published: 5 })
      .mockResolvedValue(EMPTY);
    const worker = workerWith(relayBatch, 60_000); // would sleep a minute if it slept
    worker.start();
    await waitFor(() => relayBatch.mock.calls.length >= 2, 500);
    await worker.stop();
  });

  it('keeps running after a failed pass', async () => {
    const relayBatch = jest
      .fn<Promise<RelayBatchResult>, []>()
      .mockRejectedValueOnce(new Error('MongoDB not reachable'))
      .mockResolvedValue(EMPTY);
    const worker = workerWith(relayBatch);
    worker.start();
    await waitFor(() => relayBatch.mock.calls.length >= 2);
    await worker.stop();
  });

  it('shuts down gracefully: wakes from sleep and waits for the in-flight pass', async () => {
    let finishPass!: () => void;
    let passFinished = false;
    const relayBatch = jest.fn(
      () =>
        new Promise<RelayBatchResult>((resolve) => {
          finishPass = () => {
            passFinished = true;
            resolve(EMPTY);
          };
        }),
    );
    const worker = workerWith(relayBatch, 60_000);
    worker.start();
    await waitFor(() => relayBatch.mock.calls.length === 1);

    const stopping = worker.beforeApplicationShutdown();
    setTimeout(() => finishPass(), 30);
    await stopping;
    expect(passFinished).toBe(true);
    expect(relayBatch).toHaveBeenCalledTimes(1); // no new pass after stop
  });

  it('stop() returns promptly while sleeping', async () => {
    const worker = workerWith(
      jest.fn(() => Promise.resolve(EMPTY)),
      60_000,
    );
    worker.start();
    await new Promise((resolve) => setTimeout(resolve, 20));
    const started = Date.now();
    await worker.stop();
    expect(Date.now() - started).toBeLessThan(500);
  });
});
