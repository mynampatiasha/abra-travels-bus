# Public Website (Next.js)

A lightweight SEO website. It does **not** duplicate the Flutter booking application and holds **no business logic**. It reads public data from the same NestJS API and hands users over to the Flutter booking app.

## Responsibilities

| Next.js (public_website) | Flutter customer_app |
|---|---|
| Home (hero search form, banners, popular routes, offers, why Abra, safety) | Search results, filters, sort |
| Route landing pages `/bus-tickets/bengaluru-to-tirupati` | Bus details, boarding/dropping selection |
| City pages `/bus-tickets/from-bengaluru` | Seat layout, seat lock |
| Operator pages `/operators/<slug>` | Passenger details, summary, coupon |
| Offers `/offers` | Payment, confirmation, ticket |
| FAQ, help centre, terms, privacy, cancellation policy, safety | My bookings, cancellation, refunds |
| Blog / travel guides `/guides/<slug>` | Profile, tracking, Women Safety, support |
| Contact / support page | AI assistant |
| Ticket lookup landing (links to app) | |

Search submitted on the website redirects to `NEXT_PUBLIC_BOOKING_APP_URL/search?from=bengaluru&to=tirupati&date=2026-10-01` (Flutter web), or opens the mobile app via app links / universal links when installed.

## Rendering

- Next.js App Router with **SSG + ISR**. Route pages revalidate every 15 minutes and on demand when CMS content, popular routes or offers are published (`POST /api/revalidate` with `REVALIDATE_SECRET`, called by the backend).
- Live seat availability is **never** baked into static pages. Route pages show schedule information ("buses from ₹650, departures from 19:00") labelled with the time it was fetched, plus a live "Search buses" call to action.
- Banner impressions and clicks are posted to `POST /api/v1/banners/:id/events`.

## SEO

- Per-page `generateMetadata`: title, description, canonical URL, Open Graph, Twitter card.
- Structured data (JSON-LD): `Organization`, `WebSite` with `SearchAction`, `BreadcrumbList`, `FAQPage`, `BusTrip` on route pages.
- `sitemap.xml` generated from active routes, cities, operators and content pages; `robots.txt` blocks `/api` and preview routes.
- Localized routes `/{locale}/...` for 8 languages, with `hreflang` alternates; English at the root.
- Performance budget: LCP < 2.5 s on 4G, images through `next/image` from the CDN, no client-side booking bundle.

## Structure

```
apps/public_website/
├── app/
│   ├── [locale]/page.tsx                                  home
│   ├── [locale]/bus-tickets/[routeSlug]/page.tsx          route landing page
│   ├── [locale]/bus-tickets/from-[citySlug]/page.tsx
│   ├── [locale]/operators/[operatorSlug]/page.tsx
│   ├── [locale]/offers/page.tsx
│   ├── [locale]/help/[[...slug]]/page.tsx                 FAQ, help, policies from CMS
│   ├── [locale]/guides/[guideSlug]/page.tsx
│   ├── api/revalidate/route.ts
│   ├── sitemap.ts
│   └── robots.ts
├── components/  home-search-form.tsx, promotional-banner-carousel.tsx, popular-route-grid.tsx, route-schedule-summary.tsx, structured-data-script.tsx
├── lib/         abra-public-api-client.ts, booking-app-links.ts, seo-metadata-builder.ts
└── messages/    en.json, kn.json, te.json, hi.json, ta.json, ml.json, mr.json, bn.json
```

The design uses the same Abra tokens (Navy #12304A, Blue #1677C8, Teal #1B8A5A, Orange #F28C28, Gray #F3F5F7) as `shared_ui`.
