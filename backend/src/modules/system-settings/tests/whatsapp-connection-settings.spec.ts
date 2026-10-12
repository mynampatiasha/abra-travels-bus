import { Types } from 'mongoose';
import { type Model, type ClientSession } from 'mongoose';
import { FieldEncryptionService } from '../../../common/crypto/field-encryption.service';
import { AppConfigService } from '../../../config/app-config.service';
import { type WhatsAppSettings } from '../../../integrations/whatsapp/whatsapp-settings.schema';
import { WhatsAppSettingsStore } from '../../../integrations/whatsapp/whatsapp-settings.store';
import { UpdateWhatsAppSettingsDto } from '../dto/whatsapp-settings.dto';

describe('WhatsApp connection settings', () => {
  it('accepts the reference connection fields and rejects invalid values', () => {
    expect(
      UpdateWhatsAppSettingsDto.zodSchema.safeParse({
        phoneDisplay: '+91 90000 00000',
        webhookVerifyToken: 'abra_webhook_verify_123',
        reason: 'Configure WhatsApp connection',
      }).success,
    ).toBe(true);
    for (const fields of [
      { phoneDisplay: 'not a phone' },
      { webhookVerifyToken: 'short' },
      { webhookVerifyToken: 'contains spaces' },
    ]) {
      expect(
        UpdateWhatsAppSettingsDto.zodSchema.safeParse({
          ...fields,
          reason: 'Configure WhatsApp connection',
        }).success,
      ).toBe(false);
    }
  });

  it('encrypts the verify token, preserves omitted secrets and allows explicit clearing', async () => {
    const updates: Array<Record<string, unknown>> = [];
    const query = {
      lean: () => ({ exec: () => Promise.resolve({ key: 'default' }) }),
    };
    const model = {
      findOneAndUpdate: (_filter: unknown, update: { $set: Record<string, unknown> }) => {
        updates.push(update.$set);
        return query;
      },
    } as unknown as Model<WhatsAppSettings>;
    const encryption = {
      encrypt: (value: string) => `encrypted:${value}`,
    } as unknown as FieldEncryptionService;
    const store = new WhatsAppSettingsStore(model, encryption, {} as AppConfigService);
    const actor = new Types.ObjectId();
    const session = {} as ClientSession;

    await store.save(
      { phoneDisplay: '+91 90000 00000', webhookVerifyToken: 'chosen_verify_token' },
      actor,
      session,
    );
    expect(updates[0]).toMatchObject({
      phoneDisplay: '+91 90000 00000',
      webhookVerifyTokenEncrypted: 'encrypted:chosen_verify_token',
    });
    expect(updates[0]).not.toHaveProperty('webhookVerifyToken');

    await store.save({ phoneDisplay: '+91 91111 11111' }, actor, session);
    expect(updates[1]).not.toHaveProperty('webhookVerifyTokenEncrypted');
    expect(updates[1]).not.toHaveProperty('accessTokenEncrypted');

    await store.save({ webhookVerifyToken: null }, actor, session);
    expect(updates[2]?.webhookVerifyTokenEncrypted).toBeNull();
  });
});
