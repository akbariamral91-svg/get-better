import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_icons.dart';
import '../utils/dates.dart';
import '../widgets/common.dart';

/// تب «یادداشت‌ها» با دو بخش: یادداشت‌های متنی (کارت‌ها، سنجاق، جست‌وجو، برچسب) و اتفاقات روز.
class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});
  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  int _view = 0; // ۰ یادداشت‌ها، ۱ اتفاقات روز
  final _search = TextEditingController();
  int? _tagFilter;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        icon: const Icon(Icons.add),
        label: Text(_view == 0 ? 'یادداشت جدید' : 'اتفاق جدید'),
        onPressed: () => _view == 0 ? openNoteEditor(context) : openEventForm(context),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 0, label: Text('یادداشت‌ها'), icon: Icon(Icons.sticky_note_2_outlined)),
                ButtonSegment(value: 1, label: Text('اتفاقات روز'), icon: Icon(Icons.auto_awesome_outlined)),
              ],
              selected: {_view},
              onSelectionChanged: (v) => setState(() => _view = v.first),
            ),
          ),
        ),
        Expanded(
          child: _view == 0
              ? _NotesPane(
                  s: s,
                  search: _search,
                  tagFilter: _tagFilter,
                  onFilter: (id) => setState(() => _tagFilter = id),
                  onQuery: () => setState(() {}),
                )
              : _EventsList(s),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- یادداشت‌ها

/// یکسان‌سازی متن برای جست‌وجو (حروف عربی/فارسی، ارقام، کشیده)
String normalizeSearch(String t) {
  var s = t.toLowerCase().replaceAll('ي', 'ی').replaceAll('ك', 'ک').replaceAll('ـ', '');
  const fa = '۰۱۲۳۴۵۶۷۸۹', ar = '٠١٢٣٤٥٦٧٨٩';
  for (var i = 0; i < 10; i++) {
    s = s.replaceAll(fa[i], '$i').replaceAll(ar[i], '$i');
  }
  return s;
}

/// فیلتر یادداشت‌ها بر اساس برچسب و جست‌وجو در عنوان و متن (ترتیب ورودی حفظ می‌شود).
List<Note> filterNotes(List<Note> all, {int? tagId, String query = ''}) {
  final q = normalizeSearch(query.trim());
  return all.where((n) {
    if (tagId != null && !n.tagIds.contains(tagId)) return false;
    if (q.isEmpty) return true;
    return normalizeSearch(n.title).contains(q) || normalizeSearch(n.body).contains(q);
  }).toList();
}

class _NotesPane extends StatelessWidget {
  final AppState s;
  final TextEditingController search;
  final int? tagFilter;
  final ValueChanged<int?> onFilter;
  final VoidCallback onQuery;
  const _NotesPane({required this.s, required this.search, required this.tagFilter, required this.onFilter, required this.onQuery});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // اگر برچسبِ فیلترشده حذف شده باشد، فیلتر نادیده گرفته می‌شود.
    final activeTag = (tagFilter != null && s.tagById(tagFilter!) != null) ? tagFilter : null;
    final shown = filterNotes(s.notes, tagId: activeTag, query: search.text);
    final pinned = shown.where((n) => n.pinned).toList();
    final others = shown.where((n) => !n.pinned).toList();
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6).toDouble();

    SliverPadding grid(List<Note> list) => SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              mainAxisExtent: 172 * scale,
            ),
            delegate: SliverChildBuilderDelegate((_, i) => _NoteCard(note: list[i], s: s), childCount: list.length),
          ),
        );

    Widget header(String t) => SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
            child: Text(t, style: TextStyle(color: c.muted, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        );

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: TextField(
          controller: search,
          onChanged: (_) => onQuery(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'جست‌وجو در عنوان و متن یادداشت‌ها',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'پاک‌کردن جست‌وجو',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      search.clear();
                      onQuery();
                    },
                  ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
      SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            ChoiceChip(label: const Text('همه'), selected: activeTag == null, onSelected: (_) => onFilter(null)),
            for (final t in s.tags) ...[
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: CircleAvatar(radius: 6, backgroundColor: Color(t.color)),
                label: Text(t.name),
                selected: activeTag == t.id,
                onSelected: (_) => onFilter(activeTag == t.id ? null : t.id),
              ),
            ],
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.sell_outlined, size: 16),
              label: const Text('مدیریت برچسب‌ها'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TagManagerScreen())),
            ),
          ],
        ),
      ),
      Expanded(
        child: s.notes.isEmpty
            ? ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: const [
                AppCard(child: EmptyState(icon: Icons.sticky_note_2_outlined, message: 'هنوز یادداشتی ثبت نکرده‌ای. با دکمهٔ «یادداشت جدید» شروع کن.')),
              ])
            : shown.isEmpty
                ? ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: const [
                    AppCard(child: EmptyState(icon: Icons.search_off, message: 'یادداشتی با این جست‌وجو یا برچسب پیدا نشد.')),
                  ])
                : CustomScrollView(slivers: [
                    if (pinned.isNotEmpty) ...[header('سنجاق‌شده'), grid(pinned)],
                    if (others.isNotEmpty) ...[
                      if (pinned.isNotEmpty) header('سایر یادداشت‌ها') else const SliverToBoxAdapter(child: SizedBox(height: 6)),
                      grid(others),
                    ],
                    const SliverToBoxAdapter(child: SizedBox(height: 90)),
                  ]),
      ),
    ]);
  }
}

