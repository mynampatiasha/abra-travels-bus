import PDFDocument from 'pdfkit';
import { toBuffer } from 'qrcode';
import { ABRA_LOGO_PNG_BASE64 } from './ticket_logo';
import { type TicketView } from './tickets_customer.service';

/*
 * The ticket as a PDF: the Abra logo, drawn icons (never emojis), the trip, the passengers, the QR
 * the conductor scans, what was paid, the cancellation policy of this booking and the terms. It is
 * the same ticket the app shows; the email and WhatsApp carry this file.
 *
 * Fonts are the PDF standard ones, which have no rupee sign, so amounts are written "Rs 941.50".
 */

const NAVY = '#12304A';
const BLUE = '#1677C8';
const SKY = '#36BDF5';
const INK = '#0F2233';
const MUTED = '#5C6F82';
const LINE = '#D9E2EA';
const SOFT = '#F2F7FB';
const GREEN = '#1B8A5A';
const ORANGE = '#F28C28';

/** The terms every ticket carries until the admin Help centre holds the real ones. */
export const DEFAULT_TERMS: readonly string[] = [
  'Please reach the boarding point at least 15 minutes before departure and carry a photo ID that matches a passenger name.',
  'Show this ticket (the QR code or the PNR) to the conductor. A ticket is valid only for the date, seats and passengers printed on it.',
  'Abra Travels sells seats on buses run by independent operators. The operator is responsible for the journey; Abra Travels is the booking platform.',
  'Cancellation and refund follow the policy printed on this ticket. Gateway and platform charges that are not refundable are not returned.',
  'Departure and arrival times may change for traffic, weather or operational reasons. You will be told by message when a trip changes.',
  'Luggage is carried at the owner\'s risk. Carrying illegal goods, alcohol in excess of the law, or anything dangerous is not allowed.',
  'For help, contact the operator on the number printed here, or Abra Travels support through the app.',
];

export interface PolicyLine {
  hoursBefore: number;
  refundPct: number;
}

export interface TicketPdfInput {
  ticket: TicketView;
  policy: readonly PolicyLine[];
  terms?: readonly string[];
  supportPhone?: string;
  supportEmail?: string;
}

const rs = (paise: number): string => {
  const whole = Math.floor(paise / 100);
  const rest = paise % 100;
  const grouped = whole.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
  return rest === 0 ? `Rs ${grouped}` : `Rs ${grouped}.${rest.toString().padStart(2, '0')}`;
};

function timeText(iso: string, zone: string): string {
  return new Intl.DateTimeFormat('en-IN', {
    day: 'numeric',
    month: 'short',
    year: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
    hour12: true,
    timeZone: zone,
  }).format(new Date(iso));
}

function durationText(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return m === 0 ? `${h}h` : `${h}h ${m}m`;
}

// ===== icons: small vector drawings, one colour, drawn in a box of the given size =====

type Doc = InstanceType<typeof PDFDocument>;

function iconBus(doc: Doc, x: number, y: number, s: number, color: string): void {
  doc.save().fillColor(color);
  doc.roundedRect(x, y + s * 0.1, s, s * 0.68, s * 0.14).fill();
  doc.fillColor('#FFFFFF');
  doc.rect(x + s * 0.12, y + s * 0.22, s * 0.3, s * 0.22).fill();
  doc.rect(x + s * 0.5, y + s * 0.22, s * 0.38, s * 0.22).fill();
  doc.fillColor(color);
  doc.circle(x + s * 0.27, y + s * 0.84, s * 0.1).fill();
  doc.circle(x + s * 0.73, y + s * 0.84, s * 0.1).fill();
  doc.restore();
}

function iconPin(doc: Doc, x: number, y: number, s: number, color: string): void {
  doc.save().fillColor(color);
  doc.circle(x + s / 2, y + s * 0.36, s * 0.34).fill();
  doc.moveTo(x + s * 0.2, y + s * 0.54).lineTo(x + s / 2, y + s).lineTo(x + s * 0.8, y + s * 0.54).closePath().fill();
  doc.fillColor('#FFFFFF').circle(x + s / 2, y + s * 0.36, s * 0.13).fill();
  doc.restore();
}

function iconClock(doc: Doc, x: number, y: number, s: number, color: string): void {
  doc.save().lineWidth(s * 0.1).strokeColor(color);
  doc.circle(x + s / 2, y + s / 2, s * 0.42).stroke();
  doc.moveTo(x + s / 2, y + s * 0.22).lineTo(x + s / 2, y + s / 2).lineTo(x + s * 0.72, y + s * 0.6).stroke();
  doc.restore();
}

