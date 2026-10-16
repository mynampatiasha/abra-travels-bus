import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Models and state store for the Safety module matching prototypes/admin_demo_model.html.

class SosLogEntry {
  SosLogEntry({
    required this.title,
    required this.at,
    List<String>? proofFiles,
  }) : proofFiles = proofFiles ?? <String>[];

  final String title;
  final DateTime at;
  final List<String> proofFiles;
}

class SosAlert {
  SosAlert({
    required this.id,
    required this.customer,
    required this.phone,
    required this.trip,
    required this.route,
    required this.bus,
    required this.driver,
    required this.operator,
    required this.status, // NEW, ACKNOWLEDGED, RESPONDING, ESCALATED, RESOLVED, FALSE_ALARM
    required this.at,
    required this.note,
    required this.x,
    required this.y,
    List<String>? contacts,
    List<SosLogEntry>? log,
    this.assignee = '',
    this.fromDriver = false,
  })  : contacts = contacts ?? <String>[],
        log = log ?? <SosLogEntry>[];

  final String id;
  final String customer;
  final String phone;
  final String trip;
  final String route;
  final String bus;
  final String driver;
  final String operator;
  String status;
  final DateTime at;
  final String note;
  final double x;
  final double y;
  final List<String> contacts;
  final List<SosLogEntry> log;
  String assignee;
  final bool fromDriver;

  bool isOverdue(int ackMinutes) {
    if (status != 'NEW') return false;
    final diff = DateTime.now().difference(at).inMinutes;
    return diff > ackMinutes;
  }
}

class IncidentRecord {
  IncidentRecord({
    required this.id,
    required this.title,
    required this.customer,
    required this.against, // Driver, Conductor, Co-passenger, Operator
    required this.severity, // HIGH, MEDIUM, LOW
    required this.status, // OPEN, IN_PROGRESS, CLOSED
    required this.at,
    required this.trip,
    required this.notes,
    List<String>? files,
  }) : files = files ?? <String>[];

  final String id;
  final String title;
  final String customer;
  final String against;
  String severity;
  String status;
  final DateTime at;
  final String trip;
  String notes;
  final List<String> files;
}

class TripSharingRecord {
  TripSharingRecord({
    required this.id,
    required this.customer,
    required this.trip,
    required this.link,
    required this.opened,
    required this.created,
    required this.expires,
    required this.status, // ACTIVE, EXPIRED
  });

  final String id;
  final String customer;
  final String trip;
  final String link;
  final int opened;
  final DateTime created;
  final DateTime expires;
  String status;
}

class SafetyConfig {
  SafetyConfig({
    required this.ackMinutes,
    required this.escalateMinutes,
    required this.police,
    required this.team,
    required this.smsOn,
    required this.whatsOn,
    required this.notifyOperator,
    required this.sosHold,
    required this.template,
  });

  final int ackMinutes;
  final int escalateMinutes;
  final String police;
  final List<String> team;
  final bool smsOn;
  final bool whatsOn;
  final bool notifyOperator;
  final int sosHold;
  final String template;

  SafetyConfig copyWith({
    int? ackMinutes,
    int? escalateMinutes,
    String? police,
    List<String>? team,
    bool? smsOn,
    bool? whatsOn,
    bool? notifyOperator,
    int? sosHold,
    String? template,
  }) {
    return SafetyConfig(
      ackMinutes: ackMinutes ?? this.ackMinutes,
      escalateMinutes: escalateMinutes ?? this.escalateMinutes,
      police: police ?? this.police,
      team: team ?? List<String>.from(this.team),
      smsOn: smsOn ?? this.smsOn,
      whatsOn: whatsOn ?? this.whatsOn,
      notifyOperator: notifyOperator ?? this.notifyOperator,
      sosHold: sosHold ?? this.sosHold,
      template: template ?? this.template,
    );
  }
}

class SafetyState {
  SafetyState({
    required this.alerts,
    required this.incidents,
    required this.sharing,
    required this.config,
    this.soundOn = true,
    this.selectedAlertId,
  });

  final List<SosAlert> alerts;
  final List<IncidentRecord> incidents;
  final List<TripSharingRecord> sharing;
  final SafetyConfig config;
  final bool soundOn;
  final String? selectedAlertId;