class _NoteCard extends StatelessWidget {
  final Note note;
  final AppState s;
  const _NoteCard({required this.note, required this.s});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = note;
    final tags = [for (final id in n.tagIds) if (s.tagById(id) != null) s.tagById(id)!];
    final hasTitle = n.title.trim().isNotEmpty;
    final body = n.body.trim();
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openNoteEditor(context, note: n),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    n.displayTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, height: 1.4),
                  ),
                ),
              ),
              SizedBox(
                width: 34,
                height: 34,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: n.pinned ? 'برداشتن سنجاق' : 'سنجاق‌کردن',
                  icon: Icon(n.pinned ? Icons.push_pin : Icons.push_pin_outlined, size: 19, color: n.pinned ? c.gold : c.muted),
                  onPressed: () async {
                    final err = await s.toggleNotePin(n.id!);
                    if (err != null && context.mounted) toast(context, err);
                  },
                ),
              ),
            ]),
            if (hasTitle && body.isNotEmpty)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 6),
                  child: ClipRect(
                    child: Text(body, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: c.muted, fontSize: 13, height: 1.5)),
                  ),
                ),
              )
            else
              const Spacer(),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Wrap(spacing: 4, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                for (final t in tags.take(2)) _TagDot(t),
                if (tags.length > 2) Text('+${faDigits(tags.length - 2)}', style: TextStyle(color: c.muted, fontSize: 11)),
              ]),
            ),
            const SizedBox(height: 4),
            Text(jalaliLabel(parseDay(n.updatedAt)), style: TextStyle(color: c.muted, fontSize: 11)),
          ]),
        ),
      ),
    );
  }
}

class _TagDot extends StatelessWidget {
  final NoteTag t;
  const _TagDot(this.t);
  @override
  Widget build(BuildContext context) {
    final col = Color(t.color);
    return Container(
      constraints: const BoxConstraints(maxWidth: 74),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: col.withOpacity(0.18), borderRadius: BorderRadius.circular(12)),
      child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: context.colors.text)),
    );
  }
}

Future<void> openNoteEditor(BuildContext context, {Note? note}) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)));

/// صفحهٔ ایجاد/ویرایش یادداشت؛ متن کامل (هر قدر طولانی) اینجا قابل دسترسی و ویرایش است.
class NoteEditorScreen extends StatefulWidget {
  final Note? note;
  const NoteEditorScreen({super.key, this.note});
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = TextEditingController(text: widget.note?.body ?? '');
  late final Set<int> _tagIds = {...?widget.note?.tagIds};
  late bool _pinned = widget.note?.pinned ?? false;
  bool _saving = false;

  late final String _t0, _b0;
  late final Set<int> _tags0;
  late final bool _pin0;

  bool get _dirty =>
      _title.text != _t0 || _body.text != _b0 || _pinned != _pin0 || _tagIds.length != _tags0.length || !_tagIds.containsAll(_tags0);