function iconCalendar(doc: Doc, x: number, y: number, s: number, color: string): void {
  doc.save().fillColor(color);
  doc.roundedRect(x, y + s * 0.12, s, s * 0.86, s * 0.1).fill();
  doc.fillColor('#FFFFFF').rect(x + s * 0.08, y + s * 0.38, s * 0.84, s * 0.52).fill();
  doc.fillColor(color).rect(x + s * 0.22, y, s * 0.12, s * 0.26).fill().rect(x + s * 0.66, y, s * 0.12, s * 0.26).fill();
  doc.restore();
}

function iconUser(doc: Doc, x: number, y: number, s: number, color: string): void {
  doc.save().fillColor(color);
  doc.circle(x + s / 2, y + s * 0.3, s * 0.22).fill();
  doc.moveTo(x + s * 0.1, y + s).quadraticCurveTo(x + s * 0.1, y + s * 0.55, x + s / 2, y + s * 0.55).quadraticCurveTo(x + s * 0.9, y + s * 0.55, x + s * 0.9, y + s).closePath().fill();
  doc.restore();
}

function iconSeat(doc: Doc, x: number, y: number, s: number, color: string): void {
  doc.save().fillColor(color);
  doc.roundedRect(x + s * 0.18, y, s * 0.5, s * 0.62, s * 0.12).fill();
  doc.roundedRect(x, y + s * 0.5, s * 0.92, s * 0.3, s * 0.1).fill();
  doc.rect(x + s * 0.12, y + s * 0.78, s * 0.12, s * 0.22).fill().rect(x + s * 0.66, y + s * 0.78, s * 0.12, s * 0.22).fill();
  doc.restore();
}

function iconPhone(doc: Doc, x: number, y: number, s: number, color: string): void {
  doc.save().fillColor(color);
  doc.roundedRect(x + s * 0.22, y, s * 0.56, s, s * 0.12).fill();
  doc.fillColor('#FFFFFF').rect(x + s * 0.3, y + s * 0.12, s * 0.4, s * 0.64).fill().circle(x + s / 2, y + s * 0.88, s * 0.05).fill();
  doc.restore();
}

function iconRupee(doc: Doc, x: number, y: number, s: number, color: string): void {
  doc.save().fillColor(color).circle(x + s / 2, y + s / 2, s / 2).fill();
  doc.lineWidth(s * 0.09).strokeColor('#FFFFFF');
  doc.moveTo(x + s * 0.3, y + s * 0.3).lineTo(x + s * 0.7, y + s * 0.3);
  doc.moveTo(x + s * 0.3, y + s * 0.45).lineTo(x + s * 0.7, y + s * 0.45);
  doc.moveTo(x + s * 0.32, y + s * 0.3).bezierCurveTo(x + s * 0.72, y + s * 0.3, x + s * 0.72, y + s * 0.6, x + s * 0.34, y + s * 0.6);
  doc.moveTo(x + s * 0.34, y + s * 0.6).lineTo(x + s * 0.68, y + s * 0.82).stroke();
  doc.restore();
}

function iconShield(doc: Doc, x: number, y: number, s: number, color: string): void {
  doc.save().fillColor(color);
  doc.moveTo(x + s / 2, y).lineTo(x + s * 0.92, y + s * 0.16).lineTo(x + s * 0.92, y + s * 0.52).bezierCurveTo(x + s * 0.92, y + s * 0.78, x + s * 0.7, y + s * 0.92, x + s / 2, y + s).bezierCurveTo(x + s * 0.3, y + s * 0.92, x + s * 0.08, y + s * 0.78, x + s * 0.08, y + s * 0.52).lineTo(x + s * 0.08, y + s * 0.16).closePath().fill();
  doc.lineWidth(s * 0.1).strokeColor('#FFFFFF').moveTo(x + s * 0.3, y + s * 0.5).lineTo(x + s * 0.45, y + s * 0.65).lineTo(x + s * 0.7, y + s * 0.35).stroke();
  doc.restore();
}

function iconArrow(doc: Doc, x: number, y: number, w: number, color: string): void {
  doc.save().lineWidth(1.4).strokeColor(color).dash(3, { space: 3 });
  doc.moveTo(x, y).lineTo(x + w - 6, y).stroke().undash();
  doc.fillColor(color).moveTo(x + w, y).lineTo(x + w - 7, y - 3.5).lineTo(x + w - 7, y + 3.5).closePath().fill();
  doc.restore();
}

