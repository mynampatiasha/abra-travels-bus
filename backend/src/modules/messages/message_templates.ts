import { type MessageKind } from './messages_admin_manage.service';

/*
 * The words of every message the platform sends, in one place: the email (subject, plain text and
 * a branded HTML page) and the WhatsApp template it needs. WhatsApp only lets a business start a
 * conversation with a template that Meta approved, with blanks filled in; the wording below is
 * what you submit (documentation/whatsapp-templates.md lists it for copying). The names are fixed
 * here, so the template you create in WhatsApp Manager must use exactly the same name and the
 * same blanks in the same order.
 *
 * No emojis anywhere: plain words, and the Abra logo in the email header.
 */

export type MessageVars = Readonly<Record<string, string | undefined>>;

export interface WhatsAppTemplateDef {
  /** The name in WhatsApp Manager. */
  name: string;
  language: string;
  /** The variables that fill {{1}}, {{2}} ... in order. */
  params: readonly string[];
  /** The wording to submit: {{1}} stands for the first param, and so on. */
  wording: string;
  /** The ticket PDF travels as the header of this template. */
  withDocument?: boolean;
}

interface EmailParts {
  subject: string;
  heading: string;
  intro: string;
  rows: ReadonlyArray<readonly [string, string]>;
  footnote?: string;
}

interface TemplateDef {
  email: (v: MessageVars) => EmailParts;
  whatsapp: WhatsAppTemplateDef;
}

const v = (vars: MessageVars, key: string, fallback = '-'): string => {
  const value = vars[key];
  return value === undefined || value === '' ? fallback : value;
};

const row = (label: string, value: string): readonly [string, string] => [label, value];

