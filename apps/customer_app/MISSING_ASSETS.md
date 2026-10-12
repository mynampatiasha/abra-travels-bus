# Missing assets

Placeholders still in use. Nothing here may ship as it is.

| Where | What is missing | Needed from | Used by |
| --- | --- | --- | --- |
| `pubspec.yaml` (fonts) | Inter font files, weights 400 / 600 / 800 (`assets/fonts/Inter-*.ttf`). The app uses the platform font until they are added. | Design | Every screen |
| Seat map, "Front" marker | Steering-wheel icon. A bus icon (`Icons.directions_bus_rounded`) stands in. | Design | Seat selection |
| Hold-expired screen | Illustration (an hourglass icon, `Icons.timer_off_rounded`, stands in). | Design | Seat hold expired |
| Payment method marks | Official logos of GPay, PhonePe, Paytm, BHIM, Amazon Pay and the banks (SBI, HDFC, ICICI, Axis, Kotak). A coloured letter tile stands in for each. | Brand guidelines / design | Payment |
| Payment: "More banks" | The prototype's "More banks" chip is not built (no bank list from the backend yet). | Backend | Payment |
| Ticket PDF fonts | Bundled Noto Sans fonts for Hindi, Telugu, Kannada, Tamil, Malayalam, Marathi and Bengali names (the PDF uses Roboto, which has Latin only). | Design | Ticket PDF |
| Ticket: "Add to calendar" | Opens a Google Calendar link; a native calendar plugin is not added. | Product decision | Booking confirmed |
| My trips empty states and guest card | Illustrations (a bus icon on the gradient disc stands in). | Design | My trips |
| Live tracking map | A real map (Google Maps or Mappls) with its API key. A drawn placeholder (street shapes, route, bus) is shown instead; nothing on it is a real position. | Product decision and key | Live tracking |
| Women safety | The official safety-desk number and the helpline list (1091, 112, 108 are public; 1800 123 4567 is a sample). | Operations | Women safety |
| Notifications and offers | Bell and tag illustrations for the empty states (an icon on the gradient disc stands in) and real banner artwork for the offers carousel (gradients stand in). | Design | Notifications, Offers |
| Seat data | All seats come from `MockSeatRepository` (sample layout, fares and availability). | Backend | Seat selection |
| Seat hold, coupons, cancellation policy | Come from `MockBookingRepository` (10-minute hold, coupon `ABRA100` = Rs 100 off, a 90 / 50 / 0 % policy). | Backend | Boarding, passengers, review |

Official brand logos (Google, Apple, WhatsApp), illustrations, banners, bus photos
and operator logos are not used by the screens built so far; they will be listed
here when the screens that need them are built.
