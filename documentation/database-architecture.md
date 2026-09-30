# Database Architecture (MongoDB)

MongoDB 7+ running as a **replica set** (required for multi-document transactions). All collections use `snake_case` plural names, `_id: ObjectId`, `createdAt`, `updatedAt`. Money is stored as **integer paise** (`amountPaise`) to avoid floating-point errors. Times are UTC `Date`; the trip's `timezone` (default `Asia/Kolkata`) is stored for display.

Every tenant-owned collection has `operatorId` and a compound index that starts with `operatorId`.

Legend: **U** = unique index, **I** = index, **TTL** = expiring index.

---

## 1. Identity and access

| Collection | Key fields | Indexes |
|---|---|---|
| `users` | name, email, phone, passwordHash (argon2id), userType (`STAFF`,`OPERATOR_STAFF`,`DRIVER`,`PARTNER_USER`,`CUSTOMER`), roleIds[], operatorId?, partnerId?, dataScope {type, operatorIds[]}, status (`ACTIVE`,`INVITED`,`SUSPENDED`,`DEACTIVATED`), permissionVersion, mfa {enabled, secretEncrypted}, preferredLanguage, lastLoginAt | U email (partial), U phone (partial), I operatorId+status |
| `roles` | key (`BOOKING_STAFF`), name, description, audience (`PLATFORM`,`OPERATOR`,`PARTNER`,`CUSTOMER`,`FIELD`), permissionKeys[], isSystemRole, operatorId? (operator-defined custom roles) | U key+operatorId |
| `permissions` | key (`bookings.cancel`), module, action, description, audience[], isSensitive | U key |
| `permission_overrides` | userId, permissionKey, effect (`ALLOW`,`DENY`), reason, grantedBy | U userId+permissionKey |
| `auth_sessions` | userId, refreshTokenHash, tokenFamilyId, deviceName, ip, userAgent, expiresAt, revokedAt | I userId, TTL expiresAt |
| `otp_challenges` | target (phone/email), purpose, codeHash, attempts, expiresAt, consumedAt | I target+purpose, TTL expiresAt |
| `customers` | userId, emergencyContacts[], notificationPreferences, safetyPreferences, marketingConsent | U userId |
| `saved_passengers` | customerId, name, age, gender | I customerId |

## 2. Operators and fleet

| Collection | Key fields | Indexes |
|---|---|---|
| `operators` | companyName, ownerName, phone, email, address, gstin, pan, bankAccount (encrypted), contacts {technical, operations}, status (`PENDING_APPROVAL`,`ACTIVE`,`REJECTED`,`SUSPENDED`), approvedBy, approvedAt | U gstin (partial), I status |
| `operator_documents` | operatorId, documentType, storageKey, verificationStatus | I operatorId |
| `bus_types` | key (`AC_SLEEPER`), isAc, berthType (`SEATER`,`SLEEPER`,`SEMI_SLEEPER`,`MIXED`) | U key |
| `buses` | operatorId, registrationNumber, name, busTypeId, amenities[], activeSeatLayoutVersionId, status | U registrationNumber, I operatorId+status |
| `bus_documents` | operatorId, busId, documentType, storageKey, expiresOn | I busId |
| `seat_layouts` | operatorId, name, currentVersionId | I operatorId |
| `seat_layout_versions` | seatLayoutId, operatorId, version, decks [{deck:`LOWER`/`UPPER`, rows, columns}], seats [{seatKey:`L-A1`, label:`A1`, deck, row, column, rowSpan, columnSpan, seatType, genderRestriction, priceCategory, isBookable}], totalSeats, **immutable after first use** | U seatLayoutId+version |
| `drivers` | operatorId, userId, fieldRole (`DRIVER`,`CONDUCTOR`), licenseNumber (encrypted), phone, status | I operatorId |

Layout versions are never edited once any trip references them. Editing a layout creates a new version.

## 3. Geography, routes and schedules

| Collection | Key fields | Indexes |
|---|---|---|
| `cities` | name, slug, state, translations {kn, te, ...}, location (GeoJSON Point) | U slug, text name |
| `locations` | operatorId?, cityId, name, address, landmark, location (Point), contactPhone, instructions | 2dsphere location, I cityId |
| `routes` | operatorId, originCityId, destinationCityId, name, distanceKm, estimatedDurationMinutes, status | I operatorId, I originCityId+destinationCityId |
| `route_stops` | routeId, operatorId, cityId, sequence, offsetMinutes, distanceFromOriginKm | U routeId+sequence |
| `route_points` | routeId, operatorId, locationId, cityId, pointType (`BOARDING`,`DROPPING`,`BOTH`), offsetMinutes | I routeId+pointType |
| `schedules` | operatorId, routeId, busId, departureTimeLocal, recurrence {type:`DAILY`/`WEEKLY`/`DATES`, weekdays[], dates[]}, validFrom, validTo, holidayExceptions[], fareRuleSetId, status | I operatorId+status |