export const MESSAGE_TEMPLATES: Partial<Record<MessageKind, TemplateDef>> = {
  BOOKING_CONFIRMED: {
    email: (vars) => ({
      subject: `Booking confirmed: ${v(vars, 'pnr')}`,
      heading: 'Your booking is confirmed',
      intro: `Hello ${v(vars, 'contactName', 'there')}, your seats are booked. Your ticket is attached as a PDF.`,
      rows: [
        row('Booking reference (PNR)', v(vars, 'pnr')),
        row('Route', v(vars, 'route')),
        row('Departure', v(vars, 'departureText')),
        row('Seats', v(vars, 'seatsText')),
        row('Boarding point', v(vars, 'boardingPoint')),
        row('Amount paid', v(vars, 'amountText')),
      ],
      footnote: 'Show the QR code on your ticket, or your PNR, to the conductor when you board. Please reach the boarding point 15 minutes early.',
    }),
    whatsapp: {
      name: 'abra_booking_confirmed',
      language: 'en',
      params: ['contactName', 'pnr', 'route', 'departureText', 'seatsText', 'boardingPoint', 'amountText'],
      withDocument: true,
      wording:
        'Hello {{1}}, your booking is confirmed.\nPNR: {{2}}\nRoute: {{3}}\nDeparture: {{4}}\nSeats: {{5}}\nBoarding point: {{6}}\nAmount paid: {{7}}\nYour ticket is attached. Show the QR code to the conductor when you board.',
    },
  },
  BOOKING_CANCELLED: {
    email: (vars) => ({
      subject: `Booking cancelled: ${v(vars, 'pnr')}`,
      heading: 'Your booking is cancelled',
      intro: `Your booking ${v(vars, 'pnr')} on ${v(vars, 'route')} is cancelled.`,
      rows: [row('Booking reference (PNR)', v(vars, 'pnr')), row('Route', v(vars, 'route'))],
      footnote: 'The refund has started and reaches the account you paid from in 5 to 7 working days.',
    }),
    whatsapp: {
      name: 'abra_booking_cancelled',
      language: 'en',
      params: ['pnr', 'route'],
      wording: 'Your booking {{1}} on {{2}} is cancelled. The refund has started and reaches your account in 5 to 7 working days.',
    },
  },
  REFUND_PAID: {
    email: (vars) => ({
      subject: `Refund processed: ${v(vars, 'pnr')}`,
      heading: 'Your refund is processed',
      intro: `Your refund for booking ${v(vars, 'pnr')} has been processed.`,
      rows: [
        row('Booking reference (PNR)', v(vars, 'pnr')),
        row('Refund amount', v(vars, 'amountText')),
        row('Reference', v(vars, 'reference')),
      ],
      footnote: 'It can take a few working days to show in your account, depending on your bank.',
    }),
    whatsapp: {
      name: 'abra_refund_processed',
      language: 'en',
      params: ['amountText', 'pnr', 'reference'],
      wording: 'Your refund of {{1}} for booking {{2}} has been processed. Reference: {{3}}. It can take a few working days to reach your account.',
    },
  },
  PAYMENT_FAILED: {
    email: (vars) => ({
      subject: 'Your payment did not go through',
      heading: 'Payment not completed',
      intro: `Your payment of ${v(vars, 'amountText')} did not go through. ${v(vars, 'reason', '')}`.trim(),
      rows: [row('Route', v(vars, 'route')), row('Amount', v(vars, 'amountText'))],
      footnote: 'Your seats are held for a short time. Please open the app and try again. If money was taken from your account, it is returned automatically.',
    }),
    whatsapp: {
      name: 'abra_payment_failed',
      language: 'en',
      params: ['amountText', 'route'],
      wording: 'Your payment of {{1}} for {{2}} did not go through. Your seats are held for a short time: please open the app and try again. If money was taken, it is returned automatically.',
    },
  },
  TRIP_DELAYED: {
    email: (vars) => ({
      subject: `Bus delayed: ${v(vars, 'pnr')}`,
      heading: 'Your bus is running late',
      intro: `Your bus on ${v(vars, 'route')} is about ${v(vars, 'minutes')} minutes late. ${v(vars, 'reason', '')}`.trim(),
      rows: [row('Booking reference (PNR)', v(vars, 'pnr')), row('Route', v(vars, 'route')), row('Delay', `${v(vars, 'minutes')} minutes`)],
      footnote: 'You can follow the bus live in the app.',
    }),
    whatsapp: {
      name: 'abra_trip_delayed',
      language: 'en',
      params: ['route', 'minutes', 'pnr'],
      wording: 'Your bus on {{1}} is about {{2}} minutes late. Booking {{3}}. You can follow the bus live in the app.',
    },
  },
  BOARDING_STARTED: {
    email: (vars) => ({
      subject: `Boarding now: ${v(vars, 'pnr')}`,
      heading: 'Boarding has started',
      intro: `Bus ${v(vars, 'busRegistration')} is boarding. Please reach your boarding point.`,
      rows: [row('Booking reference (PNR)', v(vars, 'pnr')), row('Bus', v(vars, 'busRegistration'))],
    }),
    whatsapp: {
      name: 'abra_boarding_started',
      language: 'en',
      params: ['busRegistration', 'pnr'],
      wording: 'Boarding has started for bus {{1}}. Please reach your boarding point now. Booking {{2}}.',
    },
  },
  TRIP_REMINDER: {
    email: (vars) => ({
      subject: `Your trip is coming up: ${v(vars, 'pnr')}`,
      heading: 'Your trip is coming up',
      intro: `A reminder for your trip on ${v(vars, 'route')}.`,
      rows: [
        row('Booking reference (PNR)', v(vars, 'pnr')),
        row('Departure', v(vars, 'departureText')),
        row('Boarding point', v(vars, 'boardingPoint')),
        row('Seats', v(vars, 'seatsText')),
      ],
      footnote: 'Please reach the boarding point 15 minutes early and keep your ticket and a photo ID with you.',
    }),
    whatsapp: {
      name: 'abra_trip_reminder',
      language: 'en',
      params: ['route', 'departureText', 'boardingPoint', 'pnr'],
      wording: 'Reminder: your trip on {{1}} leaves on {{2}} from {{3}}. Booking {{4}}. Please reach the boarding point 15 minutes early and keep a photo ID with you.',
    },
  },
  FEEDBACK_REQUEST: {
    email: (vars) => ({
      subject: 'How was your trip?',
      heading: 'How was your trip?',
      intro: `Thank you for travelling with ${v(vars, 'operatorName', 'us')} on ${v(vars, 'route')}. Your feedback helps other travellers and helps us improve.`,
      rows: [row('Booking reference (PNR)', v(vars, 'pnr')), row('Route', v(vars, 'route'))],
      footnote: 'Open the Abra Travels app, go to My trips and rate this journey. It takes less than a minute.',
    }),
    whatsapp: {
      name: 'abra_feedback_request',
      language: 'en',
      params: ['route', 'pnr'],
      wording: 'Thank you for travelling with Abra Travels on {{1}} (booking {{2}}). How was your trip? Open the app, go to My trips and rate this journey. It takes less than a minute.',
    },
  },
  SUPPORT_REPLY: {
    email: (vars) => ({
      subject: `Reply to your support request ${v(vars, 'ticketNumber', '')}`.trim(),
      heading: 'We have replied to your request',
      intro: v(vars, 'replyText', 'Our team has answered your support request.'),
      rows: [row('Request', v(vars, 'ticketNumber'))],
      footnote: 'You can see the whole conversation and reply in the app, under Support.',
    }),
    whatsapp: {
      name: 'abra_support_reply',
      language: 'en',
      params: ['ticketNumber'],
      wording: 'We have replied to your support request {{1}}. Open the Abra Travels app and go to Support to read the reply.',
    },
  },
};

