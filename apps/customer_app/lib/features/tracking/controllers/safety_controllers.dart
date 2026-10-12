import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tracking_models.dart';
import '../repositories/tracking_repositories.dart';

/// The emergency contacts of the customer.
final emergencyContactsProvider =
    AsyncNotifierProvider.autoDispose<
      EmergencyContactsController,
      List<EmergencyContact>
    >(EmergencyContactsController.new);

class EmergencyContactsController
    extends AsyncNotifier<List<EmergencyContact>> {
  @override
  Future<List<EmergencyContact>> build() =>
      ref.read(safetyRepositoryProvider).contacts();

  Future<void> add({
    required String name,
    required String phone,
    required String relation,
  }) async {
    final created = await ref
        .read(safetyRepositoryProvider)
        .addContact(name: name, phone: phone, relation: relation);
    state = AsyncData<List<EmergencyContact>>(<EmergencyContact>[
      ...?state.value,
      created,
    ]);
  }
}

/// The sharing of a trip: the link, who has it, and starting and stopping.
final shareStateProvider = AsyncNotifierProvider.autoDispose
    .family<ShareController, ShareState, String>(ShareController.new);

class ShareController extends AsyncNotifier<ShareState> {
  ShareController(this.bookingId);

  final String bookingId;

  @override
  Future<ShareState> build() =>
      ref.read(sharingRepositoryProvider).state(bookingId);

  Future<void> start() async {
    state = AsyncData<ShareState>(
      await ref.read(sharingRepositoryProvider).start(bookingId),
    );
  }

  Future<void> stop() async {
    state = AsyncData<ShareState>(
      await ref.read(sharingRepositoryProvider).stop(bookingId),
    );
  }
}