## 4. Trips, fares and inventory (transaction-critical)

| Collection | Key fields | Indexes |
|---|---|---|
| `trips` | operatorId, scheduleId?, routeId, busId, seatLayoutVersionId, travelDate (YYYY-MM-DD, local), departureAt, arrivalAt, originCityId, destinationCityId, stopCityIds[], boardingPoints[] (snapshot with times), droppingPoints[] (snapshot), fareRuleSetVersionId, driverIds[], status (see state machines), publishedAt, seatCounts {total, available, locked, booked, blocked}, cancellationPolicyId, trackingStatus | **I originCityId+destinationCityId+travelDate+status** (search), I operatorId+travelDate, I busId+departureAt |
| `trip_seat_inventory` | tripId, operatorId, seatKey, seatLabel, deck, seatType, genderRestriction, priceCategory, **status** (`AVAILABLE`,`LOCKED`,`BOOKED`,`BLOCKED`), lock {lockId, holderType, holderId, channel, partnerId?, expiresAt}, bookingId?, bookingSeatId?, fareSnapshotPaise, version, lastChangedAt, lastChangedBy | **U tripId+seatKey**, I tripId+status, I lock.expiresAt (partial status=LOCKED) |
| `seat_lock_groups` | lockId, tripId, seatKeys[], holderType (`CUSTOMER`,`PARTNER`,`OPERATOR_STAFF`), holderId, channel, idempotencyKey, expiresAt, status (`ACTIVE`,`CONSUMED`,`RELEASED`,`EXPIRED`) | U lockId, U holderId+idempotencyKey, I status+expiresAt |
| `inventory_events` | tripId, seatKey, fromStatus, toStatus, reason, bookingId?, lockId?, actor, channel, at | I tripId+seatKey+at (append-only audit of every seat change) |
| `fare_rule_sets` | operatorId, routeId?, name, currentVersionId | I operatorId |
| `fare_rule_set_versions` | fareRuleSetId, version, baseFarePaise, priceCategoryFares {}, deckAdjustments {}, weekendAdjustment, holidayDates[], holidayAdjustment, partnerAdjustments [], effectiveFrom, createdBy | U fareRuleSetId+version |

Why one document per seat: MongoDB guarantees atomicity per document, so `findOneAndUpdate({tripId, seatKey, status:'AVAILABLE'}, ...)` is race-free on its own; the unique index `(tripId, seatKey)` makes it impossible to have two inventory rows for one seat. Multi-seat locks run inside one transaction so they succeed or fail as a group.

## 5. Bookings, tickets and check-in

| Collection | Key fields | Indexes |
|---|---|---|
| `bookings` | bookingNumber (`ABR-2026-000123`), pnr (8 chars, no ambiguous letters), customerId?, partnerId?, channel (`WEBSITE`,`MOBILE_APP`,`PARTNER_API`,`OPERATOR_COUNTER`,`WHATSAPP_ASSISTED`), operatorId, tripId, lockId, contact {name, phone, email}, status, pricing {baseFarePaise, seatChargesPaise, taxesPaise, convenienceFeePaise, discountPaise, couponCode?, totalPaise}, cancellationPolicySnapshot, idempotencyKey, expiresAt, confirmedAt, timeline[] | U bookingNumber, U pnr, U customerId+idempotencyKey (partial), U partnerId+idempotencyKey (partial), I tripId+status, I operatorId+createdAt, I customerId+createdAt, I contact.phone |
| `booking_seats` | bookingId, tripId, operatorId, seatKey, seatLabel, passenger {name, age, gender, phone?}, boardingPointId, droppingPointId, farePaise (snapshot), status (`ACTIVE`,`CANCELLED`), checkInStatus, checkedInAt, checkedInBy | U tripId+seatKey (partial: status=ACTIVE) ← **second line of defence against double booking**, I bookingId |
| `tickets` | bookingId, ticketNumber, qrToken (random 128-bit, opaque), pdfStorageKey, generatedAt, version | U qrToken, U bookingId+version |
| `idempotency_records` | scope (`customer:<id>`/`partner:<id>`), key, requestHash, responseStatus, responseBody, lockedUntil | U scope+key, TTL createdAt (48h) |

## 6. Payments, refunds, commission, settlement