// ===== the email page =====

const escapeHtml = (text: string): string =>
  text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

/** Id of the logo inside the email (an attached image, not a link that a mail app may block). */
export const EMAIL_LOGO_CID = 'abra-logo';

function htmlOf(parts: EmailParts): string {
  const rows = parts.rows
    .map(
      ([label, value]) =>
        `<tr><td style="padding:9px 0;border-bottom:1px solid #E6EDF3;color:#5C6F82;font-size:14px;width:44%">${escapeHtml(label)}</td>` +
        `<td style="padding:9px 0;border-bottom:1px solid #E6EDF3;color:#0F2233;font-size:14px;font-weight:600;text-align:right">${escapeHtml(value)}</td></tr>`,
    )
    .join('');
  return (
    '<!doctype html><html><body style="margin:0;background:#F2F7FB;font-family:Arial,Helvetica,sans-serif">' +
    '<table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#F2F7FB"><tr><td align="center" style="padding:24px 12px">' +
    '<table role="presentation" width="560" cellspacing="0" cellpadding="0" style="max-width:560px;width:100%;background:#FFFFFF;border-radius:12px;overflow:hidden">' +
    '<tr><td style="background:#12304A;padding:18px 24px;border-bottom:4px solid #36BDF5">' +
    `<img src="cid:${EMAIL_LOGO_CID}" width="40" height="40" alt="Abra Travels" style="vertical-align:middle;border-radius:8px;background:#FFFFFF">` +
    '<span style="color:#FFFFFF;font-size:20px;font-weight:bold;vertical-align:middle;margin-left:12px">Abra Travels</span></td></tr>' +
    '<tr><td style="padding:24px">' +
    `<h1 style="margin:0 0 10px;font-size:22px;color:#0F2233">${escapeHtml(parts.heading)}</h1>` +
    `<p style="margin:0 0 18px;font-size:15px;line-height:1.5;color:#33475B">${escapeHtml(parts.intro)}</p>` +
    (rows ? `<table role="presentation" width="100%" cellspacing="0" cellpadding="0">${rows}</table>` : '') +
    (parts.footnote
      ? `<p style="margin:18px 0 0;font-size:13px;line-height:1.5;color:#5C6F82">${escapeHtml(parts.footnote)}</p>`
      : '') +
    '</td></tr>' +
    '<tr><td style="background:#F2F7FB;padding:14px 24px;font-size:12px;color:#7A8B9C">This message was sent by Abra Travels. If you did not expect it, you can ignore it.</td></tr>' +
    '</table></td></tr></table></body></html>'
  );
}

export interface RenderedEmail {
  subject: string;
  text: string;
  html: string;
}

/** The email for [kind] with its values, or null when the kind has no template (the plain words are used then). */
export function renderEmail(kind: MessageKind, vars: MessageVars): RenderedEmail | null {
  const def = MESSAGE_TEMPLATES[kind];
  if (!def) return null;
  const parts = def.email(vars);
  const text = [
    parts.heading,
    '',
    parts.intro,
    '',
    ...parts.rows.map(([label, value]) => `${label}: ${value}`),
    ...(parts.footnote ? ['', parts.footnote] : []),
    '',
    'Abra Travels',
  ].join('\n');
  return { subject: parts.subject, text, html: htmlOf(parts) };
}

/** The WhatsApp template of [kind] and the values for its blanks, in order. */
export function whatsAppFor(
  kind: MessageKind,
  vars: MessageVars,
): { template: WhatsAppTemplateDef; parameters: string[] } | null {
  const def = MESSAGE_TEMPLATES[kind];
  if (!def) return null;
  return {
    template: def.whatsapp,
    // A blank is never empty: WhatsApp refuses an empty parameter
    parameters: def.whatsapp.params.map((name) => (v(vars, name).replace(/\s+/g, ' ').trim() || '-').slice(0, 900)),
  };
}

/** Every WhatsApp template the platform needs, for the document you submit to Meta. */
export function allWhatsAppTemplates(): WhatsAppTemplateDef[] {
  return Object.values(MESSAGE_TEMPLATES).flatMap((def) => (def ? [def.whatsapp] : []));
}
