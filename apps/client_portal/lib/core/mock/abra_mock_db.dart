// ignore_for_file: avoid_redundant_argument_values
/// Central mock data for all client-portal screens.
/// All data is static. Repositories return these wrapped in Future.value.
library;

import 'package:flutter/foundation.dart';

const String kMockOperatorId = 'OP1';

const List<Map<String, dynamic>> kMockOperators = <Map<String, dynamic>>[
  {
    'id': 'OP1',
    'name': 'Kaveri Express',
    'owner': 'Ramesh Kumar',
    'email': 'ramesh@kaveriexpress.in',
    'phone': '+91 98450 12345',
    'city': 'Bengaluru',
    'gst': '29AABCK1234A1Z5',
    'status': 'ACTIVE',
    'kyc': 'APPROVED',
    'rating': '4.6',
    'payout': 'AUTO',
    'bank': {
      'holder': 'Kaveri Express Pvt Ltd',
      'acc': 'XXXXXXXXXXXX9012',
      'ifsc': 'HDFC0001234',
      'status': 'VERIFIED',
    },
    'joined': '2024-01-15T08:00:00.000Z',
  },
];

Map<String, dynamic> get kMockMe =>
    kMockOperators.firstWhere((o) => o['id'] == kMockOperatorId);

const List<Map<String, dynamic>> kMockCities = <Map<String, dynamic>>[
  {'id': 'C1', 'name': 'Bengaluru', 'state': 'Karnataka', 'active': true},
  {'id': 'C2', 'name': 'Hyderabad', 'state': 'Telangana', 'active': true},
  {'id': 'C3', 'name': 'Chennai', 'state': 'Tamil Nadu', 'active': true},
  {'id': 'C4', 'name': 'Mysuru', 'state': 'Karnataka', 'active': true},
  {'id': 'C5', 'name': 'Pune', 'state': 'Maharashtra', 'active': true},
];

const List<Map<String, dynamic>> kMockPlaces = <Map<String, dynamic>>[
  {'id':'PL1','city':'Bengaluru','name':'Majestic Bus Stand','address':'Gubbi Thotadappa Rd','landmark':'Opp KSR Railway Stn','type':'BOTH','active':true},
  {'id':'PL2','city':'Bengaluru','name':'Silk Board Junction','address':'Silk Board Circle','landmark':'Near flyover','type':'BOARDING','active':true},
  {'id':'PL3','city':'Hyderabad','name':'Miyapur Metro Pickup','address':'Miyapur Main Road','landmark':'Metro station exit 2','type':'BOARDING','active':true},
  {'id':'PL4','city':'Hyderabad','name':'MGBS Bus Stand','address':'Mahatma Gandhi Bus Station','landmark':'Central Hyderabad','type':'BOTH','active':true},
  {'id':'PL5','city':'Chennai','name':'Koyambedu Bus Terminus','address':'Koyambedu, Chennai','landmark':'Near Koyambedu Market','type':'DROPPING','active':true},
];

const List<String> kMockBusTypes = <String>[
  'AC Sleeper','AC Seater','Non-AC Sleeper','Volvo Multi-Axle AC','Luxury AC',
];

const List<String> kMockAmenities = <String>[
  'WiFi','Charging Port','Blanket','Water Bottle','Reading Light','Emergency Exit',
];

List<Map<String, dynamic>> kMockBuses = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockCrew = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockRoutes = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockFares = <Map<String, dynamic>>[];

const Map<String, dynamic> kMockCommissionDefault = {'mode':'PERCENT','value':800,'scope':'DEFAULT','target':'Default rule','status':'ACTIVE'};

const List<Map<String, dynamic>> kMockCommissions = [];

const Map<String, dynamic> kMockPayoutConfig = {'fee':500,'defaultMode':'AUTO'};

List<Map<String, dynamic>> kMockSchedules = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockTrips = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockBookings = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockOffers = <Map<String, dynamic>>[];

List<Map<String, dynamic>> get kMockEarnings => <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockSettlements = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockNotifications = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockStaff = <Map<String, dynamic>>[
  {'id':'OU1','operatorId':'OP1','name':'Ramesh Kumar','email':'ramesh@kaveriexpress.in','role':'SUPER_ADMIN','roleLabel':'Owner','status':'ACTIVE','last':'','mfa':false},
];

List<Map<String, dynamic>> kMockLive = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockSos = <Map<String, dynamic>>[];

List<Map<String, dynamic>> kMockPlaceRequests = <Map<String, dynamic>>[];

Map<String, int> priceBreakdown(int fareInPaise) {
  const commission = kMockCommissions;
  final rule = commission.isNotEmpty ? commission.first : kMockCommissionDefault;
  final cm = rule['mode'] == 'PERCENT'
      ? (fareInPaise * (rule['value'] as int) ~/ 10000)
      : (rule['value'] as int);
  final gst = ((fareInPaise + cm) * 0.05).round();
  const fee = 500;
  return {'fare': fareInPaise, 'commission': cm, 'gst': gst, 'fee': fee, 'total': fareInPaise + cm + gst + fee};
}

