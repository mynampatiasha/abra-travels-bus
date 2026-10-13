import { Types } from 'mongoose';
import { EmailDeliveryError } from '../../../integrations/email/email.service';
import { WhatsAppDeliveryError } from '../../../integrations/whatsapp/whatsapp-provider.interface';
import { MessageSenderService, toMessageView } from '../messages_admin_manage.service';

type Doc = Record<string, unknown> & { _id: Types.ObjectId; createdAt: Date };

/** A tiny in-memory stand-in for the Mongoose model: only what the sender uses. */
function fakeModel() {
  const docs: Doc[] = [];
  const lean = (value: unknown) => ({ lean: () => ({ exec: () => Promise.resolve(value) }) });
  return {
    docs,
    findOne: (filter: Record<string, unknown>) =>
      lean(
        docs.find((doc) => Object.entries(filter).every(([key, value]) => doc[key] === value)) ??
          null,
      ),
    create: (input: Record<string, unknown>) => {
      const doc = { _id: new Types.ObjectId(), createdAt: new Date(), ...input } as Doc;
      docs.push(doc);
      return Promise.resolve({ toObject: () => doc });
    },
    findByIdAndUpdate: (
      id: Types.ObjectId,
      update: { $set: Record<string, unknown>; $inc?: Record<string, number> },
    ) => {
      const doc = docs.find((candidate) => candidate._id.equals(id))!;
      Object.assign(doc, update.$set);
      for (const [key, by] of Object.entries(update.$inc ?? {})) {
        doc[key] = ((doc[key] as number) ?? 0) + by;
      }
      return lean(doc);
    },
  };
}

function build(options: {
  emailSend?: () => Promise<void>;
  whatsApp?: { enabled: boolean; template?: string };
  whatsAppSend?: () => Promise<void>;
}) {
  const model = fakeModel();
  const email = { send: jest.fn(options.emailSend ?? (() => Promise.resolve())) };
  const whatsApp = { sendTemplate: jest.fn(options.whatsAppSend ?? (() => Promise.resolve())) };
  const settings = {
    effective: () =>
      Promise.resolve({
        enabled: options.whatsApp?.enabled ?? false,
        notificationTemplateName: options.whatsApp?.template,
        notificationTemplateLanguage: options.whatsApp?.template ? 'en' : undefined,
      }),
  };
  const sender = new MessageSenderService(
    model as never,
    email as never,
    settings as never,
    whatsApp as never,
  );
  return { sender, model, email, whatsApp };
}

const emailInput = {
  channel: 'EMAIL' as const,
  kind: 'BOOKING_CONFIRMED' as const,
  recipientName: 'Priya Nair',
  address: 'priya@example.com',
  subject: 'Booking confirmed: ABRK1234A',
  body: 'Your seat 12A on Hyderabad to Bengaluru is confirmed.',
};

describe('MessageSenderService', () => {
  it('sends an email and stores a copy marked SENT', async () => {
    const { sender, model, email } = build({});
    const view = await sender.send(emailInput);
    expect(view.status).toBe('SENT');
    expect(view.attempts).toBe(1);
    expect(view.sentAt).not.toBeNull();
    expect(email.send).toHaveBeenCalledTimes(1);
    expect(model.docs).toHaveLength(1);
  });

  it('stores the message as SKIPPED when email is not set up, and does not throw', async () => {
    const { sender } = build({
      emailSend: () =>
        Promise.reject(new EmailDeliveryError('Email is not set up.', 'NOT_CONFIGURED')),
    });
    const view = await sender.send(emailInput);
    expect(view.status).toBe('SKIPPED');
    expect(view.detail).toBe('Email is not set up.');
  });

  it('stores the message as FAILED with a sentence for people when the provider refuses it', async () => {
    const { sender } = build({
      emailSend: () =>
        Promise.reject(new EmailDeliveryError('The mail server refused it.', 'REJECTED')),
    });
    const view = await sender.send(emailInput);
    expect(view.status).toBe('FAILED');
    expect(view.detail).toBe('The mail server refused it.');
  });

  it("never stores a provider's raw error text", async () => {
    const { sender } = build({
      emailSend: () => Promise.reject(new Error('smtp://user:secret@host failed')),
    });
    const view = await sender.send(emailInput);
    expect(view.status).toBe('FAILED');
    expect(view.detail).toBe('The channel could not be used.');
    expect(JSON.stringify(view)).not.toContain('secret');
  });

  it('skips WhatsApp when no notification template is set up', async () => {
    const { sender, whatsApp } = build({ whatsApp: { enabled: true } });
    const view = await sender.send({
      ...emailInput,
      channel: 'WHATSAPP',
      address: '+919876543210',
    });
    expect(view.status).toBe('SKIPPED');
    expect(whatsApp.sendTemplate).not.toHaveBeenCalled();
  });

  it('sends WhatsApp through the template with the subject and a one-line body', async () => {
    const { sender, whatsApp } = build({ whatsApp: { enabled: true, template: 'abra_update' } });
    const view = await sender.send({
      ...emailInput,
      channel: 'WHATSAPP',
      address: '+919876543210',
      body: 'Line one\n\nLine   two',
    });
    expect(view.status).toBe('SENT');
    expect(whatsApp.sendTemplate).toHaveBeenCalledWith(
      expect.objectContaining({
        to: '+919876543210',
        templateName: 'abra_update',
        bodyParameters: ['Booking confirmed: ABRK1234A', 'Line one Line two'],
      }),
    );
  });

  it('marks a WhatsApp refusal FAILED', async () => {
    const { sender } = build({
      whatsApp: { enabled: true, template: 'abra_update' },
      whatsAppSend: () => Promise.reject(new WhatsAppDeliveryError('WhatsApp did not accept it.')),
    });
    const view = await sender.send({
      ...emailInput,
      channel: 'WHATSAPP',
      address: '+919876543210',
    });
    expect(view.status).toBe('FAILED');
    expect(view.detail).toBe('WhatsApp did not accept it.');
  });

  it('does nothing the second time for the same event, channel and address', async () => {
    const { sender, model, email } = build({});
    await sender.send({ ...emailInput, eventId: 'evt-1' });
    const again = await sender.send({ ...emailInput, eventId: 'evt-1' });
    expect(again.status).toBe('SENT');
    expect(email.send).toHaveBeenCalledTimes(1);
    expect(model.docs).toHaveLength(1);
  });

  it('tries a FAILED message of the same event again instead of creating a second one', async () => {
    let fail = true;
    const { sender, model } = build({
      emailSend: () =>
        fail ? Promise.reject(new EmailDeliveryError('Busy.', 'REJECTED')) : Promise.resolve(),
    });
    const first = await sender.send({ ...emailInput, eventId: 'evt-2' });
    expect(first.status).toBe('FAILED');
    fail = false;
    const second = await sender.send({ ...emailInput, eventId: 'evt-2' });
    expect(second.status).toBe('SENT');
    expect(second.attempts).toBe(2);
    expect(model.docs).toHaveLength(1);
  });

  it('the view shows what an administrator needs and the ids as text', () => {
    const id = new Types.ObjectId();
    const view = toMessageView({
      _id: id,
      createdAt: new Date('2026-10-12T10:00:00Z'),
      channel: 'EMAIL',
      kind: 'GENERAL',
      recipientName: 'A',
      address: 'a@b.c',
      subject: 's',
      body: 'b',
      status: 'SENT',
      attempts: 1,
    });
    expect(view.id).toBe(id.toHexString());
    expect(view.at).toBe('2026-10-12T10:00:00.000Z');
    expect(view.bookingId).toBeNull();
    expect(view.detail).toBeNull();
  });
});
