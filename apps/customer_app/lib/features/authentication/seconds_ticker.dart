import 'dart:async';

import 'package:flutter/widgets.dart';

/// Rebuilds the widget once a second so that countdowns stay current. The
/// remaining time itself is always computed from the clock and the times the
/// server gave, never by counting ticks, so it stays right after the app was
/// in the background.
mixin SecondsTicker<T extends StatefulWidget> on State<T> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