  SafetyState copyWith({
    List<SosAlert>? alerts,
    List<IncidentRecord>? incidents,
    List<TripSharingRecord>? sharing,
    SafetyConfig? config,
    bool? soundOn,
    String? selectedAlertId,
    bool clearSelection = false,
  }) {
    return SafetyState(
      alerts: alerts ?? this.alerts,
      incidents: incidents ?? this.incidents,
      sharing: sharing ?? this.sharing,
      config: config ?? this.config,
      soundOn: soundOn ?? this.soundOn,
      selectedAlertId: clearSelection ? null : (selectedAlertId ?? this.selectedAlertId),
    );
  }
}

class SafetyStoreNotifier extends Notifier<SafetyState> {
  @override
  SafetyState build() {
    return _seedInitialData();
  }

  static SafetyState _seedInitialData() {
    final now = DateTime.now();

    final alerts = <SosAlert>[
      SosAlert(
        id: 'SOS-2001',
        customer: 'Divya Iyer',
        phone: '+91 98450 12001',
        trip: 'TRP-3003',
        route: 'Hyderabad to Bengaluru',
        bus: 'TS09 UB 4521',
        driver: 'Ramesh K',
        operator: 'Kaveri Express',
        status: 'NEW',
        at: now.subtract(const Duration(minutes: 2)),
        note: 'Unsafe behaviour by co-passenger in seat 14B',
        x: 44.0,
        y: 40.0,
        contacts: const [
          'Mother +91 98450 00001',
          'Husband +91 98450 00002',
        ],
        log: [
          SosLogEntry(
            title: 'SOS received from passenger mobile app',
            at: now.subtract(const Duration(minutes: 2)),
          ),
          SosLogEntry(
            title: 'Contacts alerted by SMS and WhatsApp broadcast',
            at: now.subtract(const Duration(minutes: 1, seconds: 50)),
          ),
        ],
      ),
      SosAlert(
        id: 'SOS-2002',
        customer: 'Meera Pillai',
        phone: '+91 98450 12002',
        trip: 'TRP-3004',
        route: 'Chennai to Coimbatore',
        bus: 'TN38 TX 8812',
        driver: 'Sunil Y',
        operator: 'Nilgiri Travels',
        status: 'ACKNOWLEDGED',
        assignee: 'Divya (Support)',
        at: now.subtract(const Duration(minutes: 18)),
        note: 'Bus stopped at an unknown unlit bypass place for 25 minutes',
        x: 52.0,
        y: 58.0,
        contacts: const [
          'Father +91 98450 00003',
          'Brother +91 98450 00004',
        ],
        log: [
          SosLogEntry(
            title: 'SOS received from passenger mobile app',
            at: now.subtract(const Duration(minutes: 18)),
          ),
          SosLogEntry(
            title: 'Contacts alerted by SMS and call',
            at: now.subtract(const Duration(minutes: 17)),
          ),
          SosLogEntry(
            title: 'Acknowledged by Divya (Support)',
            at: now.subtract(const Duration(minutes: 15)),
          ),
        ],
      ),
      SosAlert(
        id: 'SOS-2003',
        customer: 'Driver Ramesh K',
        phone: '+91 98450 12003',
        trip: 'TRP-3005',
        route: 'Bengaluru to Hyderabad',
        bus: 'KA01 AB 9021',
        driver: 'Ramesh K',
        operator: 'Kaveri Express',
        status: 'NEW',
        fromDriver: true,
        at: now.subtract(const Duration(minutes: 7)),
        note: 'Vehicle breakdown on highway with aggressive passengers',
        x: 30.0,
        y: 62.0,
        contacts: const [
          'Operator Kaveri Express Ops +91 98450 00010',
          'Highway Patrol Kurnool +91 98450 00100',
        ],
        log: [
          SosLogEntry(
            title: 'SOS raised by Driver Ramesh K via Driver App',
            at: now.subtract(const Duration(minutes: 7)),
          ),
          SosLogEntry(
            title: 'Operator operations team alerted',
            at: now.subtract(const Duration(minutes: 6)),
          ),
        ],
      ),
      SosAlert(
        id: 'SOS-2004',
        customer: 'Pooja Shah',
        phone: '+91 98450 12004',
        trip: 'TRP-3006',
        route: 'Hyderabad to Vijayawada',
        bus: 'AP39 CD 1289',
        driver: 'Anwar S',
        operator: 'Godavari Lines',
        status: 'RESOLVED',
        assignee: 'Divya (Support)',
        at: now.subtract(const Duration(hours: 5)),
        note: 'Accidental press while adjusting seat pocket',
        x: 66.0,
        y: 34.0,
        contacts: const [
          'Sister +91 98450 00005',
        ],
        log: [
          SosLogEntry(
            title: 'SOS received',
            at: now.subtract(const Duration(hours: 5)),
          ),
          SosLogEntry(
            title: 'Acknowledged by Divya (Support)',
            at: now.subtract(const Duration(hours: 4, minutes: 58)),
          ),
          SosLogEntry(
            title: 'Resolved: customer confirmed safe, false alert',
            at: now.subtract(const Duration(hours: 4, minutes: 20)),
            proofFiles: const ['call_log_screenshot.png'],
          ),
        ],
      ),
      SosAlert(
        id: 'SOS-2005',
        customer: 'Neha Bhat',
        phone: '+91 98450 12005',
        trip: 'TRP-3007',
        route: 'Visakhapatnam to Hyderabad',
        bus: 'AP16 EF 7744',
        driver: 'Prakash M',
        operator: 'Araku Express',
        status: 'FALSE_ALARM',
        assignee: 'Kiran (Support)',
        at: now.subtract(const Duration(hours: 25)),
        note: 'Pressed by mistake during charging phone',
        x: 58.0,
        y: 46.0,
        contacts: const [
          'Mother +91 98450 00006',
        ],
        log: [
          SosLogEntry(
            title: 'SOS received',
            at: now.subtract(const Duration(hours: 25)),
          ),
          SosLogEntry(
            title: 'Marked false alarm after call with passenger',
            at: now.subtract(const Duration(hours: 24, minutes: 40)),
            proofFiles: const ['passenger_call_note.pdf'],
          ),
        ],
      ),
      SosAlert(
        id: 'SOS-2006',
        customer: 'Kavya Menon',
        phone: '+91 98450 12006',
        trip: 'TRP-3008',
        route: 'Kochi to Bengaluru',
        bus: 'KL07 GH 3321',
        driver: 'Naveen B',
        operator: 'Malabar Lines',
        status: 'RESOLVED',
        assignee: 'Ravi (Safety lead)',
        at: now.subtract(const Duration(hours: 66)),
        note: 'Driver rash driving and speeding in heavy rain',
        x: 40.0,
        y: 70.0,
        contacts: const [
          'Friend +91 98450 00007',
        ],
        log: [
          SosLogEntry(
            title: 'SOS received',
            at: now.subtract(const Duration(hours: 66)),
          ),
          SosLogEntry(
            title: 'Escalated to safety lead and operator dispatch',
            at: now.subtract(const Duration(hours: 65, minutes: 50)),
          ),
          SosLogEntry(
            title: 'Resolved: Operator reprimanded driver and slowed vehicle',
            at: now.subtract(const Duration(hours: 64)),
            proofFiles: const ['operator_confirmation_email.pdf'],
          ),
        ],
      ),
    ];

    final incidents = <IncidentRecord>[
      IncidentRecord(
        id: 'INC-3001',
        title: 'Rash driving reported on NH44',
        customer: 'Kavya Menon',
        against: 'Driver',
        severity: 'MEDIUM',
        status: 'CLOSED',
        at: now.subtract(const Duration(days: 1)),
        trip: 'TRP-3008',
        notes: 'Investigated by safety team. Driver warned and telemetry reviewed.',
        files: const ['gps_telemetry_report.pdf'],
      ),
      IncidentRecord(
        id: 'INC-3002',
        title: 'Harassment complaint by female co-passenger',
        customer: 'Priya Nair',
        against: 'Co-passenger',
        severity: 'HIGH',
        status: 'OPEN',
        at: now.subtract(const Duration(hours: 3)),
        trip: 'TRP-3006',
        notes: 'Co-passenger in 18C was causing distress. Conductor swapped passenger seat to 3A.',
        files: const ['police_complaint_ack.jpg'],
      ),
      IncidentRecord(
        id: 'INC-3003',
        title: 'Bus breakdown at night on highway',
        customer: 'Rohan Mehta',
        against: 'Operator',
        severity: 'MEDIUM',
        status: 'CLOSED',
        at: now.subtract(const Duration(days: 3)),
        trip: 'TRP-3005',
        notes: 'AC compressor failure. Replacement bus arranged within 90 minutes.',
      ),
      IncidentRecord(
        id: 'INC-3004',
        title: 'Lost luggage from luggage compartment',
        customer: 'Isha Agarwal',
        against: 'Operator',
        severity: 'LOW',
        status: 'OPEN',
        at: now.subtract(const Duration(days: 5)),
        trip: 'TRP-3004',
        notes: 'Red Samsonite bag missing at destination. Operator reviewing baggage tag records.',
      ),
      IncidentRecord(
        id: 'INC-3005',
        title: 'Overcharging for water bottles and luggage by conductor',
        customer: 'Sanjay Gupta',
        against: 'Conductor',
        severity: 'MEDIUM',
        status: 'IN_PROGRESS',
        at: now.subtract(const Duration(days: 7)),
        trip: 'TRP-3003',
        notes: 'Conductor demanded ₹100 extra per bag. Operator issued penalty notice.',
        files: const ['passenger_receipt.png'],
      ),
    ];

    final sharing = <TripSharingRecord>[
      TripSharingRecord(
        id: 'SH1',
        customer: 'Aarav Sharma',
        trip: 'TRP-3003',
        link: 'abra.in/s/729104',
        opened: 4,
        created: now.subtract(const Duration(minutes: 45)),
        expires: now.add(const Duration(hours: 6)),
        status: 'ACTIVE',
      ),
      TripSharingRecord(
        id: 'SH2',
        customer: 'Priya Nair',
        trip: 'TRP-3006',
        link: 'abra.in/s/819230',
        opened: 2,
        created: now.subtract(const Duration(hours: 2)),
        expires: now.add(const Duration(hours: 4)),
        status: 'ACTIVE',
      ),
      TripSharingRecord(
        id: 'SH3',
        customer: 'Vikram Singh',
        trip: 'TRP-3004',
        link: 'abra.in/s/448102',
        opened: 6,
        created: now.subtract(const Duration(hours: 3)),
        expires: now.add(const Duration(hours: 8)),
        status: 'ACTIVE',
      ),
      TripSharingRecord(
        id: 'SH4',
        customer: 'Meera Pillai',
        trip: 'TRP-3005',
        link: 'abra.in/s/229014',
        opened: 1,
        created: now.subtract(const Duration(days: 1)),
        expires: now.subtract(const Duration(hours: 12)),
        status: 'EXPIRED',
      ),
      TripSharingRecord(
        id: 'SH5',
        customer: 'Arjun Patel',
        trip: 'TRP-3007',
        link: 'abra.in/s/994120',
        opened: 0,
        created: now.subtract(const Duration(days: 2)),
        expires: now.subtract(const Duration(days: 1)),
        status: 'EXPIRED',
      ),
      TripSharingRecord(
        id: 'SH6',
        customer: 'Sneha Joshi',
        trip: 'TRP-3008',
        link: 'abra.in/s/552109',
        opened: 5,
        created: now.subtract(const Duration(days: 3)),
        expires: now.subtract(const Duration(days: 2)),
        status: 'EXPIRED',
      ),
    ];

    final config = SafetyConfig(
      ackMinutes: 3,
      escalateMinutes: 8,
      police: '+91 100',
      team: ['Divya (Support)', 'Kiran (Support)', 'Ravi (Safety lead)'],
      smsOn: true,
      whatsOn: true,
      notifyOperator: true,
      sosHold: 3,
      template: '{customer} pressed SOS on {route}. Bus {bus}. Live location: {link}',
    );

    return SafetyState(
      alerts: alerts,
      incidents: incidents,
      sharing: sharing,
      config: config,
      soundOn: true,
      selectedAlertId: 'SOS-2001',
    );
  }