  @override
  void initState() {
    super.initState();
    _t0 = _title.text;
    _b0 = _body.text;
    _tags0 = {..._tagIds};
    _pin0 = _pinned;
    _title.addListener(_refresh);
    _body.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final s = context.read<AppState>();
    setState(() => _saving = true);
    final valid = _tagIds.where((id) => s.tagById(id) != null).toList();
    final err = await s.saveNote(id: widget.note?.id, title: _title.text, body: _body.text, pinned: _pinned, tagIds: valid);
    if (!mounted) return;
    if (err != null) {
      setState(() => _saving = false);
      toast(context, err);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final ok = await confirm(context, 'حذف یادداشت', 'این یادداشت برای همیشه حذف می‌شود. ادامه می‌دهی؟', ok: 'حذف کن');
    if (!ok || !mounted) return;
    final err = await context.read<AppState>().deleteNote(widget.note!.id!);
    if (!mounted) return;
    if (err != null) {
      toast(context, err);
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _newTag() async {
    final s = context.read<AppState>();
    final before = s.tags.map((t) => t.id).toSet();
    final ok = await showTagDialog(context);
    if (ok != true || !mounted) return;
    for (final t in s.tags) {
      if (!before.contains(t.id)) setState(() => _tagIds.add(t.id!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.colors;
    return PopScope(
      canPop: !_dirty || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirm(context, 'خروج بدون ذخیره', 'تغییرات ذخیره‌نشده از بین می‌روند. خارج می‌شوی؟', ok: 'خروج');
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.note == null ? 'یادداشت جدید' : 'ویرایش یادداشت'),
          actions: [
            IconButton(
              tooltip: _pinned ? 'برداشتن سنجاق' : 'سنجاق‌کردن',
              icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined, color: _pinned ? c.gold : null),
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            if (widget.note != null) IconButton(tooltip: 'حذف', icon: const Icon(Icons.delete_outline), onPressed: _delete),
            IconButton(tooltip: 'ذخیره', icon: const Icon(Icons.check), onPressed: _saving ? null : _save),
          ],
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          TextField(
            controller: _title,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(hintText: 'عنوان'),
          ),
          const SizedBox(height: 12),
          Text('برچسب‌ها', style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final t in s.tags)
              FilterChip(
                avatar: CircleAvatar(radius: 6, backgroundColor: Color(t.color)),
                label: Text(t.name),
                selected: _tagIds.contains(t.id),
                onSelected: (v) => setState(() => v ? _tagIds.add(t.id!) : _tagIds.remove(t.id!)),
              ),
            ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('برچسب جدید'), onPressed: _newTag),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _body,
            minLines: 12,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            style: const TextStyle(height: 1.8),
            decoration: const InputDecoration(hintText: 'متن یادداشت…'),
          ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- برچسب‌ها

const tagPalette = <int>[
  0xFFE8B84A, 0xFF4CC38A, 0xFF5B8DEF, 0xFFE5737A, 0xFFB07CE8,
  0xFF3FC1C9, 0xFFF08A4B, 0xFFE06CA8, 0xFF8BC34A, 0xFF8E9AC0,
];

/// ساخت یا ویرایش برچسب؛ true یعنی ذخیره شد.
Future<bool?> showTagDialog(BuildContext context, {NoteTag? tag}) {
  final s = context.read<AppState>();
  final name = TextEditingController(text: tag?.name ?? '');
  var color = tag?.color ?? tagPalette.first;
  String? error;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSt) => AlertDialog(
        title: Text(tag == null ? 'برچسب جدید' : 'ویرایش برچسب'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: name, autofocus: true, maxLength: 24, decoration: InputDecoration(labelText: 'نام برچسب', counterText: '', errorText: error)),
          const SizedBox(height: 14),
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final col in tagPalette)
              Semantics(
                button: true,
                selected: col == color,
                label: 'رنگ برچسب',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setSt(() => color = col),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Color(col),
                      shape: BoxShape.circle,
                      border: col == color ? Border.all(color: ctx.colors.text, width: 3) : null,
                    ),
                    child: col == color ? const Icon(Icons.check, size: 18, color: Colors.black87) : null,
                  ),
                ),
              ),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          TextButton(
            onPressed: () async {
              final err = await s.saveTag(id: tag?.id, name: name.text, color: color);
              if (err != null) {
                setSt(() => error = err);
                return;
              }
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    ),
  );
}

/// مدیریت برچسب‌ها: ساخت، تغییر نام/رنگ، حذف. حذف برچسب هیچ یادداشتی را پاک نمی‌کند.
class TagManagerScreen extends StatelessWidget {
  const TagManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('مدیریت برچسب‌ها')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        icon: const Icon(Icons.add),
        label: const Text('برچسب جدید'),
        onPressed: () => showTagDialog(context),
      ),
      body: s.tags.isEmpty
          ? ListView(padding: const EdgeInsets.all(16), children: const [
              AppCard(child: EmptyState(icon: Icons.sell_outlined, message: 'هنوز برچسبی نساخته‌ای. برچسب‌ها به دسته‌بندی و فیلتر یادداشت‌ها کمک می‌کنند.')),
            ])
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 90), children: [
              for (final t in s.tags)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                    child: Row(children: [
                      CircleAvatar(radius: 9, backgroundColor: Color(t.color)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(t.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text('${faDigits(s.notesWithTag(t.id!).length)} یادداشت', style: TextStyle(color: c.muted, fontSize: 12)),
                        ]),
                      ),
                      IconButton(tooltip: 'ویرایش برچسب', icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => showTagDialog(context, tag: t)),
                      IconButton(
                        tooltip: 'حذف برچسب',
                        icon: Icon(Icons.delete_outline, size: 20, color: c.muted),
                        onPressed: () async {
                          final n = s.notesWithTag(t.id!).length;
                          final ok = await confirm(
                            context,
                            'حذف برچسب',
                            n == 0
                                ? 'برچسب «${t.name}» حذف می‌شود.'
                                : 'برچسب «${t.name}» از ${faDigits(n)} یادداشت برداشته می‌شود. خود یادداشت‌ها حذف نمی‌شوند.',
                            ok: 'حذف کن',
                          );
                          if (!ok) return;
                          final err = await s.deleteTag(t.id!);
                          if (err != null && context.mounted) toast(context, err);
                        },
                      ),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

// ---------------------------------------------------------------- اتفاقات روز

class _EventsList extends StatelessWidget {
  final AppState s;
  const _EventsList(this.s);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (s.dayEvents.isEmpty) {
      return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: const [
        AppCard(child: EmptyState(icon: Icons.auto_awesome_outlined, message: 'هنوز اتفاقی ثبت نکرده‌ای. چیزهای جالب هر روز را اینجا نگه دار.')),
      ]);
    }
    final children = <Widget>[];
    String? lastDate;
    for (final e in s.dayEvents) {
      if (e.date != lastDate) {
        lastDate = e.date;
        final d = parseDay(e.date);
        final isToday = e.date == s.todayIso;
        children.add(SectionTitle('${isToday ? 'امروز، ' : ''}${weekdayName(d)} ${jalaliFull(d)}'));
      }
      final hasTitle = e.title != null && e.title!.trim().isNotEmpty;
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          onTap: () => openEventForm(context, event: e),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: c.gold.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
              child: Icon(iconFor(e.icon) ?? Icons.auto_awesome, color: c.gold, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (hasTitle) Text(e.title!.trim(), style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(e.body, maxLines: 6, overflow: TextOverflow.ellipsis, style: TextStyle(color: hasTitle ? c.muted : c.text, height: 1.6)),
                const SizedBox(height: 4),
                Row(children: [
                  Icon(Icons.schedule, size: 13, color: c.muted),
                  const SizedBox(width: 4),
                  Text(faDigits(e.time), style: TextStyle(color: c.muted, fontSize: 11)),
                ]),
              ]),
            ),
            IconButton(
              tooltip: 'حذف',
              icon: Icon(Icons.delete_outline, size: 20, color: c.muted),
              onPressed: () async {
                final ok = await confirm(context, 'حذف اتفاق', 'این اتفاق برای همیشه حذف می‌شود. ادامه می‌دهی؟', ok: 'حذف کن');
                if (!ok) return;
                final err = await s.deleteDayEvent(e.id!);
                if (err != null && context.mounted) toast(context, err);
              },
            ),
          ]),
        ),
      ));
    }
    return ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 90), children: children);
  }
}

