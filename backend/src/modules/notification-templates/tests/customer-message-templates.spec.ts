import { CORE_EVENT_RULES } from '../../notifications/event_router_core';
import {
  CUSTOMER_MESSAGE_TEMPLATES,
  dltTemplateBody,
  fieldsOf,
  fillCustomerMessage,
  fillTemplate,
  metaTemplateBody,
} from '../customer_message_templates';

describe('customer message templates: the list', () => {
  it('has one template per key, each a valid Meta template name', () => {
    const keys = CUSTOMER_MESSAGE_TEMPLATES.map((template) => template.key);
    expect(new Set(keys).size).toBe(keys.length);
    for (const key of keys) expect(key).toMatch(/^[a-z0-9_]{1,64}$/);
  });

  it('gives every template words for at least one channel', () => {
    for (const template of CUSTOMER_MESSAGE_TEMPLATES) {
      expect('text' in template || 'sms' in template).toBe(true);
    }
  });

  it('signs every SMS -ABRA, as registered on DLT', () => {
    for (const template of CUSTOMER_MESSAGE_TEMPLATES) {
      if ('sms' in template) expect(template.sms).toMatch(/ -ABRA$/);
    }
  });

  it('is used by the router for every customer template but the login code', () => {
    const used = new Set(
      CORE_EVENT_RULES.flatMap((rule) =>
        (rule.messages ?? []).flatMap((message) => ('template' in message ? [message.template] : [])),
      ),
    );
    const unused = CUSTOMER_MESSAGE_TEMPLATES.map((template) => template.key).filter(
      (key) => !used.has(key),
    );
    // The login code is sent by otp-delivery, not by an event
    expect(unused).toEqual(['login_otp']);
  });
});

describe('customer message templates: filling in', () => {
  it('lists the fields in the order they first appear', () => {
    expect(fieldsOf('{a} and {b}, then {a} again and {c}')).toEqual(['a', 'b', 'c']);
  });

  it('turns the text into the Meta and DLT versions', () => {
    const text = 'Hi {contactName}, PNR {pnr}. Again {contactName}.';
    expect(metaTemplateBody(text)).toBe('Hi {{1}}, PNR {{2}}. Again {{1}}.');
    expect(dltTemplateBody(text)).toBe('Hi {#var#}, PNR {#var#}. Again {#var#}.');
  });

  it('fills a missing value with "-" so no message has a hole', () => {
    expect(fillTemplate('Bus {busRegistration} at {boardingPoint}', { busRegistration: 'TS09' })).toBe(
      'Bus TS09 at -',
    );
  });

  it('keeps the line breaks of the full text, and makes one-line parameters for Meta', () => {
    const filled = fillCustomerMessage('refund_processed', {
      contactName: 'Asha',
      amountText: 'Rs 500',
      pnr: 'ABR123',
      reference: 'RFND9',
    });
    expect(filled.kind).toBe('REFUND_PAID');
    expect(filled.subject).toBe('Refund processed: ABR123');
    expect(filled.text.split('\n')[0]).toBe(
      'Hi Asha, good news! 🎉 Your refund of Rs 500 for PNR ABR123 has been processed.',
    );
    expect(filled.whatsAppParameters).toEqual(['Asha', 'Rs 500', 'ABR123', 'RFND9']);
    expect(filled.sms).toBe('Abra Travels: Refund Rs 500 for PNR ABR123 processed. Ref RFND9 -ABRA');
    expect(filled.whatsAppButtonParameter).toBeUndefined();
  });

  it('fills the button from its field, and leaves an SMS-less template without SMS', () => {
    const filled = fillCustomerMessage('trip_completed_feedback', {
      contactName: 'Asha',
      route: 'A to B',
      bookingId: 'b1',
    });
    expect(filled.whatsAppButtonParameter).toBe('b1');
    expect(filled.sms).toBe('');
  });

  it('writes the emergency-contact alert calmly, with no emojis, on WhatsApp and SMS', () => {
    const filled = fillCustomerMessage('sos_emergency_contact', { customerName: 'Asha' });
    expect(filled.text.startsWith('Urgent: Asha has raised an SOS alert')).toBe(true);
    expect(filled.text).toMatch(/call 112\.\n– Abra Travels Safety Team$/);
    expect(filled.text).not.toMatch(/\p{Extended_Pictographic}/u);
    expect(filled.sms.startsWith('ALERT: Asha raised an SOS')).toBe(true);
  });
});
