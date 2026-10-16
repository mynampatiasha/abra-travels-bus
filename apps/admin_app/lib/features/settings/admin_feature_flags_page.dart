import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_theme/shared_theme.dart';

class FeatureFlag {
  FeatureFlag({
    required this.key,
    required this.name,
    required this.desc,
    required this.on,
  });

  final String key;
  final String name;
  final String desc;
  bool on;
}

class AdminFeatureFlagsPage extends ConsumerStatefulWidget {
  const AdminFeatureFlagsPage({super.key});

  @override
  ConsumerState<AdminFeatureFlagsPage> createState() =>
      _AdminFeatureFlagsPageState();
}

class _AdminFeatureFlagsPageState extends ConsumerState<AdminFeatureFlagsPage> {
  late List<FeatureFlag> _flags;

  // Maintenance scopes
  bool _globalMaint = false;
  bool _customerMaint = false;
  bool _operatorMaint = false;
  bool _partnerMaint = false;
  bool _adminMaint = false;

  final TextEditingController _maintMsgCtrl = TextEditingController(
    text: 'We are improving Abra Travels. Back soon.',
  );
  final TextEditingController _startsCtrl = TextEditingController(
    text: '2026-10-15T02:00',
  );
  final TextEditingController _endsCtrl = TextEditingController(
    text: '2026-10-15T05:00',
  );

  @override
  void initState() {
    super.initState();
    _flags = [
      FeatureFlag(
        key: 'live_tracking',
        name: 'Live tracking',
        desc: 'Customers see the bus and telemetry on a live map',
        on: true,
      ),
      FeatureFlag(
        key: 'whatsapp_chatbot',
        name: 'WhatsApp chatbot',
        desc: 'Interactive booking help and status updates via WhatsApp',
        on: false,
      ),
      FeatureFlag(
        key: 'ai_support',
        name: 'AI support assistant',
        desc: 'Automated answers to common queries and dispute pre-triage',
        on: false,
      ),
      FeatureFlag(
        key: 'women_safety',
        name: 'Women safety',
        desc: 'Emergency SOS alerts and live trip sharing links',
        on: true,
      ),
      FeatureFlag(
        key: 'partner_api',
        name: 'Partner API',
        desc: 'External agents and corporate travel booking integration',
        on: false,
      ),
      FeatureFlag(
        key: 'dynamic_pricing',
        name: 'Dynamic pricing',
        desc: 'Fares adjust dynamically based on seat velocity and demand',
        on: false,
      ),
      FeatureFlag(
        key: 'mobile_app',
        name: 'Mobile app booking',
        desc: 'Enable new bookings from the passenger Android & iOS apps',
        on: true,
      ),
      FeatureFlag(
        key: 'driver_app',
        name: 'Driver app',
        desc: 'Driver check-in, passenger manifest, and live GPS pinging',
        on: true,
      ),
      FeatureFlag(
        key: 'advanced_analytics',
        name: 'Advanced analytics',
        desc: 'Extended cohort analysis, occupancy yield, and financial drilldowns',
        on: false,
      ),
    ];
  }

  @override
  void dispose() {
    _maintMsgCtrl.dispose();
    _startsCtrl.dispose();
    _endsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Feature flags and maintenance',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AbraColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch features on and off, or put an app into maintenance.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Feature Flags Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Runtime feature flags',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toggles take effect immediately across mobile apps and web portals upon next sync.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _flags.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final f = _flags[index];
                        return SwitchListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                          title: Row(
                            children: [
                              Text(
                                f.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: f.on
                                      ? Colors.green.shade50
                                      : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  f.on ? 'Active' : 'Disabled',
                                  style: TextStyle(
                                    color: f.on
                                        ? Colors.green.shade800
                                        : Colors.grey.shade600,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            f.desc,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          value: f.on,
                          activeThumbColor: AbraColors.blue,
                          onChanged: (val) => _confirmFlagToggle(f, val),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Maintenance Mode Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Maintenance mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Staff with maintenance permissions can always sign in, so nobody gets locked out.',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),

                    // Scopes switches
                    _buildScopeTile(
                      'Global maintenance (All apps & APIs)',
                      'Emergency lock on Customer, Operator, and Partner interfaces',
                      _globalMaint,
                      (val) => _toggleGlobalMaint(val),
                      isDanger: true,
                    ),
                    const Divider(),
                    _buildScopeTile(
                      'Customer app maintenance',
                      'Passenger bookings and seat reservation temporarily paused',
                      _customerMaint,
                      (val) => setState(() => _customerMaint = val),
                    ),
                    const Divider(),
                    _buildScopeTile(
                      'Operator portal maintenance',
                      'Operator schedule management and inventory editing paused',
                      _operatorMaint,
                      (val) => setState(() => _operatorMaint = val),
                    ),
                    const Divider(),
                    _buildScopeTile(
                      'Partner API maintenance',
                      'External OTA integrations and seat syndication paused',
                      _partnerMaint,
                      (val) => setState(() => _partnerMaint = val),
                    ),
                    const Divider(),
                    _buildScopeTile(
                      'Admin portal maintenance',
                      'Restricted to Super Admin tier only',
                      _adminMaint,
                      (val) => setState(() => _adminMaint = val),
                    ),
                    const SizedBox(height: 20),

                    // Schedule & Message
                    TextField(
                      controller: _maintMsgCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Message customers and operators see',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Starts (UTC/Local)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _endsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Ends (UTC/Local)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Maintenance window and customer broadcast message saved.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Save message and schedule'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AbraColors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeTile(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged, {
    bool isDanger = false,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDanger && value ? Colors.red.shade800 : null,
            ),
          ),
          if (value) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ACTIVE LOCK',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
      value: value,
      activeThumbColor: isDanger ? Colors.red : AbraColors.blue,
      onChanged: onChanged,
    );
  }

  void _confirmFlagToggle(FeatureFlag f, bool newVal) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newVal ? 'Turn on ${f.name}?' : 'Turn off ${f.name}?'),
        content: Text(
          newVal
              ? 'Customers will get this feature on their next app refresh.'
              : 'Customers and operators will lose access to this feature immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => f.on = newVal);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${f.name} is now ${newVal ? "enabled" : "disabled"}.',
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: newVal ? AbraColors.blue : Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(newVal ? 'Turn on' : 'Turn off'),
          ),
        ],
      ),
    );
  }

  void _toggleGlobalMaint(bool newVal) {
    if (newVal) {
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enable Global Maintenance?'),
          content: const Text(
            'This will pause customer bookings, operator portals, and external partner APIs immediately. Portal super admins will still have access.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _globalMaint = true);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Global maintenance mode enabled.'),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enable Global Maintenance'),
            ),
          ],
        ),
      );
    } else {
      setState(() => _globalMaint = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Global maintenance mode disabled. Services restored.'),
        ),
      );
    }
  }
}
