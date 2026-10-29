import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';

import '../../app/providers.dart';

/// One feature switch as returned by GET /admin/feature-flags.
class FeatureFlag {
  const FeatureFlag({
    required this.key,
    required this.name,
    required this.description,
    required this.on,
    this.updatedAt,
  });

  final String key;
  final String name;
  final String description;
  final bool on;
  final String? updatedAt;

  factory FeatureFlag.fromJson(JsonMap json) => FeatureFlag(
    key: json['key'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    on: json['on'] as bool? ?? false,
    updatedAt: json['updatedAt'] as String?,
  );

  FeatureFlag copyWith({bool? on, String? updatedAt}) => FeatureFlag(
    key: key,
    name: name,
    description: description,
    on: on ?? this.on,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// The maintenance mode state as returned by GET /admin/maintenance.
class MaintenanceState {
  const MaintenanceState({
    required this.scopes,
    required this.message,
    this.from,
    this.to,
    this.activeNow = const <String, bool>{},
    this.updatedAt,
  });

  final Map<String, bool> scopes;
  final String message;
  final String? from;
  final String? to;
  final Map<String, bool> activeNow;
  final String? updatedAt;

  factory MaintenanceState.fromJson(JsonMap json) {
    final rawScopes = json['scopes'] as Map<String, Object?>? ?? const {};
    final rawActive = json['activeNow'] as Map<String, Object?>? ?? const {};
    return MaintenanceState(
      scopes: rawScopes.map((k, v) => MapEntry(k, v == true)),
      message:
          json['message'] as String? ??
          'We are improving Abra Travels. Back soon.',
      from: json['from'] as String?,
      to: json['to'] as String?,
      activeNow: rawActive.map((k, v) => MapEntry(k, v == true)),
      updatedAt: json['updatedAt'] as String?,
    );
  }

  MaintenanceState copyWith({
    Map<String, bool>? scopes,
    String? message,
    String? from,
    String? to,
    Map<String, bool>? activeNow,
    String? updatedAt,
  }) => MaintenanceState(
    scopes: scopes ?? this.scopes,
    message: message ?? this.message,
    from: from ?? this.from,
    to: to ?? this.to,
    activeNow: activeNow ?? this.activeNow,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// Feature flags and maintenance management matching prototypes/admin_demo_model.html.
class AdminFeatureFlagsPage extends ConsumerStatefulWidget {
  const AdminFeatureFlagsPage({super.key});

  @override
  ConsumerState<AdminFeatureFlagsPage> createState() =>
      _AdminFeatureFlagsPageState();
}

class _AdminFeatureFlagsPageState extends ConsumerState<AdminFeatureFlagsPage> {
  bool _loading = true;
  String? _error;
  List<FeatureFlag> _flags = <FeatureFlag>[];
  MaintenanceState? _maintenance;

  final TextEditingController _maintMsgCtrl = TextEditingController();
  final TextEditingController _startsCtrl = TextEditingController();
  final TextEditingController _endsCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _maintMsgCtrl.dispose();
    _startsCtrl.dispose();
    _endsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(appDependenciesProvider).apiClient;
      final flagsResponse = await api.get('admin/feature-flags');
      final flags = flagsResponse.decodeList(
        (JsonMap item) => FeatureFlag.fromJson(item),
      );

      final maintResponse = await api.get('admin/maintenance');
      final maint = maintResponse.decodeObject(
        (JsonMap json) => MaintenanceState.fromJson(json),
      );

      if (mounted) {
        setState(() {
          _flags = flags;
          _maintenance = maint;
          _maintMsgCtrl.text = maint.message;
          _startsCtrl.text = maint.from ?? '';
          _endsCtrl.text = maint.to ?? '';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _saveFlag(FeatureFlag flag, bool newVal, String reason) async {
    try {
      final api = ref.read(appDependenciesProvider).apiClient;
      final response = await api.put(
        'admin/feature-flags/${flag.key}',
        body: <String, Object?>{'on': newVal, 'reason': reason},
      );
      final updated = response.decodeObject(
        (JsonMap json) => FeatureFlag.fromJson(json),
      );
      if (mounted) {
        setState(() {
          _flags = [
            for (final f in _flags)
              if (f.key == flag.key) updated else f,
          ];
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${flag.name} is now ${newVal ? 'enabled.' : 'disabled.'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update ${flag.name}: $e'),
            backgroundColor: AbraColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _updateMaintenance({
    Map<String, bool>? scopes,
    String? message,
    String? from,
    String? to,
    required String reason,
    String? successMessage,
  }) async {
    try {
      final api = ref.read(appDependenciesProvider).apiClient;
      final body = <String, Object?>{'reason': reason};
      if (scopes != null) body['scopes'] = scopes;
      if (message != null) body['message'] = message;
      if (from != null) body['from'] = from.isEmpty ? null : from;
      if (to != null) body['to'] = to.isEmpty ? null : to;

      final response = await api.put('admin/maintenance', body: body);
      final updated = response.decodeObject(
        (JsonMap json) => MaintenanceState.fromJson(json),
      );

      if (mounted) {
        setState(() {
          _maintenance = updated;
          if (message != null) _maintMsgCtrl.text = updated.message;
          if (from != null) _startsCtrl.text = updated.from ?? '';
          if (to != null) _endsCtrl.text = updated.to ?? '';
        });
        if (successMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(successMessage)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not update maintenance: $e'),
            backgroundColor: AbraColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(accessProvider);
    final canEdit = access.can(PermissionKeys.settingsUpdate);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('Could not load feature flags: $_error'),
            const SizedBox(height: AbraSpacing.md),
            FilledButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final maint = _maintenance ?? const MaintenanceState(
      scopes: {},
      message: 'We are improving Abra Travels. Back soon.',
    );
    final scopes = maint.scopes;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1620) : Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Page Header
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Feature flags and maintenance',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Switch features on and off, or put an app into maintenance.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? const Color(0xFF9FB6C9) : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Feature Flags Card
            Card(
              elevation: 0,
              color: isDark ? const Color(0xFF13222F) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isDark ? const Color(0xFF2A3E50) : Colors.grey.shade300,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Feature flags',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Toggles take effect immediately across mobile apps and web portals upon next sync.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF9FB6C9) : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _flags.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: isDark ? const Color(0xFF2A3E50) : Colors.grey.shade200,
                      ),
                      itemBuilder: (context, index) {
                        final f = _flags[index];
                        return SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          title: Row(
                            children: <Widget>[
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
                            f.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? const Color(0xFF9FB6C9)
                                  : Colors.grey.shade600,
                            ),
                          ),
                          value: f.on,
                          activeThumbColor: AbraColors.blue,
                          onChanged: canEdit
                              ? (val) => _confirmFlagToggle(f, val)
                              : null,
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
              color: isDark ? const Color(0xFF13222F) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isDark ? const Color(0xFF2A3E50) : Colors.grey.shade300,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Maintenance mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFE6EEF5) : AbraColors.navy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Staff with the maintenance permission can always sign in, so nobody gets locked out.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF9FB6C9) : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Scopes switches
                    _buildScopeTile(
                      'Global maintenance (All apps & APIs)',
                      'Emergency lock on Customer, Operator, and Partner interfaces',
                      scopes['global'] == true,
                      canEdit ? (val) => _toggleGlobalMaint(val) : null,
                      isDanger: true,
                    ),
                    const Divider(),
                    _buildScopeTile(
                      'Customer app maintenance',
                      'Passenger bookings and seat reservation temporarily paused',
                      scopes['customer'] == true,
                      canEdit
                          ? (val) => _updateMaintenance(
                              scopes: {'customer': val},
                              reason: val
                                  ? 'Turned on customer app maintenance'
                                  : 'Turned off customer app maintenance',
                              successMessage: val
                                  ? 'Customer app maintenance enabled.'
                                  : 'Customer app maintenance disabled.',
                            )
                          : null,
                    ),
                    const Divider(),
                    _buildScopeTile(
                      'Operator portal maintenance',
                      'Operator schedule management and inventory editing paused',
                      scopes['operator'] == true,
                      canEdit
                          ? (val) => _updateMaintenance(
                              scopes: {'operator': val},
                              reason: val
                                  ? 'Turned on operator portal maintenance'
                                  : 'Turned off operator portal maintenance',
                              successMessage: val
                                  ? 'Operator portal maintenance enabled.'
                                  : 'Operator portal maintenance disabled.',
                            )
                          : null,
                    ),
                    const Divider(),
                    _buildScopeTile(
                      'Partner API maintenance',
                      'External OTA integrations and seat syndication paused',
                      scopes['partner'] == true,
                      canEdit
                          ? (val) => _updateMaintenance(
                              scopes: {'partner': val},
                              reason: val
                                  ? 'Turned on partner API maintenance'
                                  : 'Turned off partner API maintenance',
                              successMessage: val
                                  ? 'Partner API maintenance enabled.'
                                  : 'Partner API maintenance disabled.',
                            )
                          : null,
                    ),
                    const Divider(),
                    _buildScopeTile(
                      'Admin portal maintenance',
                      'Restricted to Super Admin tier only',
                      scopes['admin'] == true,
                      canEdit
                          ? (val) => _updateMaintenance(
                              scopes: {'admin': val},
                              reason: val
                                  ? 'Turned on admin portal maintenance'
                                  : 'Turned off admin portal maintenance',
                              successMessage: val
                                  ? 'Admin portal maintenance enabled.'
                                  : 'Admin portal maintenance disabled.',
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // Schedule & Message
                    TextField(
                      controller: _maintMsgCtrl,
                      readOnly: !canEdit,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Message customers see',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _startsCtrl,
                            readOnly: !canEdit,
                            decoration: const InputDecoration(
                              labelText: 'Starts',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextField(
                            controller: _endsCtrl,
                            readOnly: !canEdit,
                            decoration: const InputDecoration(
                              labelText: 'Ends',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (canEdit)
                      ElevatedButton.icon(
                        onPressed: _saveMessageAndSchedule,
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
    ValueChanged<bool>? onChanged, {
    bool isDanger = false,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: <Widget>[
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDanger && value ? Colors.red.shade800 : null,
            ),
          ),
          if (value) ...<Widget>[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'On',
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
    final reasonCtrl = TextEditingController(
      text: 'Updated in the management app',
    );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(newVal ? 'Turn on ${f.name}' : 'Turn off ${f.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              newVal
                  ? 'Customers get this feature on their next app refresh.'
                  : 'Customers lose this feature straight away.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason for change',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              if (reason.length < 3) return;
              Navigator.of(ctx).pop();
              _saveFlag(f, newVal, reason);
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
      final reasonCtrl = TextEditingController(text: 'Scheduled maintenance');
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Global maintenance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Customer, operator and partner apps stop working. Admin staff still get in.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for change',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final reason = reasonCtrl.text.trim();
                if (reason.length < 3) return;
                Navigator.of(ctx).pop();
                _updateMaintenance(
                  scopes: {'global': true},
                  reason: reason,
                  successMessage: 'Global maintenance mode enabled.',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Turn on'),
            ),
          ],
        ),
      );
    } else {
      _updateMaintenance(
        scopes: {'global': false},
        reason: 'Global maintenance ended',
        successMessage: 'Global maintenance mode disabled. Services restored.',
      );
    }
  }

  void _saveMessageAndSchedule() {
    final starts = _startsCtrl.text.trim();
    final ends = _endsCtrl.text.trim();

    if (starts.isNotEmpty && ends.isNotEmpty) {
      try {
        final startDt = DateTime.parse(starts);
        final endDt = DateTime.parse(ends);
        if (endDt.isBefore(startDt) || endDt.isAtSameMomentAs(startDt)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End must be after start'),
              backgroundColor: AbraColors.danger,
            ),
          );
          return;
        }
      } catch (_) {
        if (ends.compareTo(starts) <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End must be after start'),
              backgroundColor: AbraColors.danger,
            ),
          );
          return;
        }
      }
    }

    _updateMaintenance(
      message: _maintMsgCtrl.text.trim(),
      from: starts,
      to: ends,
      reason: 'Updated maintenance window',
      successMessage: 'Saved',
    );
  }
}
