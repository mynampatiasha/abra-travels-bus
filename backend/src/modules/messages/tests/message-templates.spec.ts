import { Types } from 'mongoose';
import { MessageSenderService, MESSAGE_KINDS } from '../messages_admin_manage.service';
import { allWhatsAppTemplates, EMAIL_LOGO_CID, MESSAGE_TEMPLATES, renderEmail, whatsAppFor } from '../message_templates';

const vars = {
  contactName: 'Asha Rao',
  pnr: 'ABR7K2M9QX',
  route: 'Hyderabad to Bengaluru',
  departureText: '1 Nov, 9:30 pm',
  seatsText: '1, 2',
  boardingPoint: 'Ameerpet Metro',
  amountText: 'Rs 1,734',
};

describe('the words of the messages', () => {
  it('has an email and a WhatsApp template for each kind that gets one, with no emojis', () => {
    for (const kind of MESSAGE_KINDS) {
      const def = MESSAGE_TEMPLATES[kind];
      if (!def) continue;
      const email = renderEmail(kind, vars);
      expect(email?.subject.length).toBeGreaterThan(3);
      expect(email?.html).toContain(`cid:${EMAIL_LOGO_CID}`);
      const everything = JSON.stringify([email, def.whatsapp]);
      // eslint-disable-next-line no-misleading-character-class
      expect(everything).not.toMatch(/[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]/u);
    }
  });

  it('puts the booking details into the confirmation email, escaped', () => {
    const email = renderEmail('BOOKING_CONFIRMED', { ...vars, contactName: '<b>Asha</b> & Co' });
    expect(email?.subject).toBe('Booking confirmed: ABR7K2M9QX');
    expect(email?.text).toContain('Route: Hyderabad to Bengaluru');
    expect(email?.text).toContain('Amount paid: Rs 1,734');
    expect(email?.html).toContain('&lt;b&gt;Asha&lt;/b&gt; &amp; Co');
    expect(email?.html).not.toContain('<b>Asha</b>');
  });

  it('fills the blanks of a WhatsApp template in order, and never leaves one empty', () => {
    const made = whatsAppFor('BOOKING_CONFIRMED', { ...vars, boardingPoint: '', amountText: undefined });
    expect(made?.template.name).toBe('abra_booking_confirmed');
    expect(made?.template.withDocument).toBe(true);
    expect(made?.parameters).toEqual(['Asha Rao', 'ABR7K2M9QX', 'Hyderabad to Bengaluru', '1 Nov, 9:30 pm', '1, 2', '-', '-']);
    // The wording has exactly as many blanks as the template has parameters
    for (const template of allWhatsAppTemplates()) {
      const blanks = (template.wording.match(/\{\{\d+\}\}/g) ?? []).length;
      expect(blanks).toBe(template.params.length);
    }
  });

  it('has a name that is unique and fit for WhatsApp Manager', () => {
    const names = allWhatsAppTemplates().map((t) => t.name);
    expect(new Set(names).size).toBe(names.length);
    for (const name of names) expect(name).toMatch(/^[a-z][a-z0-9_]{2,}$/);
  });

  it('has nothing for a kind without a template', () => {
    expect(renderEmail('GENERAL', vars)).toBeNull();
    expect(whatsAppFor('ANNOUNCEMENT', vars)).toBeNull();
  });
});

type Doc = Record<string, unknown> & { _id: Types.ObjectId };

