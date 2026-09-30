# WhatsApp and AI Assistant Architecture

```
WhatsApp user ─▶ Provider (Meta Cloud API / BSP) ─▶ POST /webhooks/whatsapp/:provider (signature check)
                                                     └▶ BullMQ "whatsapp-inbound" ─▶ ChatbotOrchestrator
                                                                                        │
                    identify audience by phone: CUSTOMER / OPERATOR (operator_users) / ADMIN (users)
                                                                                        │
                                           AiProvider (Claude) with a fixed tool set per audience
                                                                                        │
                                           Tools = backend services (same permission + scope checks)
                                                                                        │
                                      reply rendered in session language ─▶ WhatsAppProvider.send()
```

## Guardrails (hard rules in code, not only in the prompt)

- The AI can only answer transactional questions through tools. Tool results are the only source for availability, prices, seat state, booking, payment and refund status. If a tool fails, the reply says the information is unavailable.
- Tools are read-only except `createSeatLockForCustomer` and `createPaymentLink`, which go through the normal services. The AI never confirms bookings, marks payments or changes inventory. A booking completes only when the customer pays on the payment link and the server verifies it.
- Each tool enforces the caller's identity: a customer can only read bookings linked to their verified phone number; booking details from an unknown number require PNR + OTP.
- Operator and admin bots require the number to be registered to an active user, plus a session OTP every 24 hours. Sensitive actions (cancel trip, approve refund) are **not available** in WhatsApp; the bot sends a deep link to the authenticated app instead.
- All tool calls are logged in `chatbot_messages.toolCalls` (arguments and result summary, PII redacted).
- Conversation language = detected or selected language; replies use translated templates where a template exists.

## Customer tools

`searchTrips(from, to, date, timeWindow)`, `getTripDetails`, `getSeatAvailabilitySummary`, `getBookingByPnr`, `listMyBookings`, `getTicketLink`, `getCancellationQuote`, `getRefundStatus`, `getLiveTripStatus`, `getFaqAnswer`, `createSupportTicket`, `startSafetyReport`, `createSeatLockForCustomer` + `createPaymentLink`.

Example: *"I need a bus from Bengaluru to Tirupati tomorrow night"* → AI extracts `{from: bengaluru, to: tirupati, date: <tomorrow>, timeWindow: 18:00–23:59}` → calls `searchTrips` → replies with the top real results and a "select seats" link into the customer app.

## Operator tools

`getTodaysTrips`, `getTripBookingCount`, `getAvailableSeats`, `getTripPassengerCount`, `getRevenueSummary`, `getSettlementStatus`, `reportBusIssue` (creates a support ticket).

## Admin bot

Mostly outbound: critical alerts, daily summary (bookings, revenue, failures), operator approval requests (with app link), safety incidents.

## Provider abstraction

`WhatsAppProvider { sendTemplate(), sendText(), sendInteractive(), verifyWebhook(), parseInbound() }` with `MetaCloudWhatsAppProvider` and `DevelopmentWhatsAppProvider` (writes to a "WhatsApp test inbox" screen in the admin app). Credentials are server-side only.

## In-app AI assistant

The customer app assistant uses the same orchestrator and tool set via `POST /assistant/messages`.
