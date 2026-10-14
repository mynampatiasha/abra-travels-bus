import { Types } from 'mongoose';
import {
  AUDIT_ACTION_LABELS,
  SENSITIVE_ACTIONS,
  targetLabelOf,
} from '../audit_log_admin_manage.service';
import { AUDIT_ACTIONS } from '../schemas/audit-log.schema';

describe('Audit log page words', () => {
  it('has a plain label for every action, and no two actions share one', () => {
    const labels = AUDIT_ACTIONS.map((action) => AUDIT_ACTION_LABELS[action]);
    expect(labels.every((label) => label && label.length > 3)).toBe(true);
    expect(new Set(labels).size).toBe(labels.length);
  });

  it('marks only known actions as sensitive, and the access and settings ones are', () => {
    for (const action of SENSITIVE_ACTIONS) expect(AUDIT_ACTIONS).toContain(action);
    for (const action of [
      'role.access.changed',
      'user.roles.changed',
      'settings.integration.changed',
      'maintenance.changed',
    ] as const) {
      expect(SENSITIVE_ACTIONS.has(action)).toBe(true);
    }
    expect(SENSITIVE_ACTIONS.has('banner.created')).toBe(false);
    expect(SENSITIVE_ACTIONS.has('catalogue.exported')).toBe(false);
  });

  describe('the target of an entry', () => {
    const entry = (before: Record<string, unknown>, after: Record<string, unknown>) => ({
      entityType: 'place-request',
      entityId: new Types.ObjectId(),
      before,
      after,
    });

    it('names the record when the change carries a name', () => {
      expect(targetLabelOf(entry({}, { name: ' Kondapur stop ' }))).toBe(
        'Place request: Kondapur stop',
      );
      expect(targetLabelOf(entry({ title: 'Old title' }, {}))).toBe('Place request: Old title');
      expect(targetLabelOf(entry({}, { companyName: 'Meena Travels' }))).toBe(
        'Place request: Meena Travels',
      );
    });

    it('prefers the new name over the old one, and falls back to the kind of record', () => {
      expect(targetLabelOf(entry({ name: 'Old' }, { name: 'New' }))).toBe('Place request: New');
      expect(targetLabelOf(entry({}, {}))).toBe('Place request');
      expect(targetLabelOf(entry({}, { name: 42 }))).toBe('Place request');
    });
  });
});
