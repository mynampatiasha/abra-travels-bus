# Abra Travels customer app

## Repositories and the backend they will need

Screens depend on an abstract repository. The default is a mock with sample
data; connecting the backend means providing the `Api...` implementation in the
repository's provider. Discovery (cities, search, trip) and Home banners
already use the backend.

| Repository (interface) | Mock | Backend endpoint it needs | Status |
| --- | --- | --- | --- |
| `SeatRepository` (`features/booking/repositories/seat_repository.dart`) | `MockSeatRepository` | `GET /trips/:tripId/seats` (public): layout, deck, seat id, fare in paise, status `AVAILABLE` / `BOOKED` / `LADIES_ONLY` / `BLOCKED` | Mock |

| `BookingRepository` (`features/booking/repositories/booking_repository.dart`) | `MockBookingRepository` | `POST /trips/:tripId/seat-locks` (needs sign-in; body `seatKeys`, `boardingPointId`, `droppingPointId`; answers lock id and expiry; 409 `SEAT_NOT_AVAILABLE` when a seat was taken) | Mock |
| | | `POST /coupons/validate` (trip, code, base fare in paise; answers valid + discount in paise) | Mock |
| | | `GET /coupons?tripId=` (codes worth suggesting) | Mock |
| | | `GET /trips/:tripId/policy` (cancellation windows and refund percent) | Mock |

| | | `POST /bookings` (held seats, passengers, contact, GST, coupon code; answers booking id and the amount the backend calculated) | Mock |
| `TicketRepository` (`features/booking/repositories/ticket_repository.dart`) | `MockTicketRepository` (reads bookings made in this run) | `GET /bookings/:id/ticket`: PNR, trip, passengers and seats, points, operator phone, signed QR payload, amount paid | Mock |
| `TripsRepository` (`features/my_trips/repositories/trips_repository.dart`) | `MockTripsRepository` (two upcoming and two completed samples, plus bookings made in this run) | `GET /bookings`, `GET /bookings/:id` (with refund status and UTR), `POST /bookings/:id/cancellations/quote`, `POST /bookings/:id/cancellations` (seats, reason) | Mock |
| `TrackingRepository` (`features/tracking/repositories/tracking_repositories.dart`) | `MockTrackingRepository` (live for 40 s after opening, then "signal lost" until Retry) | `GET /bookings/:id/tracking` (bus number, driver, ETA to the boarding point, last ping time, route progress); polled every 10 s | Mock |
| `SafetyRepository` (same file) | `MockSafetyRepository` | `GET` and `POST /me/emergency-contacts`; `POST /safety/sos` (booking id; the backend adds the live location and alerts contacts, the safety team and the police control room); `POST /safety/sos/:id/cancel` | Mock |
| `SharingRepository` (same file) | `MockSharingRepository` | `GET`, `POST` and `DELETE /bookings/:id/share` (link, people who opened it, expiry one hour after arrival) | Mock |
| `NotificationFeed` (`features/notifications/repositories/notifications_repositories.dart`) | `MockNotificationFeed` (the real `ApiNotificationFeed` over the existing `/notifications` endpoints is written; override `notificationFeedProvider` with `realNotificationFeed` to use it) | `GET /notifications`, `POST /notifications/:id/read`, `POST /notifications/read-all` (already live; the bell in the top bar uses them) | Mock, real one ready |
| `OffersRepository` (same file) | `MockOffersRepository` | `GET /offers` (code, description, valid-till, terms; no sign-in) and `GET /offers/banners`; the backend `offers` module is still empty | Mock |
| `PaymentRepository` (`features/booking/repositories/payment_repository.dart`) | `MockPaymentRepository` | `POST /bookings` (from the seat lock), `POST /payments/orders`, then the payment partner's SDK; confirmation by `GET /bookings/:id` or push. Card details go to the partner's SDK only: the app must never store or log them. | Mock |

Live tracking draws its map through `mapBuilderProvider`
(`features/tracking/widgets/tracking_map.dart`). Until a map SDK and its key are
provided, a drawn placeholder is used; the SDK replaces that one provider.

The refund estimate on the cancel screen comes from `TripsRepository.quote`; the mock
applies the booking policy (`CancellationCalculator`). The mock refund moves from
processing to refunded two minutes after the cancellation and then shows a UTR.

The ticket PDF is built in the app (`services/ticket_pdf.dart`). It fetches Roboto
for the rupee sign; offline it falls back to Helvetica and prints "Rs". Indian-script
names need a Noto font bundled (see `MISSING_ASSETS.md`).

Mock payment test values: UPI id `fail@upi` or card `4000 0000 0000 0002` is
declined (code U30); `timeout@upi` or `4000 0000 0000 0036` gets no confirmation
(seats released); anything else succeeds. Use card `4111 1111 1111 1111`, expiry
any future month, any 3-digit CVV, for a valid card.

The fare breakup (GST 5%, convenience fee, discount) is calculated in the app by
`FareCalculator` for display only; the backend calculates the amount to pay when
the booking is created, and a quote endpoint will replace it.

More rows are added as each feature is built.
