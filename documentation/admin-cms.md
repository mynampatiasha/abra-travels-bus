# Admin CMS, Marketing and Platform Controls

## Banners

- Fields: see `banners` in database-architecture.md. Images are uploaded via pre-signed URL (desktop 1920×600, mobile 800×600, max 1 MB, webp/jpg/png, validated server-side).
- Lifecycle: `DRAFT → SCHEDULED → PUBLISHED → ARCHIVED`. `GET /banners` returns only `PUBLISHED` banners where `startsAt ≤ now < endsAt`, so expired banners disappear automatically without depending on a job. A daily job moves expired banners to `ARCHIVED`.
- Targeting: placement, routes, operators, audience (all / new users / logged-in).
- Ordering: priority desc, then sortOrder.
- Analytics: impression and click events → Redis counters → flushed every minute to `banner_daily_metrics`. Conversion = booking within 24 h of a click in the same session. CTR computed on the analytics screen.
- Actions: create, edit, preview (desktop + mobile), publish, unpublish, schedule, duplicate, archive — each permission-controlled.

## Offers and coupons

- Coupon validation runs only on the backend, at booking creation and at payment-order creation: active, within dates, minimum booking amount, route/operator/bus-type restrictions, new-user rule, total usage limit, per-customer limit.
- Usage limit enforced atomically: `coupons.updateOne({ _id, usedCount: { $lt: usageLimit } }, { $inc: { usedCount: 1 } })` when reserving; released if the booking expires or fails.
- Discount = min(computed, maxDiscount). Who funds the discount (platform or operator) is recorded for settlement.

## Content

FAQs, terms, privacy, cancellation policy, safety info, help centre, contact info, footer, announcements, travel guides, popular routes. Draft/publish with version history. Publishing triggers on-demand revalidation of the affected Next.js pages.

## System settings

Grouped keys in `system_settings`: company, booking (seat-lock seconds, max seats, sales cut-off), cancellation slabs, refund approval mode, payment (gateway selection — secrets stay in environment/secret manager), notification providers, languages, currency, tax/fees, commission defaults, settlement cycle, support and safety contacts, tracking intervals, API rate limits, security (MFA required, session length). Sensitive keys require `settings.edit` + reason + audit.

## Feature flags

`live_tracking, whatsapp_chatbot, ai_support, women_safety, partner_api, dynamic_pricing, mobile_app, driver_app, advanced_analytics`. Checked server-side (`FeatureFlagService.isEnabled`) and exposed to apps via `GET /app-config`.

## Maintenance mode

Scopes: global, customer, operator, partner, admin. Holders of `maintenance.manage` always pass the guard, so administrators cannot lock themselves out. Supports a schedule window, per-language message and countdown. Enforced by `MaintenanceModeGuard`; apps show a maintenance screen from `GET /app-config`.