Future<void> openEventForm(BuildContext context, {DayEvent? event}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EventForm(event: event),
    );

class _EventForm extends StatefulWidget {
  final DayEvent? event;
  const _EventForm({this.event});
  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final _title = TextEditingController(text: widget.event?.title ?? '');
  late final _body = TextEditingController(text: widget.event?.body ?? '');
  late DateTime _date;
  late TimeOfDay _time;
  late String? _icon = widget.event?.icon;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _date = parseDay(e.date);
      final p = e.time.split(':');
      _time = TimeOfDay(hour: int.tryParse(p[0]) ?? 0, minute: int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
    } else {
      final now = DateTime.now();
      _date = dateOnly(now);
      _time = TimeOfDay(hour: now.hour, minute: now.minute);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  String get _timeStr => '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final err = await context.read<AppState>().saveDayEvent(
          id: widget.event?.id,
          title: _title.text,
          body: _body.text,
          date: isoDay(_date),
          time: _timeStr,
          icon: _icon,
        );
    if (!mounted) return;
    if (err != null) {
      setState(() => _saving = false);
      toast(context, err);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.event == null ? 'اتفاق جدید' : 'ویرایش اتفاق', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: _title, decoration: const InputDecoration(labelText: 'عنوان (اختیاری)')),
          const SizedBox(height: 10),
          TextField(controller: _body, minLines: 3, maxLines: 8, decoration: const InputDecoration(labelText: 'چه اتفاقی افتاد؟')),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text('${weekdayName(_date)} ${jalaliLabel(_date)}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _date = dateOnly(d));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.schedule, size: 18),
                label: Text(faDigits(_timeStr)),
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: _time,
                    builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true), child: child!),
                  );
                  if (t != null) setState(() => _time = t);
                },
              ),
            ),
          ]),
          const SizedBox(height: 10),
          IconPickerField(group: IconGroup.events, value: _icon, onChanged: (v) => setState(() => _icon = v)),
          const SizedBox(height: 14),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('ذخیره')),
        ]),
      ),
    );
  }
}