// ===== the page =====

export async function renderTicketPdf(input: TicketPdfInput): Promise<Buffer> {
  const { ticket } = input;
  const doc = new PDFDocument({
    size: 'A4',
    margin: 0,
    info: {
      Title: `Abra Travels ticket ${ticket.pnr}`,
      Author: 'Abra Travels',
      Subject: `${ticket.originName} to ${ticket.destinationName}`,
    },
  });
  const chunks: Buffer[] = [];
  doc.on('data', (chunk: Buffer) => chunks.push(chunk));
  const finished = new Promise<Buffer>((resolve, reject) => {
    doc.on('end', () => resolve(Buffer.concat(chunks)));
    doc.on('error', reject);
  });

  const W = doc.page.width;
  const left = 40;
  const right = W - 40;
  const inner = right - left;
  const zone = ticket.timezone;

  // --- header band with the logo
  doc.rect(0, 0, W, 92).fill(NAVY);
  doc.rect(0, 92, W, 4).fill(SKY);
  doc.save().roundedRect(left, 20, 52, 52, 12).fill('#FFFFFF').restore();
  doc.image(Buffer.from(ABRA_LOGO_PNG_BASE64, 'base64'), left + 4, 24, { fit: [44, 44], align: 'center', valign: 'center' });
  doc.fillColor('#FFFFFF').font('Helvetica-Bold').fontSize(20).text('Abra Travels', left + 66, 28, { lineBreak: false });
  doc.font('Helvetica').fontSize(10).fillColor('#B9D3E8').text('E-ticket', left + 66, 54, { lineBreak: false });
  doc.font('Helvetica-Bold').fontSize(9).fillColor('#B9D3E8').text('BOOKING REFERENCE (PNR)', right - 200, 26, { width: 200, align: 'right', lineBreak: false });
  doc.font('Helvetica-Bold').fontSize(22).fillColor('#FFFFFF').text(ticket.pnr, right - 200, 42, { width: 200, align: 'right', lineBreak: false });
  const statusText = ticket.status === 'CONFIRMED' ? 'CONFIRMED' : ticket.status.replace(/_/g, ' ');
  doc.save().roundedRect(right - 92, 70, 92, 16, 8).fill(ticket.status === 'CONFIRMED' ? GREEN : ORANGE).restore();
  doc.font('Helvetica-Bold').fontSize(8).fillColor('#FFFFFF').text(statusText, right - 92, 74, { width: 92, align: 'center', lineBreak: false });

  // --- the journey
  let y = 116;
  iconBus(doc, left, y, 18, BLUE);
  doc.font('Helvetica-Bold').fontSize(11).fillColor(INK).text(`${ticket.operatorName}${ticket.busTypeName ? '  |  ' + ticket.busTypeName : ''}`, left + 28, y + 3, { lineBreak: false });
  y += 34;
  doc.font('Helvetica-Bold').fontSize(20).fillColor(INK).text(ticket.originName, left, y, { width: 190, lineBreak: false });
  iconArrow(doc, left + 205, y + 12, 90, MUTED);
  doc.font('Helvetica-Bold').fontSize(20).fillColor(INK).text(ticket.destinationName, left + 310, y, { width: 190, lineBreak: false });
  y += 30;
  iconClock(doc, left, y + 1, 12, MUTED);
  doc.font('Helvetica').fontSize(9.5).fillColor(MUTED).text(`Departs ${timeText(ticket.departureAt, zone)}`, left + 18, y + 2, { lineBreak: false });
  doc.text(`Arrives ${timeText(ticket.arrivalAt, zone)}`, left + 310, y + 2, { lineBreak: false });
  y += 15;
  iconCalendar(doc, left, y + 1, 12, MUTED);
  doc.text(`Journey time ${durationText(ticket.durationMinutes)}`, left + 18, y + 2, { lineBreak: false });
  y += 28;

  // --- boarding and dropping
  const boxH = 70;
  for (const [index, point, title, color] of [
    [0, ticket.boarding, 'BOARDING POINT', GREEN],
    [1, ticket.dropping, 'DROPPING POINT', ORANGE],
  ] as const) {
    const bx = left + index * (inner / 2 + 6);
    const bw = inner / 2 - 6;
    doc.save().roundedRect(bx, y, bw, boxH, 8).fill(SOFT).restore();
    iconPin(doc, bx + 12, y + 12, 16, color);
    doc.font('Helvetica-Bold').fontSize(8).fillColor(MUTED).text(title, bx + 36, y + 11, { lineBreak: false });
    doc.font('Helvetica-Bold').fontSize(11).fillColor(INK).text(point.name || '-', bx + 36, y + 24, { width: bw - 48, lineBreak: false, ellipsis: true });
    doc.font('Helvetica').fontSize(8.5).fillColor(MUTED).text(timeText(point.time, zone), bx + 36, y + 40, { width: bw - 48, lineBreak: false });
    if (point.address) doc.text(point.address, bx + 36, y + 52, { width: bw - 48, height: 12, ellipsis: true });
  }
  y += boxH + 16;

  // --- passengers and the QR
  const qrSize = 104;
  const tableW = inner - qrSize - 24;
  iconUser(doc, left, y, 13, BLUE);
  doc.font('Helvetica-Bold').fontSize(11).fillColor(INK).text('Passengers', left + 20, y + 1, { lineBreak: false });
  const tableTop = y + 22;
  doc.save().rect(left, tableTop, tableW, 18).fill(NAVY).restore();
  doc.font('Helvetica-Bold').fontSize(8.5).fillColor('#FFFFFF');
  doc.text('SEAT', left + 10, tableTop + 5, { lineBreak: false });
  doc.text('NAME', left + 64, tableTop + 5, { lineBreak: false });
  doc.text('AGE', left + tableW - 110, tableTop + 5, { lineBreak: false });
  doc.text('GENDER', left + tableW - 70, tableTop + 5, { lineBreak: false });
  let rowY = tableTop + 18;
  ticket.passengers.forEach((passenger, index) => {
    if (index % 2 === 1) doc.save().rect(left, rowY, tableW, 22).fill(SOFT).restore();
    iconSeat(doc, left + 8, rowY + 5, 12, BLUE);
    doc.font('Helvetica-Bold').fontSize(10).fillColor(INK).text(passenger.seatId, left + 26, rowY + 6, { lineBreak: false });
    doc.font('Helvetica').fontSize(10).text(passenger.name, left + 64, rowY + 6, { width: tableW - 190, lineBreak: false, ellipsis: true });
    doc.text(String(passenger.age), left + tableW - 110, rowY + 6, { lineBreak: false });
    doc.text(passenger.gender.charAt(0) + passenger.gender.slice(1).toLowerCase(), left + tableW - 70, rowY + 6, { lineBreak: false });
    rowY += 22;
  });
  doc.save().lineWidth(0.8).strokeColor(LINE).rect(left, tableTop, tableW, rowY - tableTop).stroke().restore();

  const qrX = right - qrSize;
  const qrPng = await toBuffer(ticket.qrPayload, { errorCorrectionLevel: 'M', margin: 1, width: 400 });
  doc.save().roundedRect(qrX - 6, y - 4, qrSize + 12, qrSize + 34, 8).lineWidth(0.8).strokeColor(LINE).stroke().restore();
  doc.image(qrPng, qrX, y, { width: qrSize, height: qrSize });
  doc.font('Helvetica-Bold').fontSize(8).fillColor(MUTED).text('SHOW AT BOARDING', qrX - 6, y + qrSize + 6, { width: qrSize + 12, align: 'center', lineBreak: false });
  doc.font('Helvetica').fontSize(8).text(ticket.pnr, qrX - 6, y + qrSize + 18, { width: qrSize + 12, align: 'center', lineBreak: false });
  y = Math.max(rowY, y + qrSize + 34) + 12;

  // --- what was paid, and who to call
  const colW = inner / 2 - 8;
  iconRupee(doc, left, y, 14, BLUE);
  doc.font('Helvetica-Bold').fontSize(11).fillColor(INK).text('Payment', left + 20, y + 1, { lineBreak: false });
  const amounts: Array<[string, string]> = [
    ['Fare', rs(ticket.baseFarePaise)],
    ['GST', rs(ticket.gstPaise)],
    ['Platform fee', rs(ticket.convenienceFeePaise)],
  ];
  if (ticket.discountPaise > 0) amounts.push(['Discount', `- ${rs(ticket.discountPaise)}`]);
  let ay = y + 22;
  for (const [label, value] of amounts) {
    doc.font('Helvetica').fontSize(9.5).fillColor(MUTED).text(label, left, ay, { lineBreak: false });
    doc.fillColor(INK).text(value, left, ay, { width: colW, align: 'right', lineBreak: false });
    ay += 15;
  }
  doc.save().lineWidth(0.8).strokeColor(LINE).moveTo(left, ay + 1).lineTo(left + colW, ay + 1).stroke().restore();
  doc.font('Helvetica-Bold').fontSize(11).fillColor(INK).text('Total paid', left, ay + 7, { lineBreak: false });
  doc.text(rs(ticket.paidPaise), left, ay + 7, { width: colW, align: 'right', lineBreak: false });

  const cx = left + inner / 2 + 8;
  iconPhone(doc, cx, y, 14, BLUE);
  doc.font('Helvetica-Bold').fontSize(11).fillColor(INK).text('Contact', cx + 20, y + 1, { lineBreak: false });
  let cy = y + 22;
  const contacts: Array<[string, string]> = [['Operator', ticket.operatorName]];
  if (ticket.operatorPhone) contacts.push(['Operator phone', ticket.operatorPhone]);
  if (input.supportPhone) contacts.push(['Abra support', input.supportPhone]);
  if (input.supportEmail) contacts.push(['Support email', input.supportEmail]);
  contacts.push(['Ticket sent to', ticket.contactEmail]);
  for (const [label, value] of contacts) {
    doc.font('Helvetica').fontSize(9.5).fillColor(MUTED).text(label, cx, cy, { lineBreak: false });
    doc.fillColor(INK).text(value, cx, cy, { width: colW, align: 'right', lineBreak: false, ellipsis: true });
    cy += 15;
  }
  y = Math.max(ay + 30, cy) + 8;

  // --- cancellation policy of this booking
  if (input.policy.length > 0) {
    iconClock(doc, left, y, 13, BLUE);
    doc.font('Helvetica-Bold').fontSize(11).fillColor(INK).text('Cancellation policy', left + 20, y + 1, { lineBreak: false });
    y += 22;
    const sorted = [...input.policy].sort((a, b) => b.hoursBefore - a.hoursBefore);
    sorted.forEach((step, index) => {
      const next = sorted[index + 1];
      const window =
        index === 0
          ? `${step.hoursBefore} hours or more before departure`
          : `${step.hoursBefore} to ${sorted[index - 1]?.hoursBefore ?? step.hoursBefore} hours before departure`;
      const text = step.hoursBefore === 0 && index > 0 ? `Less than ${sorted[index - 1]?.hoursBefore ?? 0} hours before departure` : window;
      void next;
      doc.font('Helvetica').fontSize(9.5).fillColor(INK).text(text, left + 6, y, { lineBreak: false });
      doc.font('Helvetica-Bold').fillColor(step.refundPct === 0 ? ORANGE : GREEN).text(`${step.refundPct}% refund`, left, y, { width: inner, align: 'right', lineBreak: false });
      y += 13;
    });
    y += 6;
  }

  // --- terms (the heading never sits alone at the bottom of a page)
  if (y > doc.page.height - 140) {
    doc.addPage({ size: 'A4', margin: 0 });
    y = 40;
  }
  iconShield(doc, left, y, 13, BLUE);
  doc.font('Helvetica-Bold').fontSize(11).fillColor(INK).text('Terms and conditions', left + 20, y + 1, { lineBreak: false });
  y += 20;
  doc.font('Helvetica').fontSize(7.5).fillColor(MUTED);
  (input.terms ?? DEFAULT_TERMS).forEach((term, index) => {
    const height = doc.heightOfString(term, { width: inner - 16 });
    if (y + height > doc.page.height - 56) {
      doc.addPage({ size: 'A4', margin: 0 });
      y = 40;
      doc.font('Helvetica').fontSize(7.5).fillColor(MUTED);
    }
    doc.text(`${index + 1}.`, left, y, { lineBreak: false });
    doc.text(term, left + 16, y, { width: inner - 16 });
    y += height + 3;
  });

  // --- footer on the last page
  const footY = doc.page.height - 36;
  doc.save().rect(0, footY - 8, W, 44).fill(SOFT).restore();
  doc.font('Helvetica').fontSize(8).fillColor(MUTED).text('This is a computer generated ticket and needs no signature.  Abra Travels', left, footY, { width: inner, align: 'center', lineBreak: false });

  doc.end();
  return finished;
}