  void toggleSound(bool soundOn) {
    state = state.copyWith(soundOn: soundOn);
  }

  void selectAlert(String? id) {
    state = state.copyWith(selectedAlertId: id);
  }

  void acknowledgeAlert(String id, {String staffName = 'Super Admin'}) {
    final updated = state.alerts.map((a) {
      if (a.id == id) {
        a.status = 'ACKNOWLEDGED';
        a.assignee = staffName;
        a.log.add(SosLogEntry(
          title: 'Acknowledged by $staffName',
          at: DateTime.now(),
        ));
      }
      return a;
    }).toList();
    state = state.copyWith(alerts: updated);
  }

  void escalateAlert(String id) {
    final updated = state.alerts.map((a) {
      if (a.id == id) {
        a.status = 'ESCALATED';
        a.log.add(SosLogEntry(
          title: 'Escalated to safety lead and police control room (${state.config.police})',
          at: DateTime.now(),
        ));
      }
      return a;
    }).toList();
    state = state.copyWith(alerts: updated);
  }

  void addAlertNote(String id, String note, List<String> proofFiles) {
    final updated = state.alerts.map((a) {
      if (a.id == id) {
        a.log.add(SosLogEntry(
          title: 'Note: $note',
          at: DateTime.now(),
          proofFiles: proofFiles,
        ));
      }
      return a;
    }).toList();
    state = state.copyWith(alerts: updated);
  }