String formatRs(int paise) {
  final v = paise / 100;
  if (v >= 10000000) return '\u20b9${(v / 10000000).toStringAsFixed(2)} Cr';
  if (v >= 100000) return '\u20b9${(v / 100000).toStringAsFixed(2)} L';
  if (v >= 1000) {
    final s = v.toStringAsFixed(0);
    final b = StringBuffer();
    final len = s.length;
    for (var i = 0; i < len; i++) {
      if (i > 0) {
        final fromRight = len - i;
        if (fromRight == 3 || (fromRight > 3 && (fromRight - 3) % 2 == 0)) b.write(',');
      }
      b.write(s[i]);
    }
    return '\u20b9$b';
  }
  return '\u20b9${v.toStringAsFixed(0)}';
}

String statusTone(String status) {
  const success = {'ACTIVE','APPROVED','PUBLISHED','PAID','COMPLETED','CONFIRMED','VERIFIED','RESOLVED','ACCEPTED','LIVE','ARRIVED'};
  const warning = {'PENDING','PENDING_APPROVAL','UNDER_REVIEW','INITIATED','PROCESSING','ON_HOLD','DELAYED','OPEN','SCHEDULED','BOARDING','MAINTENANCE'};
  const danger = {'REJECTED','FAILED','SUSPENDED','BLOCKED','ESCALATED','SIGNAL_LOST','CANCELLED','EXPIRED','NEW'};
  const info = {'IN_TRANSIT','IN_PROGRESS','ACKNOWLEDGED','INVITED','DRAFT'};
  if (success.contains(status)) return 'success';
  if (warning.contains(status)) return 'warning';
  if (danger.contains(status)) return 'danger';
  if (info.contains(status)) return 'info';
  return 'neutral';
}

String labelFor(String status) => status.replaceAll('_', ' ').toLowerCase().replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());

String relativeTime(String isoString) {
  final dt = DateTime.tryParse(isoString);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.isNegative) {
    final abs = diff.abs();
    if (abs.inMinutes < 60) return 'in ${abs.inMinutes} min';
    if (abs.inHours < 24) return 'in ${abs.inHours} h';
    return 'in ${abs.inDays} d';
  }
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return '${diff.inDays} d ago';
}

// --- KYC QUESTIONNAIRE & DOCUMENT RULES (Admin-configured) ---
final List<Map<String, dynamic>> kMockKycQuestions = [
  {
    'key': 'business_type',
    'label': 'What is your business structure? *',
    'type': 'SINGLE_CHOICE',
    'opts': ['Company', 'Individual', 'Partnership'],
    'required': true,
  },
  {
    'key': 'fleet_size',
    'label': 'How many buses do you operate? *',
    'type': 'SINGLE_CHOICE',
    'opts': ['1-2', '3-5', 'Above 5'],
    'required': true,
  },
  {
    'key': 'ac_type',
    'label': 'Bus types you operate? *',
    'type': 'SINGLE_CHOICE',
    'opts': ['AC Only', 'Non-AC Only', 'Both AC and Non-AC'],
    'required': true,
  },
  {
    'key': 'gst_registered',
    'label': 'Are you GST registered? *',
    'type': 'SINGLE_CHOICE',
    'opts': ['Yes', 'No'],
    'required': true,
  },
];

final List<Map<String, dynamic>> kMockDocTypes = [
  {
    'key': 'company_reg',
    'name': 'Company Registration',
    'required': true,
    'maxMb': 5,
    'types': 'PDF, JPG, PNG',
    'applies': 'OPERATOR',
    'instr': 'Certificate of incorporation or shop establishment license.',
  },
  {
    'key': 'pan',
    'name': 'PAN Card',
    'required': true,
    'maxMb': 5,
    'types': 'PDF, JPG, PNG',
    'applies': 'OPERATOR',
    'instr': 'Company PAN card or proprietor PAN.',
  },
  {
    'key': 'bank',
    'name': 'Cancelled Cheque',
    'required': true,
    'maxMb': 5,
    'types': 'PDF, JPG, PNG',
    'applies': 'OPERATOR',
    'instr': 'Showing company name, account number and IFSC.',
  },
  {
    'key': 'gst',
    'name': 'GST Certificate',
    'required': false, // conditional on gst_registered == 'Yes'
    'maxMb': 5,
    'types': 'PDF',
    'applies': 'OPERATOR',
    'instr': 'Form GST REG-06.',
  },
];

// Global reactive mock KYC state for demo simulation:
// Can be 'APPROVED', 'PENDING', 'REJECTED', or 'DRAFT'
final ValueNotifier<String> kActiveKycStateNotifier = ValueNotifier<String>('APPROVED');
String get kActiveKycState => kActiveKycStateNotifier.value;
set kActiveKycState(String val) => kActiveKycStateNotifier.value = val;

final ValueNotifier<String> kCurrentRoleNotifier = ValueNotifier<String>('Owner');
String get kCurrentRole => kCurrentRoleNotifier.value;
set kCurrentRole(String val) => kCurrentRoleNotifier.value = val;
