import { AuthenticationModule } from './authentication/authentication.module';
import { UsersModule } from './users/users.module';
import { CustomersModule } from './customers/customers.module';
import { SessionsModule } from './sessions/sessions.module';
import { RbacModule } from './rbac/rbac.module';
import { OperatorsModule } from './operators/operators.module';
import { OperatorStaffModule } from './operator-staff/crew_client_manage';
import { OperatorPortalUsersModule } from './operator-staff/operator-staff.module';
import { BusesModule } from './buses/buses.module';
import { BusTypesModule } from './bus-types/bus-types.module';
import { DocumentTypesModule } from './document-types/document-types.module';
import { OnboardingModule } from './onboarding/onboarding.module';
import { AmenitiesModule } from './amenities/amenities_admin_manage';
import { CatalogueSharedModule } from './catalogue-shared/catalogue_shared_manage';
import { PlaceRequestsModule } from './locations/places_admin_manage';
import { CompanyClientModule } from './onboarding/kyc_client_manage';
import { OperatorsAdminModule } from './operators/operators_admin_manage';
import { PayoutCfgModule } from './settlements/payout_cfg_admin_manage';
import { CitiesModule } from './cities/cities.module';
import { LocationsModule } from './locations/locations.module';
import { RoutesModule } from './routes/routes.module';
import { SchedulesModule } from './schedules/schedules.module';
import { TripsModule } from './trips/trips.module';
import { FaresModule } from './fares/fares.module';
import { BookingsModule } from './bookings/bookings.module';
import { PassengersModule } from './passengers/passengers.module';
import { CouponsModule } from './coupons/coupons.module';
import { TicketsModule } from './tickets/tickets.module';
import { CheckInModule } from './check-in/check-in.module';
import { PaymentsModule } from './payments/payments.module';
import { RefundsModule } from './refunds/refunds.module';
import { ReconciliationModule } from './reconciliation/reconciliation.module';
import { CommissionsModule } from './commissions/commission_admin_manage';
import { SettlementsModule } from './settlements/settlements.module';
import { PartnersModule } from './partners/partners.module';
import { ApiClientsModule } from './api-clients/api-clients.module';
import { PartnerWebhooksModule } from './partner-webhooks/partner-webhooks.module';
import { NotificationsModule } from './notifications/notifications.module';
import { NotificationTemplatesModule } from './notification-templates/notification-templates.module';
import { EventRouterModule } from './notifications/event_router_core';
import { WhatsappModule } from './whatsapp/whatsapp.module';
import { MessagesModule } from './messages/messages_admin_manage';
import { RealtimeModule } from './realtime/live_updates_channel';
import { ChatbotModule } from './chatbot/assistant_chat';
import { TripOperationsModule } from './trip-operations/trip-operations.module';
import { LiveTrackingModule } from './live-tracking/live-tracking.module';
import { WomenSafetyModule } from './women-safety/women-safety.module';
import { SupportModule } from './support/support.module';
import { AdminBannersModule } from './admin-banners/admin-banners.module';
import { OffersModule } from './offers/offers.module';
import { ContentModule } from './content/content.module';
import { PopularRoutesModule } from './popular-routes/popular-routes.module';
import { TranslationsModule } from './translations/translations.module';
import { AuditLogsAdminModule } from './audit-logs/audit_log_admin_manage';
import { AuditLogsModule } from './audit-logs/audit-logs.module';
import { FilesModule } from './files/files.module';
import { SystemSettingsModule } from './system-settings/system-settings.module';
import { FeatureFlagsModule } from './feature-flags/flags_admin_manage';
import { ReportsModule } from './reports/reports.module';
import { AnalyticsModule } from './analytics/analytics.module';
import { StaffAdminManageModule } from './rbac/staff_admin_manage';

/**
 * Every domain module of the modular monolith, grouped as in architecture.md �5.
 * Each module owns its collections; other modules call its service, never its repository.
 */
export const DOMAIN_MODULES = [
  // Identity
  AuthenticationModule,
  UsersModule,
  CustomersModule,
  SessionsModule,
  RbacModule,
  // Supply
  OperatorsModule,
  OperatorStaffModule,
  OperatorPortalUsersModule,
  BusesModule,
  BusTypesModule,
  DocumentTypesModule,
  OnboardingModule,
  CitiesModule,
  LocationsModule,
  RoutesModule,
  SchedulesModule,
  TripsModule,
  FaresModule,
  // Inventory & booking
  BookingsModule,
  PassengersModule,
  CouponsModule,
  TicketsModule,
  CheckInModule,
  // Money
  PaymentsModule,
  RefundsModule,
  ReconciliationModule,
  CommissionsModule,
  SettlementsModule,
  // Channels
  PartnersModule,
  ApiClientsModule,
  PartnerWebhooksModule,
  NotificationsModule,
  NotificationTemplatesModule,
  WhatsappModule,
  MessagesModule,
  RealtimeModule,
  ChatbotModule,
  // Operations
  TripOperationsModule,
  LiveTrackingModule,
  WomenSafetyModule,
  SupportModule,
  // Content
  AdminBannersModule,
  OffersModule,
  ContentModule,
  PopularRoutesModule,
  TranslationsModule,
  // Platform
  AuditLogsModule,
  AuditLogsAdminModule,
  FilesModule,
  SystemSettingsModule,
  FeatureFlagsModule,
  ReportsModule,
  AnalyticsModule,
  CatalogueSharedModule,
  AmenitiesModule,
  PlaceRequestsModule,
  OperatorsAdminModule,
  CompanyClientModule,
  EventRouterModule,
  StaffAdminManageModule,
  PayoutCfgModule,
];