  void resolveAlert(String id, String resolution, List<String> proofFiles) {
    final updated = state.alerts.map((a) {
      if (a.id == id) {
        a.status = 'RESOLVED';
        a.log.add(SosLogEntry(
          title: 'Resolved: $resolution',
          at: DateTime.now(),
          proofFiles: proofFiles,
        ));
      }
      return a;
    }).toList();
    state = state.copyWith(alerts: updated);
  }

  void markFalseAlarm(String id, String explanation, List<String> proofFiles) {
    final updated = state.alerts.map((a) {
      if (a.id == id) {
        a.status = 'FALSE_ALARM';
        a.log.add(SosLogEntry(
          title: 'Marked false alarm: $explanation',
          at: DateTime.now(),
          proofFiles: proofFiles,
        ));
      }
      return a;
    }).toList();
    state = state.copyWith(alerts: updated);
  }

  void logIncident({
    required String title,
    required String customer,
    required String against,
    required String severity,
    required String trip,
    required String notes,
  }) {
    final newIncident = IncidentRecord(
      id: 'INC-${3000 + state.incidents.length + 1}',
      title: title,
      customer: customer,
      against: against,
      severity: severity,
      status: 'OPEN',
      at: DateTime.now(),
      trip: trip,
      notes: notes,
    );
    state = state.copyWith(incidents: [newIncident, ...state.incidents]);
  }

