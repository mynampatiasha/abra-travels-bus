import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_permissions/shared_permissions.dart';
import 'package:shared_theme/shared_theme.dart';
import 'package:shared_ui/shared_ui.dart';

import '../../app/providers.dart';
import 'content_api.dart';

/// Help content and contact: the contact details, the FAQs and the policy
/// pages that the customer app and the website show. Everything on this
/// page is read from, and saved to, the backend.
class AdminContentPage extends ConsumerStatefulWidget {
  const AdminContentPage({super.key});

  @override
  ConsumerState<AdminContentPage> createState() => _AdminContentPageState();
}

class _AdminContentPageState extends ConsumerState<AdminContentPage>
    with SingleTickerProviderStateMixin {
  late final ContentApi _api = ContentApi(
    ref.read(appDependenciesProvider).apiClient,
  );
  late final TabController _tabs = TabController(length: 3, vsync: this);

  // What the person may do. The server checks again; this only hides buttons.
  bool get _canEdit =>
      ref.read(accessProvider).can(PermissionKeys.contentManage);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: TabBar(
                controller: _tabs,
                labelColor: AbraColors.blue,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: AbraColors.blue,
                tabs: const <Tab>[
                  Tab(text: 'Contact details'),
                  Tab(text: 'Frequently asked questions'),
                  Tab(text: 'Policy pages'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: <Widget>[
                  _ContactTab(api: _api, canEdit: _canEdit),
                  _FaqTab(api: _api, canEdit: _canEdit),
                  _PagesTab(api: _api, canEdit: _canEdit),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== shared bits =====

Widget _card({required Widget child}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: Colors.grey.shade300),
  ),
  child: child,
);

void _say(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Loads something when the tab opens and shows loading, a failure with
/// "Try again", or the data.
class _Loader<T> extends StatefulWidget {
  const _Loader({required this.load, required this.builder});

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data, VoidCallback reload)
  builder;

  @override
  State<_Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<_Loader<T>> {
  late Future<T> _future = widget.load();

  void _reload() => setState(() {
    _future = widget.load();
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final text = snapshot.error is ContentApiError
              ? (snapshot.error! as ContentApiError).message
              : 'Something went wrong.';
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(text),
                const SizedBox(height: 12),
                FilledButton(onPressed: _reload, child: const Text('Try again')),
              ],
            ),
          );
        }
        if (!snapshot.hasData) return const AbraLoadingView();
        return widget.builder(context, snapshot.data as T, _reload);
      },
    );
  }
}

// ===== contact details =====

class _ContactTab extends StatelessWidget {
  const _ContactTab({required this.api, required this.canEdit});

  final ContentApi api;
  final bool canEdit;

  @override
  Widget build(BuildContext context) => _Loader<ContentContact>(
    load: api.contact,
    builder: (context, contact, _) =>
        _ContactForm(api: api, contact: contact, canEdit: canEdit),
  );
}

class _ContactForm extends StatefulWidget {
  const _ContactForm({
    required this.api,
    required this.contact,
    required this.canEdit,
  });

  final ContentApi api;
  final ContentContact contact;
  final bool canEdit;

  @override
  State<_ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<_ContactForm> {
  late final _phone = TextEditingController(text: widget.contact.phone);
  late final _email = TextEditingController(text: widget.contact.email);
  late final _address = TextEditingController(text: widget.contact.address);
  late final _hours = TextEditingController(text: widget.contact.hours);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _hours.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.saveContact(
        ContentContact(
          configured: true,
          phone: _phone.text,
          email: _email.text,
          address: _address.text,
          hours: _hours.text,
        ),
      );
      if (mounted) _say(context, 'Contact details saved.');
    } on ContentApiError catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController controller, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: controller,
          readOnly: !widget.canEdit,
          maxLines: lines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.contact.configured
                  ? 'Customers see these details in the app and on the website.'
                  : 'Not saved yet. Customers see no contact details until you save them.',
            ),
            const SizedBox(height: 16),
            _field('Support phone', _phone),
            _field('Support email', _email),
            _field('Address', _address, lines: 2),
            _field('Opening hours', _hours),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
            if (widget.canEdit)
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving...' : 'Save'),
              ),
          ],
        ),
      ),
    );
  }
}

// ===== FAQs =====

class _FaqTab extends StatefulWidget {
  const _FaqTab({required this.api, required this.canEdit});

  final ContentApi api;
  final bool canEdit;

  @override
  State<_FaqTab> createState() => _FaqTabState();
}

class _FaqTabState extends State<_FaqTab> {
  final _search = TextEditingController();
  String? _status;
  late Future<List<ContentFaqRow>> _future = _load();

  Future<List<ContentFaqRow>> _load() =>
      widget.api.faqs(search: _search.text, status: _status);

