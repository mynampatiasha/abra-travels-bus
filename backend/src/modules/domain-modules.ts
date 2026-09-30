import { AuthenticationModule } from './authentication/authentication.module';
import { UsersModule } from './users/users.module';
import { CustomersModule } from './customers/customers.module';
import { SessionsModule } from './sessions/sessions.module';
import { RbacModule } from './rbac/rbac.module';
import { OperatorsModule } from './operators/operators.module';
import { OperatorStaffModule } from './operator-staff/operator-staff.module';
import { BusesModule } from './buses/buses.module';
import { BusTypesModule } from './bus-types/bus-types.module';
import { SeatLayoutsModule } from './seat-layouts/seat-layouts.module';
import { CitiesModule } from './cities/cities.module';
import { LocationsModule } from './locations/locations.module';
import { RoutesModule } from './routes/routes.module';
import { BoardingPointsModule } from './boarding-points/boarding-points.module';
import { SchedulesModule } from './schedules/schedules.module';
import { TripsModule } from './trips/trips.module';
import { FaresModule } from './fares/fares.module';
import { DriversModule } from './drivers/drivers.module';
import { InventoryModule } from './inventory/inventory.module';
import { BookingsModule } from './bookings/bookings.module';
import { PassengersModule } from './passengers/passengers.module';
import { CouponsModule } from './coupons/coupons.module';
import { TicketsModule } from './tickets/tickets.module';
import { CheckInModule } from './check-in/check-in.module';
import { PaymentsModule } from './payments/payments.module';
import { RefundsModule } from './refunds/refunds.module';
import { ReconciliationModule } from './reconciliation/reconciliation.module';
import { CommissionsModule } from './commissions/commissions.module';
import { SettlementsModule } from './settlements/settlements.module';
import { PartnersModule } from './partners/partners.module';
import { ApiClientsModule } from './api-clients/api-clients.module';
import { PartnerWebhooksModule } from './partner-webhooks/partner-webhooks.module';
import { NotificationsModule } from './notifications/notifications.module';
import { NotificationTemplatesModule } from './notification-templates/notification-templates.module';
import { WhatsappModule } from './whatsapp/whatsapp.module';
import { ChatbotModule } from './chatbot/chatbot.module';
import { TripOperationsModule } from './trip-operations/trip-operations.module';
import { LiveTrackingModule } from './live-tracking/live-tracking.module';
import { WomenSafetyModule } from './women-safety/women-safety.module';
import { SupportModule } from './support/support.module';
import { BannersModule } from './banners/banners.module';
import { OffersModule } from './offers/offers.module';
import { ContentModule } from './content/content.module';
import { PopularRoutesModule } from './popular-routes/popular-routes.module';
import { TranslationsModule } from './translations/translations.module';
import { AuditLogsModule } from './audit-logs/audit-logs.module';
import { FilesModule } from './files/files.module';
import { SystemSettingsModule } from './system-settings/system-settings.module';
import { FeatureFlagsModule } from './feature-flags/feature-flags.module';
import { MaintenanceModule } from './maintenance/maintenance.module';
import { ReportsModule } from './reports/reports.module';
import { AnalyticsModule } from './analytics/analytics.module';

/**
 * Every domain module of the modular monolith, grouped as in architecture.md §5.
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
  BusesModule,
  BusTypesModule,
  SeatLayoutsModule,
  CitiesModule,
  LocationsModule,
  RoutesModule,
  BoardingPointsModule,
  SchedulesModule,
  TripsModule,
  FaresModule,
  DriversModule,
  // Inventory & booking
  InventoryModule,
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
  ChatbotModule,
  // Operations
  TripOperationsModule,
  LiveTrackingModule,
  WomenSafetyModule,
  SupportModule,
  // Content
  BannersModule,
  OffersModule,
  ContentModule,
  PopularRoutesModule,
  TranslationsModule,
  // Platform
  AuditLogsModule,
  FilesModule,
  SystemSettingsModule,
  FeatureFlagsModule,
  MaintenanceModule,
  ReportsModule,
  AnalyticsModule,
];