function senderWith(options: { whatsAppEnabled: boolean }) {
  const docs: Doc[] = [];
  const lean = (value: unknown) => ({ lean: () => ({ exec: () => Promise.resolve(value) }) });
  const model = {
    findOne: () => lean(null),
    create: (input: Record<string, unknown>) => {
      const doc = { _id: new Types.ObjectId(), createdAt: new Date(), ...input } as Doc;
      docs.push(doc);
      return Promise.resolve({ toObject: () => doc });
    },
    findByIdAndUpdate: (id: Types.ObjectId, update: { $set: Record<string, unknown> }) => {
      const doc = docs.find((d) => d._id.equals(id))!;
      Object.assign(doc, update.$set);
      return lean(doc);
    },
  };
  const email = { send: jest.fn(() => Promise.resolve()) };
  const whatsApp = { sendTemplate: jest.fn(() => Promise.resolve()) };
  const settings = { effective: () => Promise.resolve({ enabled: options.whatsAppEnabled, notificationTemplateName: undefined }) };
  const sender = new MessageSenderService(model as never, email as never, settings as never, whatsApp as never);
  return { sender, email, whatsApp };
}

const ticket = { filename: 'abra-ticket-ABR7K2M9QX.pdf', content: Buffer.from('%PDF-1.3 test'), contentType: 'application/pdf' };

const base = {
  kind: 'BOOKING_CONFIRMED' as const,
  recipientName: 'Asha Rao',
  subject: 'Booking confirmed: ABR7K2M9QX',
  body: 'plain words',
  variables: vars,
  attachment: ticket,
};

describe('sending a booking confirmation', () => {
  it('sends the branded email with the logo and the ticket PDF attached', async () => {
    const { sender, email } = senderWith({ whatsAppEnabled: true });
    const view = await sender.send({ ...base, channel: 'EMAIL', address: 'asha@example.com' });
    expect(view.status).toBe('SENT');
    const sent = (email.send.mock.calls[0] as unknown as [Record<string, unknown>])[0] as {
      subject: string;
      html: string;
      attachments: Array<{ filename: string; cid?: string; contentType: string }>;
    };
    expect(sent.subject).toBe('Booking confirmed: ABR7K2M9QX');
    expect(sent.html).toContain(`cid:${EMAIL_LOGO_CID}`);
    expect(sent.attachments.map((a) => a.filename)).toEqual(['abra-logo.png', 'abra-ticket-ABR7K2M9QX.pdf']);
    expect(sent.attachments[0]?.cid).toBe(EMAIL_LOGO_CID);
    expect(sent.attachments[1]?.contentType).toBe('application/pdf');
  });

  it('sends the approved WhatsApp template with the ticket as its header', async () => {
    const { sender, whatsApp } = senderWith({ whatsAppEnabled: true });
    const view = await sender.send({ ...base, channel: 'WHATSAPP', address: '+919876543210' });
    expect(view.status).toBe('SENT');
    expect(whatsApp.sendTemplate).toHaveBeenCalledWith({
      to: '+919876543210',
      templateName: 'abra_booking_confirmed',
      languageCode: 'en',
      bodyParameters: ['Asha Rao', 'ABR7K2M9QX', 'Hyderabad to Bengaluru', '1 Nov, 9:30 pm', '1, 2', 'Ameerpet Metro', 'Rs 1,734'],
      purpose: 'NOTIFICATION',
      documentHeader: ticket,
    });
  });

  it('skips WhatsApp, and says so, when WhatsApp is not set up', async () => {
    const { sender, whatsApp } = senderWith({ whatsAppEnabled: false });
    const view = await sender.send({ ...base, channel: 'WHATSAPP', address: '+919876543210' });
    expect(view.status).toBe('SKIPPED');
    expect(whatsApp.sendTemplate).not.toHaveBeenCalled();
  });

  it('keeps sending the plain words when no values are given (a resend, an old message)', async () => {
    const { sender, email } = senderWith({ whatsAppEnabled: true });
    await sender.send({ channel: 'EMAIL', kind: 'BOOKING_CONFIRMED', recipientName: 'Asha', address: 'a@example.com', subject: 'Hello', body: 'Plain' });
    const sent = (email.send.mock.calls[0] as unknown as [Record<string, unknown>])[0] as { subject: string; text: string; attachments: unknown[] };
    expect(sent.subject).toBe('Hello');
    expect(sent.text).toBe('Plain');
    expect(sent.attachments).toEqual([]);
  });
});