| Collection | Key fields | Indexes |
|---|---|---|
| `payments` | bookingId, gateway, gatewayOrderId, gatewayPaymentId?, amountPaise, currency, status, method, failureReason, verifiedAt, verificationSource (`WEBHOOK`,`STATUS_POLL`,`CLIENT_CALLBACK_VERIFIED`), attempts | U gateway+gatewayOrderId, U gatewayPaymentId (partial), I bookingId, I status+createdAt |
| `payment_gateway_events` | gateway, gatewayEventId, eventType, signatureValid, payload (redacted), receivedAt, processedAt, processingResult | **U gateway+gatewayEventId** (duplicate webhook protection) |
| `refunds` | refundNumber, bookingId, paymentId, bookingSeatIds[], amountPaise, cancellationChargePaise, reason (`CUSTOMER_CANCEL`,`TRIP_CANCELLED`,`LOCK_EXPIRED_AFTER_PAYMENT`,`ADMIN`), status, gatewayRefundId, requestedBy, approvedBy?, completedAt | U refundNumber, U gatewayRefundId (partial), I bookingId, I status |
| `commission_rules` | scope {operatorId?, routeId?, partnerId?, channel?}, priority, type (`PERCENT`,`FLAT`), value, validFrom, validTo, version | I scope fields + validFrom |
| `booking_financials` | bookingId, operatorId, partnerId?, grossPaise, platformCommissionPaise, partnerCommissionPaise, taxesPaise, operatorAmountPaise, refundAdjustmentsPaise, commissionRuleId+version, settlementId? | U bookingId, I operatorId+settlementId |
| `settlements` | settlementNumber, operatorId, periodFrom, periodTo, grossPaise, commissionPaise, refundsPaise, adjustmentsPaise, netPaise, status, paidAt, paymentReference | U settlementNumber, I operatorId+periodFrom |

## 7. Partners and API

| Collection | Key fields | Indexes |
|---|---|---|
| `partners` | companyName, contacts, useCase, status, commissionRuleId | I status |
| `api_clients` | partnerId, clientId, clientSecretHash, apiKeyPrefix, apiKeyHash, scopes[], rateLimitPerMinute, environment (`SANDBOX`,`LIVE`), status, expiresAt, rotatedFromId | U clientId, U apiKeyPrefix |
| `partner_webhook_subscriptions` | partnerId, url, secretEncrypted, events[], status | I partnerId |
| `partner_webhook_deliveries` | subscriptionId, eventId, eventType, payload, attempt, nextAttemptAt, responseStatus, status | U subscriptionId+eventId, I status+nextAttemptAt |
| `api_request_logs` | apiClientId?, userId?, method, route, statusCode, durationMs, errorCode, requestId, at | I apiClientId+at, TTL at (90 days) |

## 8. Notifications, messaging, AI

| Collection | Key fields | Indexes |
|---|---|---|
| `notification_templates` | key (`booking.confirmed`), channel, language, version, subject?, body with `{{variables}}`, providerTemplateId, approvalStatus, isActive | U key+channel+language+version |
| `notifications` | recipient {userId?, phone?, email?}, eventType, eventId, channel, language, templateVersion, status (`QUEUED`,`SENT`,`DELIVERED`,`FAILED`), attempts, providerMessageId, lastError | U eventId+channel+recipientKey, I status+createdAt |
| `in_app_notifications` | userId, title, body, deepLink, readAt | I userId+createdAt |
| `push_devices` | userId, platform, token, lastSeenAt | U token |
| `chatbot_sessions` | channel (`WHATSAPP`,`APP`), audience (`CUSTOMER`,`OPERATOR`,`ADMIN`), phone, userId?, language, verifiedAt, state | I phone+channel |
| `chatbot_messages` | sessionId, direction, text, toolCalls[] (name, args, result summary), at | I sessionId+at, TTL at (180 days) |

## 9. Tracking and safety

| Collection | Key fields | Indexes |
|---|---|---|
| `trip_live_status` | tripId, operatorId, lastLocation (Point), accuracyM, speedKmph, heading, recordedAt, receivedAt, deviceId, etaToNextPointMinutes, delayMinutes, trackingState (`LIVE`,`STALE`,`OFFLINE`,`NOT_STARTED`) | U tripId |
| `driver_location_points` | tripId, driverUserId, deviceId, location, accuracyM, speedKmph, heading, recordedAt | I tripId+recordedAt, **TTL recordedAt (30 days)** |
| `safety_incidents` | incidentNumber, type (`SOS`,`UNSAFE_BEHAVIOUR`,`HARASSMENT`,`MEDICAL`,`OTHER`), severity, reporterUserId, bookingId?, tripId?, location?, description, attachments[], status (`OPEN`,`ACKNOWLEDGED`,`ESCALATED`,`RESOLVED`,`CLOSED`), assignedTo, timeline[] | U incidentNumber, I status+severity, I tripId |
| `trip_share_links` | bookingId, tokenHash, createdBy, expiresAt, revokedAt | U tokenHash, TTL expiresAt |

