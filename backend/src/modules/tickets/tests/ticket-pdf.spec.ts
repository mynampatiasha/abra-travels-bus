import { writeFileSync } from 'node:fs';
import { DEFAULT_TERMS, renderTicketPdf, type TicketPdfInput } from '../ticket_pdf';
import { buildQr, readQr } from '../tickets_customer.service';

const ticket: TicketPdfInput['ticket'] = {
  bookingId: '6af0c0ffee0000000000aaaa',
  tripId: '6af0c0ffee0000000000bbbb',
  pnr: 'ABR7K2M9QX',
  status: 'CONFIRMED',
  operatorName: 'Demo Travels',
  operatorPhone: '9000011111',
  busTypeName: 'AC Sleeper',
  originName: 'Hyderabad',
  destinationName: 'Bengaluru',
  travelDate: '2026-11-01',
  timezone: 'Asia/Kolkata',
  departureAt: '2026-11-01T16:00:00.000Z',
  arrivalAt: '2026-11-02T01:00:00.000Z',
  durationMinutes: 540,
  passengers: [
    { name: 'Asha Rao', seatId: '1', age: 31, gender: 'FEMALE' },
    { name: 'Ravi Rao', seatId: '2', age: 34, gender: 'MALE' },
  ],
  boarding: { name: 'Ameerpet Metro', time: '2026-11-01T16:00:00.000Z', address: 'Ameerpet Metro Station, Hyderabad' },
  dropping: { name: 'Majestic', time: '2026-11-02T01:00:00.000Z', address: 'Kempegowda Bus Station, Bengaluru' },
  baseFarePaise: 170000,
  gstPaise: 8500,
  convenienceFeePaise: 4900,
  discountPaise: 10000,
  paidPaise: 173400,
  currency: 'INR',
  contactEmail: 'asha@example.com',
  qrPayload: buildQr('s'.repeat(40), '6af0c0ffee0000000000aaaa', 'ABR7K2M9QX'),
};

const policy = [
  { hoursBefore: 24, refundPct: 90 },
  { hoursBefore: 12, refundPct: 50 },
  { hoursBefore: 0, refundPct: 0 },
];

describe('the ticket PDF', () => {
  it('is a real PDF with the trip on it', async () => {
    const pdf = await renderTicketPdf({ ticket, policy, supportPhone: '1800 000 000', supportEmail: 'help@abra.example' });
    expect(pdf.subarray(0, 5).toString('latin1')).toBe('%PDF-');
    expect(pdf.length).toBeGreaterThan(20_000);
    // Written in plain text inside the file when the document is not compressed: the structure is checked, not the pixels
    expect(pdf.toString('latin1')).toContain('/Type /Page');
    if (process.env.TICKET_PDF_SAMPLE) writeFileSync(process.env.TICKET_PDF_SAMPLE, pdf);
  }, 60_000);

  it('carries the QR text a scanner can verify', () => {
    expect(readQr('s'.repeat(40), ticket.qrPayload)).toEqual({ bookingId: ticket.bookingId, pnr: ticket.pnr });
  });

  it('copes with many passengers, no policy, no discount and long terms without failing', async () => {
    const many = {
      ...ticket,
      discountPaise: 0,
      passengers: Array.from({ length: 6 }, (_, i) => ({ name: `Passenger number ${i + 1} with a rather long name`, seatId: `${i + 1}`, age: 20 + i, gender: 'OTHER' })),
      boarding: { name: 'A very long boarding point name that goes on and on', time: ticket.boarding.time },
    };
    const long = Array.from({ length: 30 }, (_, i) => `${i + 1}. ${DEFAULT_TERMS[i % DEFAULT_TERMS.length] ?? ''}`);
    const pdf = await renderTicketPdf({ ticket: many, policy: [], terms: long });
    expect(pdf.subarray(0, 5).toString('latin1')).toBe('%PDF-');
    // Long terms run on to a second page instead of falling off the first
    expect((pdf.toString('latin1').match(/\/Type \/Page\b/g) ?? []).length).toBeGreaterThanOrEqual(2);
  }, 60_000);
});
