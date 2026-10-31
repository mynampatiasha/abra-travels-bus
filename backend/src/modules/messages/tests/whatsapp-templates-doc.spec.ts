import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { allWhatsAppTemplates, MESSAGE_TEMPLATES } from '../message_templates';
import { type MessageKind } from '../messages_admin_manage.service';

/*
 * documentation/whatsapp-templates.md is the list you copy into WhatsApp Manager. It is written from
 * message_templates.ts, and this test fails when the two drift apart. After changing a template,
 * run it once with UPDATE_WHATSAPP_DOC=1 to rewrite the file.
 */

const DOC = join(__dirname, '..', '..', '..', '..', '..', 'documentation', 'whatsapp-templates.md');

const EXAMPLES: Record<string, string> = {
  contactName: 'Asha Rao',
  pnr: 'ABR7K2M9QX',
  route: 'Hyderabad to Bengaluru',
  departureText: '1 Nov, 9:30 pm',
  seatsText: '1, 2',
  boardingPoint: 'Ameerpet Metro',
  amountText: 'Rs 1,734',
  reference: 'rfnd_Nk3x92',
  minutes: '25',
  busRegistration: 'TS09AB1234',
  ticketNumber: 'TK-1042',
};

function build(): string {
  const lines: string[] = [
    '# WhatsApp message templates',
    '',
    'WhatsApp lets a business start a conversation only with a template that Meta has approved. Create each template below in',
    'WhatsApp Manager (Message templates, Create template) with **exactly** this name, language and wording. Keep the blanks',
    '`{{1}}`, `{{2}}` and so on in the same order. Choose the category **Utility**.',
    '',
    'The ticket templates have a **document header**: choose Header, Document, and upload any sample PDF. The real ticket PDF is',
    'sent in that place with each message.',
    '',
    'The same messages also go out as emails (branded, with the logo), using the email settings in the admin app.',
    '',
    'This file is written from `backend/src/modules/messages/message_templates.ts`. Do not edit it by hand: change the template',
    'there and run `UPDATE_WHATSAPP_DOC=1 npm test -- whatsapp-templates-doc` to write it again.',
    '',
  ];
  for (const [kind, def] of Object.entries(MESSAGE_TEMPLATES) as Array<[MessageKind, NonNullable<(typeof MESSAGE_TEMPLATES)[MessageKind]>]>) {
    const t = def.whatsapp;
    lines.push(`## ${t.name}`, '', `Used for: ${kind.toLowerCase().replace(/_/g, ' ')}`, '');
    lines.push(`- Name: \`${t.name}\``, `- Language: \`${t.language}\``, '- Category: Utility');
    lines.push(`- Header: ${t.withDocument ? 'Document (the ticket PDF)' : 'none'}`, '- Footer: none', '- Buttons: none', '');
    lines.push('Body:', '', '```', t.wording, '```', '');
    lines.push('Blanks, in order:', '');
    t.params.forEach((param, index) => lines.push(`${index + 1}. {{${index + 1}}} = ${param} (example: ${EXAMPLES[param] ?? 'sample'})`));
    lines.push('');
  }
  lines.push('## Check list', '', `- ${allWhatsAppTemplates().length} templates in all.`, '- Status in WhatsApp Manager must be **Approved** before the message can be sent; until then it is recorded as failed in Messages sent.', '');
  return lines.join('\n');
}

describe('documentation/whatsapp-templates.md', () => {
  it('lists every template exactly as the code sends it', () => {
    const wanted = build();
    if (process.env.UPDATE_WHATSAPP_DOC === '1') writeFileSync(DOC, wanted, 'utf-8');
    expect(existsSync(DOC)).toBe(true);
    expect(readFileSync(DOC, 'utf-8').replace(/\r\n/g, '\n')).toBe(wanted);
  });
});