  void updateIncident({
    required String id,
    required String status,
    String? note,
    List<String>? newProofFiles,
  }) {
    final updated = state.incidents.map((i) {
      if (i.id == id) {
        i.status = status;
        if (note != null && note.trim().isNotEmpty) {
          i.notes = '${i.notes} | $note';
        }
        if (newProofFiles != null && newProofFiles.isNotEmpty) {
          i.files.addAll(newProofFiles);
        }
      }
      return i;
    }).toList();
    state = state.copyWith(incidents: updated);
  }

  void revokeSharingLink(String id) {
    final updated = state.sharing.map((s) {
      if (s.id == id) {
        s.status = 'EXPIRED';
      }
      return s;
    }).toList();
    state = state.copyWith(sharing: updated);
  }

  void updateConfig({
    required int ackMinutes,
    required int escalateMinutes,
    required String police,
    required String template,
  }) {
    state = state.copyWith(
      config: state.config.copyWith(
        ackMinutes: ackMinutes,
        escalateMinutes: escalateMinutes,
        police: police,
        template: template,
      ),
    );
  }

  void toggleSms(bool val) {
    state = state.copyWith(config: state.config.copyWith(smsOn: val));
  }

  void toggleWhatsApp(bool val) {
    state = state.copyWith(config: state.config.copyWith(whatsOn: val));
  }

  void toggleNotifyOperator(bool val) {
    state = state.copyWith(config: state.config.copyWith(notifyOperator: val));
  }

  void addTeamMember(String name) {
    final team = List<String>.from(state.config.team)..add(name);
    state = state.copyWith(config: state.config.copyWith(team: team));
  }

  void removeTeamMember(int index) {
    if (state.config.team.length <= 1) return;
    final team = List<String>.from(state.config.team)..removeAt(index);
    state = state.copyWith(config: state.config.copyWith(team: team));
  }
}

final safetyStoreProvider =
    NotifierProvider<SafetyStoreNotifier, SafetyState>(SafetyStoreNotifier.new);

/// Helper to format relative time (e.g., '2m ago', '3h ago', 'just now').
String formatRelativeTime(DateTime dt) {
  final now = DateTime.now();
  final difference = now.difference(dt);

  if (difference.isNegative) {
    final positive = dt.difference(now);
    if (positive.inMinutes < 60) return 'in ${positive.inMinutes}m';
    if (positive.inHours < 24) return 'in ${positive.inHours}h';
    return 'in ${positive.inDays}d';
  }

  if (difference.inSeconds < 60) {
    return 'just now';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m ago';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h ago';
  } else {
    return '${difference.inDays}d ago';
  }
}

/// Helper to format full date-time.
String formatDateTime(DateTime dt) {
  final months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final ampm = dt.hour >= 12 ? 'PM' : 'AM';
  return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $hour:$minute $ampm';
}
