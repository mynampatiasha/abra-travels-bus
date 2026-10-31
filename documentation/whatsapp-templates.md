# WhatsApp message templates

WhatsApp lets a business start a conversation only with a template that Meta has approved. Create each template below in
WhatsApp Manager (Message templates, Create template) with **exactly** this name, language and wording. Keep the blanks
`{{1}}`, `{{2}}` and so on in the same order. Choose the category **Utility**.

The ticket templates have a **document header**: choose Header, Document, and upload any sample PDF. The real ticket PDF is
sent in that place with each message.

The same messages also go out as emails (branded, with the logo), using the email settings in the admin app.

This file is written from `backend/src/modules/messages/message_templates.ts`. Do not edit it by hand: change the template
there and run `UPDATE_WHATSAPP_DOC=1 npm test -- whatsapp-templates-doc` to write it again.

## abra_booking_confirmed

Used for: booking confirmed

- Name: `abra_booking_confirmed`
- Language: `en`
- Category: Utility
- Header: Document (the ticket PDF)
- Footer: none
- Buttons: none

Body:

```
Hello {{1}}, your booking is confirmed.
PNR: {{2}}
Route: {{3}}
Departure: {{4}}
Seats: {{5}}
Boarding point: {{6}}
Amount paid: {{7}}
Your ticket is attached. Show the QR code to the conductor when you board.
```

Blanks, in order:

1. {{1}} = contactName (example: Asha Rao)
2. {{2}} = pnr (example: ABR7K2M9QX)
3. {{3}} = route (example: Hyderabad to Bengaluru)
4. {{4}} = departureText (example: 1 Nov, 9:30 pm)
5. {{5}} = seatsText (example: 1, 2)
6. {{6}} = boardingPoint (example: Ameerpet Metro)
7. {{7}} = amountText (example: Rs 1,734)

## abra_booking_cancelled

Used for: booking cancelled

- Name: `abra_booking_cancelled`
- Language: `en`
- Category: Utility
- Header: none
- Footer: none
- Buttons: none

Body:

```
Your booking {{1}} on {{2}} is cancelled. The refund has started and reaches your account in 5 to 7 working days.
```

Blanks, in order:

1. {{1}} = pnr (example: ABR7K2M9QX)
2. {{2}} = route (example: Hyderabad to Bengaluru)

## abra_refund_processed

Used for: refund paid

- Name: `abra_refund_processed`
- Language: `en`
- Category: Utility
- Header: none
- Footer: none
- Buttons: none

Body:

```
Your refund of {{1}} for booking {{2}} has been processed. Reference: {{3}}. It can take a few working days to reach your account.
```

Blanks, in order:

1. {{1}} = amountText (example: Rs 1,734)
2. {{2}} = pnr (example: ABR7K2M9QX)
3. {{3}} = reference (example: rfnd_Nk3x92)

## abra_payment_failed

Used for: payment failed

- Name: `abra_payment_failed`
- Language: `en`
- Category: Utility
- Header: none
- Footer: none
- Buttons: none

Body:

```
Your payment of {{1}} for {{2}} did not go through. Your seats are held for a short time: please open the app and try again. If money was taken, it is returned automatically.
```

Blanks, in order:

1. {{1}} = amountText (example: Rs 1,734)
2. {{2}} = route (example: Hyderabad to Bengaluru)

## abra_trip_delayed

Used for: trip delayed

- Name: `abra_trip_delayed`
- Language: `en`
- Category: Utility
- Header: none
- Footer: none
- Buttons: none

Body:

```
Your bus on {{1}} is about {{2}} minutes late. Booking {{3}}. You can follow the bus live in the app.
```

Blanks, in order:

1. {{1}} = route (example: Hyderabad to Bengaluru)
2. {{2}} = minutes (example: 25)
3. {{3}} = pnr (example: ABR7K2M9QX)

## abra_boarding_started

Used for: boarding started

- Name: `abra_boarding_started`
- Language: `en`
- Category: Utility
- Header: none
- Footer: none
- Buttons: none

Body:

```
Boarding has started for bus {{1}}. Please reach your boarding point now. Booking {{2}}.
```

Blanks, in order:

1. {{1}} = busRegistration (example: TS09AB1234)
2. {{2}} = pnr (example: ABR7K2M9QX)

## abra_trip_reminder

Used for: trip reminder

- Name: `abra_trip_reminder`
- Language: `en`
- Category: Utility
- Header: none
- Footer: none
- Buttons: none

Body:

```
Reminder: your trip on {{1}} leaves on {{2}} from {{3}}. Booking {{4}}. Please reach the boarding point 15 minutes early and keep a photo ID with you.
```

Blanks, in order:

1. {{1}} = route (example: Hyderabad to Bengaluru)
2. {{2}} = departureText (example: 1 Nov, 9:30 pm)
3. {{3}} = boardingPoint (example: Ameerpet Metro)
4. {{4}} = pnr (example: ABR7K2M9QX)

## abra_feedback_request

Used for: feedback request

- Name: `abra_feedback_request`
- Language: `en`
- Category: Utility
- Header: none
- Footer: none
- Buttons: none

Body:

```
Thank you for travelling with Abra Travels on {{1}} (booking {{2}}). How was your trip? Open the app, go to My trips and rate this journey. It takes less than a minute.
```

Blanks, in order:

1. {{1}} = route (example: Hyderabad to Bengaluru)
2. {{2}} = pnr (example: ABR7K2M9QX)

## abra_support_reply

Used for: support reply

- Name: `abra_support_reply`
- Language: `en`
- Category: Utility
- Header: none
- Footer: none
- Buttons: none

Body:

```
We have replied to your support request {{1}}. Open the Abra Travels app and go to Support to read the reply.
```

Blanks, in order:

1. {{1}} = ticketNumber (example: TK-1042)

## Check list

- 9 templates in all.
- Status in WhatsApp Manager must be **Approved** before the message can be sent; until then it is recorded as failed in Messages sent.
