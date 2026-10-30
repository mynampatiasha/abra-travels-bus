import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../app/providers.dart';

/// The three information pages staff write in the admin app.
enum InfoPageKind {
  terms,
  privacy,
  about;

  /// The name the backend uses in `GET /content/pages/:key`.
  String get wireKey => name;
}

/// One published information page (`GET /content/pages/:key`).
@immutable
final class InfoPageContent {
  const InfoPageContent({
    required this.title,
    required this.body,
    this.updatedAt,
  });

  /// Throws [ModelParseException] when the title or the text is missing.
  factory InfoPageContent.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return InfoPageContent(
      title: reader.string('title'),
      body: reader.string('body'),
      updatedAt: reader.dateTimeOrNull('updatedAt'),
    );
  }

  final String title;
  final String body;
  final DateTime? updatedAt;

  /// The text as paragraphs: a blank line starts a new one.
  List<String> get paragraphs => body
      .split(RegExp(r'\n\s*\n'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
}

/// One published question and answer (`GET /content/faqs`).
@immutable
final class FaqItem {
  const FaqItem({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
  });

  factory FaqItem.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return FaqItem(
      id: reader.string('id'),
      question: reader.string('question'),
      answer: reader.string('answer'),
      category: reader.stringOrNull('category') ?? 'General',
    );
  }

  final String id;
  final String question;
  final String answer;
  final String category;
}

/// How to reach support (`GET /content/contact`). Empty fields are not
/// shown; [configured] is false until staff save the details.
@immutable
final class ContactDetails {
  const ContactDetails({
    required this.configured,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.hours = '',
  });

  factory ContactDetails.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return ContactDetails(
      configured: reader.boolean('configured'),
      phone: reader.stringOrNull('phone') ?? '',
      email: reader.stringOrNull('email') ?? '',
      address: reader.stringOrNull('address') ?? '',
      hours: reader.stringOrNull('hours') ?? '',
    );
  }

  final bool configured;
  final String phone;
  final String email;
  final String address;
  final String hours;
}

final infoRepositoryProvider = Provider<InfoRepository>(
  (ref) => InfoRepository(ref.watch(appDependenciesProvider).apiClient),
);

/// The page of one kind. Loaded again when the screen is opened again.
final infoPageProvider = FutureProvider.autoDispose
    .family<InfoPageContent, InfoPageKind>(
      (ref, kind) => ref.watch(infoRepositoryProvider).page(kind),
      retry: (_, _) => null,
    );

/// The published FAQs.
final faqsProvider = FutureProvider.autoDispose<List<FaqItem>>(
  (ref) => ref.watch(infoRepositoryProvider).faqs(),
  retry: (_, _) => null,
);

/// Support contact details.
final contactDetailsProvider = FutureProvider.autoDispose<ContactDetails>(
  (ref) => ref.watch(infoRepositoryProvider).contact(),
  retry: (_, _) => null,
);

/// The public content endpoints (no sign-in, so guests read them too).
/// Every method throws `AppException` when the request fails; a page that
/// is not published yet answers 404.
class InfoRepository {
  InfoRepository(this._client);

  final ApiClient _client;

  Future<InfoPageContent> page(InfoPageKind kind) async {
    final response = await _client.get(
      'content/pages/${kind.wireKey}',
      authenticated: false,
    );
    return InfoPageContent.fromJson(_object(response.data));
  }

  Future<List<FaqItem>> faqs() async {
    final response = await _client.get('content/faqs', authenticated: false);
    final payload = response.data;
    if (payload is! List) return const <FaqItem>[];
    final items = <FaqItem>[];
    for (final item in payload) {
      if (item is! Map) continue;
      try {
        items.add(FaqItem.fromJson(asJsonMap(item)));
      } on ModelParseException {
        continue;
      }
    }
    return items;
  }

  Future<ContactDetails> contact() async {
    final response = await _client.get('content/contact', authenticated: false);
    return ContactDetails.fromJson(_object(response.data));
  }
}

JsonMap _object(Object? data) {
  if (data is Map) return asJsonMap(data);
  throw const ModelParseException('the answer is not an object');
}