## 10. Content, marketing, platform

| Collection | Key fields | Indexes |
|---|---|---|
| `banners` | title, subtitle (per language), placement (`HOME_HERO`,`HOME_OFFERS`,`ROUTE_PAGE`,`SEARCH_RESULTS`), desktopImageKey, mobileImageKey, cta {label, url}, targeting {routeIds[], operatorIds[], audience}, campaignName, priority, sortOrder, status (`DRAFT`,`SCHEDULED`,`PUBLISHED`,`ARCHIVED`), startsAt, endsAt | I placement+status+startsAt+endsAt |
| `banner_daily_metrics` | bannerId, date, impressions, clicks, conversions | U bannerId+date |
| `offers` | title, description, type, linkedCouponId?, targeting, startsAt, endsAt, status | I status+endsAt |
| `coupons` | code (uppercase), discountType (`PERCENT`,`FLAT`), value, maxDiscountPaise, minBookingPaise, usageLimit, perCustomerLimit, usedCount, restrictions {routeIds[], operatorIds[], busTypeIds[], newUsersOnly}, startsAt, endsAt, status | U code |
| `coupon_redemptions` | couponId, customerId, bookingId, status (`RESERVED`,`REDEEMED`,`RELEASED`) | U couponId+bookingId, I couponId+customerId |
| `content_pages` | slug, type (`FAQ`,`TERMS`,`PRIVACY`,`CANCELLATION_POLICY`,`HELP`,`GUIDE`,`ANNOUNCEMENT`), translations {en:{title, body}, kn:{...}}, status, publishedAt | U slug |
| `popular_routes` | originCityId, destinationCityId, sortOrder, isActive | U originCityId+destinationCityId |
| `translations` | namespace, key, language, value, updatedBy | U namespace+key+language |
| `languages` | code, nativeName, isActive, isDefault | U code |
| `support_tickets` | ticketNumber, customerId?, bookingId?, category, priority, status, assignedTo, notes[], channel | U ticketNumber, I status+priority |
| `audit_logs` | actor {userId, roleKeys, userType}, action (`booking.cancelled`), entityType, entityId, operatorId?, before, after, reason, requestId, ip, userAgent, at | I entityType+entityId+at, I actor.userId+at, I action+at (never deleted by application) |
| `analytics_events` | name, sessionId, userId?, properties (no PII), at | I name+at, TTL at (400 days) |
| `system_settings` | key, value, isSensitive, updatedBy | U key |
| `feature_flags` | key, enabled, audience rules, updatedBy | U key |
| `outbox_events` | eventId, type, aggregateType, aggregateId, payload, status, attempts, availableAt | U eventId, I status+availableAt |

## 11. Transaction boundaries

| Operation | Collections written in one transaction |
|---|---|
| Lock seats | `trip_seat_inventory` (N seats), `seat_lock_groups`, `inventory_events`, `trips.seatCounts` |
| Create booking (pending payment) | `bookings`, `booking_seats`, `coupon_redemptions` (RESERVED), `seat_lock_groups` (extend to payment window) |
| Confirm booking | `trip_seat_inventory` LOCKED→BOOKED (conditional on lockId), `bookings`, `payments`, `coupon_redemptions`, `booking_financials`, `inventory_events`, `outbox_events`, `trips.seatCounts` |
| Cancel booking / seats | `booking_seats`, `bookings`, `trip_seat_inventory` BOOKED→AVAILABLE, `refunds`, `booking_financials`, `inventory_events`, `outbox_events`, `audit_logs` |
| Cancel trip | `trips`, then one transaction **per affected booking** (bounded size) driven by a worker |

Transactions use `readConcern: snapshot`, `writeConcern: majority` and retry on `TransientTransactionError` / `UnknownTransactionCommitResult`.

## 12. Retention

| Data | Retention |
|---|---|
| Bookings, payments, refunds, settlements, audit logs | 8 years (tax/accounting), archived after 2 years |
| GPS points | 30 days (TTL). Latest position kept in `trip_live_status` |
| Chat messages | 180 days |
| API request logs | 90 days |
| Analytics events | 400 days, aggregated tables kept |
| OTP challenges, sessions | TTL at expiry |
| Safety incidents | Retained per legal review (minimum 3 years) |
