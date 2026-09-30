import { systemActor } from '../request-context/request-actor';
import { RequestContextService } from '../request-context/request-context.service';

describe('RequestContextService', () => {
  it('has no context outside a request', () => {
    expect(RequestContextService.current()).toBeUndefined();
    expect(RequestContextService.actor()).toBeUndefined();
  });

  it('attaches an actor while keeping the current request id', () => {
    const actor = systemActor('test');
    RequestContextService.run({ requestId: 'req-1' }, () => {
      RequestContextService.runWithActor(actor, () => {
        expect(RequestContextService.requestId()).toBe('req-1');
        expect(RequestContextService.actor()).toBe(actor);
      });
      // The outer context is unchanged
      expect(RequestContextService.actor()).toBeUndefined();
    });
  });

  it('needs an explicit request id outside a request', () => {
    expect(() => RequestContextService.runWithActor(systemActor('job'), () => 1)).toThrow(
      'needs a request id',
    );
    expect(RequestContextService.runWithActor(systemActor('job'), () => 1, 'job-1')).toBe(1);
  });
});