  void _reload() => setState(() {
    _future = _load();
  });

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _edit([ContentFaqRow? faq]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _FaqDialog(api: widget.api, faq: faq),
    );
    if ((saved ?? false) && mounted) _reload();
  }

  Future<void> _delete(ContentFaqRow faq) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this question?'),
        content: Text(faq.question),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await widget.api.deleteFaq(faq.id);
      if (!mounted) return;
      _say(context, 'Question deleted.');
      _reload();
    } on ContentApiError catch (error) {
      if (mounted) _say(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: (_) => _reload(),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<String?>(
              value: _status,
              hint: const Text('Status'),
              items: const <DropdownMenuItem<String?>>[
                DropdownMenuItem(child: Text('All statuses')),
                DropdownMenuItem(value: 'PUBLISHED', child: Text('Published')),
                DropdownMenuItem(value: 'DRAFT', child: Text('Draft')),
              ],
              onChanged: (value) {
                _status = value;
                _reload();
              },
            ),
            if (widget.canEdit) ...<Widget>[
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _edit,
                icon: const Icon(Icons.add),
                label: const Text('Add question'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: FutureBuilder<List<ContentFaqRow>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                final error = snapshot.error;
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        error is ContentApiError
                            ? error.message
                            : 'Something went wrong.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _reload,
                        child: const Text('Try again'),
                      ),
                    ],
                  ),
                );
              }
              final faqs = snapshot.data;
              if (faqs == null) return const AbraLoadingView();
              if (faqs.isEmpty) {
                return const Center(child: Text('No questions yet.'));
              }
              return ListView.separated(
                itemCount: faqs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final faq = faqs[index];
                  return _card(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                faq.question,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(faq.answer),
                              const SizedBox(height: 8),
                              Text(
                                '${faq.category}  |  ${faq.isPublished ? 'Published' : 'Draft'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.canEdit) ...<Widget>[
                          TextButton(
                            onPressed: () => _edit(faq),
                            child: const Text('Edit'),
                          ),
                          TextButton(
                            onPressed: () => _delete(faq),
                            child: const Text('Delete'),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FaqDialog extends StatefulWidget {
  const _FaqDialog({required this.api, this.faq});

  final ContentApi api;
  final ContentFaqRow? faq;

  @override
  State<_FaqDialog> createState() => _FaqDialogState();
}

class _FaqDialogState extends State<_FaqDialog> {
  late final _question = TextEditingController(text: widget.faq?.question);
  late final _answer = TextEditingController(text: widget.faq?.answer);
  late final _category = TextEditingController(
    text: widget.faq?.category ?? 'General',
  );
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _save({required bool publish}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.saveFaq(
        id: widget.faq?.id,
        question: _question.text,
        answer: _answer.text,
        category: _category.text,
        publish: publish,
      );
      if (mounted) Navigator.pop(context, true);
    } on ContentApiError catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.faq == null ? 'Add question' : 'Edit question'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _question,
                decoration: const InputDecoration(labelText: 'Question'),
              ),
              TextField(
                controller: _answer,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Answer'),
              ),
              TextField(
                controller: _category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        OutlinedButton(
          onPressed: _saving ? null : () => _save(publish: false),
          child: const Text('Save draft'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(publish: true),
          child: const Text('Publish'),
        ),
      ],
    );
  }
}

// ===== policy pages =====

class _PagesTab extends StatelessWidget {
  const _PagesTab({required this.api, required this.canEdit});

  final ContentApi api;
  final bool canEdit;

  @override
  Widget build(BuildContext context) => _Loader<List<ContentPageDraft>>(
    load: api.pages,
    builder: (context, pages, reload) => ListView.separated(
      itemCount: pages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final page = pages[index];
        return _card(
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      page.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      page.isPublished
                          ? 'Published${page.updatedBy.isEmpty ? '' : ' by ${page.updatedBy}'}'
                          : (page.body.isEmpty
                                ? 'Not written yet'
                                : 'Draft, not shown to customers'),
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () async {
                  final saved = await showDialog<bool>(
                    context: context,
                    builder: (_) =>
                        _PageDialog(api: api, page: page, canEdit: canEdit),
                  );
                  if (saved ?? false) reload();
                },
                child: Text(canEdit ? 'Edit' : 'View'),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _PageDialog extends StatefulWidget {
  const _PageDialog({
    required this.api,
    required this.page,
    required this.canEdit,
  });

  final ContentApi api;
  final ContentPageDraft page;
  final bool canEdit;

  @override
  State<_PageDialog> createState() => _PageDialogState();
}

class _PageDialogState extends State<_PageDialog> {
  late final _title = TextEditingController(text: widget.page.title);
  late final _body = TextEditingController(text: widget.page.body);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save({required bool publish}) async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.savePage(
        widget.page.key,
        title: _title.text,
        body: _body.text,
        publish: publish,
      );
      if (mounted) Navigator.pop(context, true);
    } on ContentApiError catch (error) {
      if (mounted) {
        setState(() {
          _error = error.message;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.page.title),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: _title,
                readOnly: !widget.canEdit,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _body,
                readOnly: !widget.canEdit,
                minLines: 8,
                maxLines: 14,
                decoration: const InputDecoration(
                  labelText: 'Text (a blank line starts a new paragraph)',
                  alignLabelWithHint: true,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: Text(widget.canEdit ? 'Cancel' : 'Close'),
        ),
        if (widget.canEdit) ...<Widget>[
          if (widget.page.isPublished)
            OutlinedButton(
              onPressed: _saving ? null : () => _save(publish: false),
              child: const Text('Unpublish'),
            )
          else
            OutlinedButton(
              onPressed: _saving ? null : () => _save(publish: false),
              child: const Text('Save draft'),
            ),
          FilledButton(
            onPressed: _saving ? null : () => _save(publish: true),
            child: const Text('Publish'),
          ),
        ],
      ],
    );
  }
}
