import 'package:shared_core/shared_core.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_network/shared_network.dart';

import '../../core/async_value_view.dart';

/// A problem to show next to the form, in plain words.
class ContentApiError implements Exception {
  ContentApiError(this.message);

  final String message;

  @override
  String toString() => message;

  factory ContentApiError.from(Object error) {
    final failure = failureOf(error);
    if (failure is ApiFailure) {
      final issues = failure.details['issues'];
      if (issues is List && issues.isNotEmpty && issues.first is Map) {
        final text = (issues.first as Map)['message'];
        if (text is String && text.isNotEmpty) return ContentApiError(text);
      }
      if (failure.isForbidden) {
        return ContentApiError('You do not have permission to do this.');
      }
      return ContentApiError(
        failure.message.isEmpty ? 'Something went wrong.' : failure.message,
      );
    }
    return ContentApiError(
      'Could not reach the server. Check your connection and try again.',
    );
  }
}

/// One information page as staff see it (`GET /admin/content/pages`).
class ContentPageDraft {
  const ContentPageDraft({
    required this.key,
    required this.title,
    required this.body,
    required this.status,
    required this.updatedBy,
    this.updatedAt,
  });

  factory ContentPageDraft.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return ContentPageDraft(
      key: reader.string('key'),
      title: reader.string('title'),
      body: reader.string('body'),
      status: reader.string('status'),
      updatedBy: reader.stringOrNull('updatedBy') ?? '',
      updatedAt: reader.dateTimeOrNull('updatedAt'),
    );
  }

  final String key;
  final String title;
  final String body;

  /// `DRAFT` or `PUBLISHED`.
  final String status;
  final String updatedBy;
  final DateTime? updatedAt;

  bool get isPublished => status == 'PUBLISHED';
}

class ContentFaqRow {
  const ContentFaqRow({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.order,
    required this.status,
  });

  factory ContentFaqRow.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return ContentFaqRow(
      id: reader.string('id'),
      question: reader.string('question'),
      answer: reader.string('answer'),
      category: reader.stringOrNull('category') ?? 'General',
      order: reader.integer('order'),
      status: reader.string('status'),
    );
  }

  final String id;
  final String question;
  final String answer;
  final String category;
  final int order;
  final String status;

  bool get isPublished => status == 'PUBLISHED';
}

class ContentContact {
  const ContentContact({
    required this.configured,
    this.phone = '',
    this.email = '',
    this.address = '',
    this.hours = '',
  });

  factory ContentContact.fromJson(JsonMap json) {
    final reader = JsonReader(json);
    return ContentContact(
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

/// The admin content endpoints. Every method throws [ContentApiError].
class ContentApi {
  ContentApi(this._client);

  final ApiClient _client;
  static const String _base = 'admin/content';

  Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ContentApiError {
      rethrow;
    } on Object catch (error) {
      throw ContentApiError.from(error);
    }
  }

  List<T> _list<T>(Object? data, T Function(JsonMap) read) => <T>[
    for (final item in data is List ? data : const <Object?>[])
      if (item is Map) read(asJsonMap(item)),
  ];

  Future<List<ContentPageDraft>> pages() => _run(() async {
    final response = await _client.get('$_base/pages');
    return _list(response.data, ContentPageDraft.fromJson);
  });

  Future<ContentPageDraft> savePage(
    String key, {
    required String title,
    required String body,
    required bool publish,
  }) => _run(() async {
    final response = await _client.put(
      '$_base/pages/$key',
      body: <String, Object?>{
        'title': title,
        'body': body,
        'status': publish ? 'PUBLISHED' : 'DRAFT',
      },
    );
    return ContentPageDraft.fromJson(asJsonMap(response.data! as Map));
  });

  Future<List<ContentFaqRow>> faqs({String search = '', String? status}) =>
      _run(() async {
        final response = await _client.get(
          '$_base/faqs',
          query: <String, Object?>{
            'pageSize': 100,
            if (search.trim().isNotEmpty) 'search': search.trim(),
            'status': ?status,
          },
        );
        return _list(response.data, ContentFaqRow.fromJson);
      });

  Future<void> saveFaq({
    String? id,
    required String question,
    required String answer,
    required String category,
    required bool publish,
  }) => _run(() async {
    final body = <String, Object?>{
      'question': question,
      'answer': answer,
      'category': category,
      'status': publish ? 'PUBLISHED' : 'DRAFT',
    };
    if (id == null) {
      await _client.post('$_base/faqs', body: body);
    } else {
      await _client.patch('$_base/faqs/$id', body: body);
    }
  });

  Future<void> deleteFaq(String id) =>
      _run(() => _client.delete('$_base/faqs/$id'));

  Future<ContentContact> contact() => _run(() async {
    final response = await _client.get('$_base/contact');
    return ContentContact.fromJson(asJsonMap(response.data! as Map));
  });

  Future<ContentContact> saveContact(ContentContact value) => _run(() async {
    final response = await _client.put(
      '$_base/contact',
      body: <String, Object?>{
        'phone': value.phone,
        'email': value.email,
        'address': value.address,
        'hours': value.hours,
      },
    );
    return ContentContact.fromJson(asJsonMap(response.data! as Map));
  });
}
