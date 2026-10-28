import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as web;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TeacherLocalApp());
}

const _classes = <String, String>{
  'hafizlik1': 'قارىلىق 1-سىنىپ',
  'hafizlik2': 'ئىجازەت سىنىپى',
  'hafizlik3': 'قارىلىق 3-سىنىپ',
};
const _weekdays = <String>[
  'دۈشەنبە',
  'سەيشەنبە',
  'چارشەنبە',
  'پەيشەنبە',
  'جۈمە',
  'شەنبە',
];
const _months = <String>[
  'يانۋار',
  'فېۋرال',
  'مارت',
  'ئاپرېل',
  'ماي',
  'ئىيۇن',
  'ئىيۇل',
  'ئاۋغۇست',
  'سېنتەبىر',
  'ئۆكتەبىر',
  'نويابىر',
  'دېكابىر',
];

String _dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
DateTime _weekStart(DateTime date) =>
    DateTime(date.year, date.month, date.day - date.weekday + 1);

class StudentRecord {
  const StudentRecord({
    required this.id,
    required this.name,
    required this.order,
    this.onLeave = false,
  });

  final String id;
  final String name;
  final int order;
  final bool onLeave;

  StudentRecord copyWith({String? name, int? order, bool? onLeave}) =>
      StudentRecord(
        id: id,
        name: name ?? this.name,
        order: order ?? this.order,
        onLeave: onLeave ?? this.onLeave,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'order': order,
        'onLeave': onLeave,
      };

  factory StudentRecord.fromJson(Map<String, dynamic> json) => StudentRecord(
        id: json['id'].toString(),
        name: json['name']?.toString() ?? '',
        order: (json['order'] as num?)?.toInt() ?? 0,
        onLeave: json['onLeave'] == true,
      );
}

class LessonRecord {
  const LessonRecord({
    required this.studentId,
    required this.date,
    required this.attended,
    this.lesson = '',
    this.homework = '',
    this.pageCount = 0,
    this.juzCount = 0,
    this.lineCount = 0,
    this.isTakrar = false,
    this.isTeravih = false,
  });

  final String studentId;
  final String date;
  final bool attended;
  final String lesson;
  final String homework;
  final int pageCount;
  final int juzCount;
  final int lineCount;
  final bool isTakrar;
  final bool isTeravih;

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'date': date,
        'attended': attended,
        'lesson': lesson,
        'homework': homework,
        'pageCount': pageCount,
        'juzCount': juzCount,
        'lineCount': lineCount,
        'isTakrar': isTakrar,
        'isTeravih': isTeravih,
      };

  factory LessonRecord.fromJson(Map<String, dynamic> json) => LessonRecord(
        studentId: json['studentId'].toString(),
        date: json['date'].toString(),
        attended: json['attended'] == true,
        lesson: json['lesson']?.toString() ?? '',
        homework: json['homework']?.toString() ?? '',
        pageCount: (json['pageCount'] as num?)?.toInt() ?? 0,
        juzCount: (json['juzCount'] as num?)?.toInt() ?? 0,
        lineCount: (json['lineCount'] as num?)?.toInt() ?? 0,
        isTakrar: json['isTakrar'] == true,
        isTeravih: json['isTeravih'] == true,
      );
}

/// All app data lives in this browser's local preferences, separated by class.
class LocalStore extends ChangeNotifier {
  late SharedPreferences _prefs;
  String classId = 'hafizlik2';
  List<StudentRecord> students = [];
  List<LessonRecord> lessons = [];
  bool ready = false;
  bool persistentStorage = false;

  String get className => _classes[classId] ?? _classes['hafizlik2']!;
  String get _storageKey => 'teacher_local_v1_$classId';

  Future<void> open() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final storage = web.window.navigator.storage;
      persistentStorage = (await storage.persisted().toDart).toDart;
      if (!persistentStorage) {
        persistentStorage = (await storage.persist().toDart).toDart;
      }
    } catch (_) {
      persistentStorage = false;
    }
    await selectClass(classId, notify: false);
    ready = true;
    notifyListeners();
  }

  Future<void> selectClass(String id, {bool notify = true}) async {
    classId = _classes.containsKey(id) ? id : 'hafizlik2';
    final raw = _prefs.getString(_storageKey);
    if (raw == null) {
      students = [];
      lessons = [];
    } else {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        students = (data['students'] as List? ?? [])
            .map((item) =>
                StudentRecord.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
        lessons = (data['lessons'] as List? ?? [])
            .map((item) =>
                LessonRecord.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList();
      } catch (_) {
        students = [];
        lessons = [];
      }
    }
    if (notify) notifyListeners();
  }

  Future<void> _save() async {
    await _prefs.setString(
      _storageKey,
      jsonEncode({
        'version': 1,
        'students': students.map((s) => s.toJson()).toList(),
        'lessons': lessons.map((l) => l.toJson()).toList(),
      }),
    );
    notifyListeners();
  }

  Future<void> addStudent(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    students = [
      ...students,
      StudentRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        name: cleanName,
        order: students.length,
      ),
    ];
    await _save();
  }

  Future<void> renameStudent(String id, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return;
    students = students
        .map((s) => s.id == id ? s.copyWith(name: cleanName) : s)
        .toList();
    await _save();
  }

  Future<void> deleteStudent(String id) async {
    students = students.where((s) => s.id != id).toList();
    lessons = lessons.where((l) => l.studentId != id).toList();
    await _save();
  }

  Future<void> setOnLeave(StudentRecord student, bool value) async {
    students = students
        .map((s) => s.id == student.id ? s.copyWith(onLeave: value) : s)
        .toList();
    await _save();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final active = students.where((s) => !s.onLeave).toList();
    if (newIndex > oldIndex) newIndex--;
    final moved = active.removeAt(oldIndex);
    active.insert(newIndex, moved);
    final leave = students.where((s) => s.onLeave).toList();
    students = [
      ...active.asMap().entries.map((e) => e.value.copyWith(order: e.key)),
      ...leave
          .asMap()
          .entries
          .map((e) => e.value.copyWith(order: active.length + e.key)),
    ];
    await _save();
  }

  LessonRecord? lessonFor(String studentId, DateTime date) {
    final key = _dateKey(date);
    for (final lesson in lessons.reversed) {
      if (lesson.studentId == studentId && lesson.date == key) return lesson;
    }
    return null;
  }

  Future<void> saveLesson(LessonRecord lesson) async {
    lessons.removeWhere(
        (l) => l.studentId == lesson.studentId && l.date == lesson.date);
    lessons.add(lesson);
    await _save();
  }

  Future<void> importBackup(String raw) async {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final importedStudents = (json['students'] as List)
        .map((item) =>
            StudentRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    final importedLessons = (json['lessons'] as List)
        .map((item) =>
            LessonRecord.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
    students = importedStudents;
    lessons = importedLessons;
    await _save();
  }

  String exportBackup() => const JsonEncoder.withIndent('  ').convert({
        'app': 'ogrenci-takip-local',
        'version': 1,
        'classId': classId,
        'students': students.map((s) => s.toJson()).toList(),
        'lessons': lessons.map((l) => l.toJson()).toList(),
      });
}

class TeacherLocalApp extends StatefulWidget {
  const TeacherLocalApp({super.key});

  @override
  State<TeacherLocalApp> createState() => _TeacherLocalAppState();
}

class _TeacherLocalAppState extends State<TeacherLocalApp> {
  final LocalStore store = LocalStore();

  @override
  void initState() {
    super.initState();
    store.open();
  }

  @override
  void dispose() {
    store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'مىئراج ئىجازەت سىنىپى ئوقۇغۇچىلىرى',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
          fontFamily: 'UyghurFont',
          fontFamilyFallback: const ['NotoNaskhArabic'],
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
        ),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        ),
        home: AnimatedBuilder(
          animation: store,
          builder: (context, _) => store.ready
              ? DashboardPage(store: store)
              : const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
        ),
      );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.store});
  final LocalStore store;

  @override
  Widget build(BuildContext context) {
    final active = store.students.where((s) => !s.onLeave).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final onLeave = store.students.where((s) => s.onLeave).toList();
    final today = DateTime.now();
    return Scaffold(
      backgroundColor: const Color(0xfff6f3f8),
      appBar: AppBar(
        title: PopupMenuButton<String>(
          tooltip: 'سىنىپ تاللاش',
          onSelected: store.selectClass,
          itemBuilder: (context) => _classes.entries
              .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(store.className),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'دوكلات',
            icon: const Icon(Icons.bar_chart),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReportPage(store: store),
            )),
          ),
          IconButton(
            tooltip: 'ئوقۇغۇچى قوشۇش',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: () => _studentDialog(context, store),
          ),
          IconButton(
            tooltip: 'سانلىق مەلۇماتنى ساقلاش / قايتۇرۇش',
            icon: const Icon(Icons.backup_outlined),
            onPressed: () => _backupDialog(context, store),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.teal.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text('جەمئىي ${active.length} ئوقۇغۇچى'),
          ),
          Container(
            width: double.infinity,
            color: store.persistentStorage
                ? Colors.green.shade50
                : Colors.amber.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Icon(
                    store.persistentStorage
                        ? Icons.verified_user_outlined
                        : Icons.info_outline,
                    size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    store.persistentStorage
                        ? 'بۇ تور بېكەتنىڭ سانلىق مەلۇماتى ئۈسكۈنىدە ساقلىنىدۇ.'
                        : 'سانلىق مەلۇمات بۇ توركۆرگۈدە ساقلىنىدۇ؛ زاپاس چۈشۈرۈۋېلىڭ.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (onLeave.isNotEmpty)
            ExpansionTile(
              collapsedBackgroundColor: Colors.amber.shade50,
              backgroundColor: Colors.amber.shade50,
              title: Text('رۇخسەتتىكى ئوقۇغۇچىلار: ${onLeave.length}',
                  style: TextStyle(color: Colors.orange.shade900)),
              children: onLeave
                  .map((student) => _studentTile(context, store, student, today,
                      isOnLeave: true))
                  .toList(),
            ),
          Expanded(
            child: active.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_outline, size: 56),
                        const SizedBox(height: 12),
                        const Text('تېخى ئوقۇغۇچى قوشۇلمىدى.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => _studentDialog(context, store),
                          icon: const Icon(Icons.add),
                          label: const Text('ئوقۇغۇچى قوشۇش'),
                        ),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.all(10),
                    buildDefaultDragHandles: false,
                    itemCount: active.length,
                    onReorder: store.reorder,
                    itemBuilder: (context, index) => _studentTile(
                      context,
                      store,
                      active[index],
                      today,
                      index: index,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _studentTile(
    BuildContext context,
    LocalStore store,
    StudentRecord student,
    DateTime today, {
    int? index,
    bool isOnLeave = false,
  }) {
    final log = store.lessonFor(student.id, today);
    final attended = log?.attended ?? false;
    return Card(
      key: ValueKey(student.id),
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _lessonDialog(context, store, student, today),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (!isOnLeave)
                ReorderableDragStartListener(
                  index: index!,
                  child: const Padding(
                    padding: EdgeInsetsDirectional.only(end: 8),
                    child: Icon(Icons.drag_indicator, color: Colors.grey),
                  ),
                ),
              CircleAvatar(
                backgroundColor: Colors.teal.shade100,
                child: Text(student.name.isEmpty ? '?' : student.name[0]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (log != null && log.lesson.isNotEmpty)
                      Text(_lessonSummary(log),
                          maxLines: 2, overflow: TextOverflow.ellipsis)
                    else if (isOnLeave)
                      const Text('رۇخسەتتە')
                    else
                      const Text('تېخى دەرس كىرگۈزۈلمىدى'),
                    if (log?.isTakrar == true || log?.isTeravih == true)
                      Wrap(
                        spacing: 4,
                        children: [
                          if (log!.isTakrar) _tag('تەكرار', Colors.orange),
                          if (log.isTeravih) _tag('تەراۋىھ', Colors.green),
                        ],
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'تاللاشلار',
                onSelected: (value) async {
                  if (value == 'edit') {
                    await _studentDialog(context, store, student: student);
                  } else if (value == 'leave') {
                    await store.setOnLeave(student, !student.onLeave);
                  } else if (value == 'delete') {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('ئوقۇغۇچىنى ئۆچۈرۈش'),
                        content: Text('${student.name} نى ئۆچۈرەمسىز؟'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('بىكار قىلىش')),
                          FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('ئۆچۈرۈش')),
                        ],
                      ),
                    );
                    if (yes == true) await store.deleteStudent(student.id);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'edit', child: Text('ئىسىمنى تەھرىرلەش')),
                  PopupMenuItem(
                    value: 'leave',
                    child: Text(student.onLeave
                        ? 'رۇخسەتتىن قايتۇرۇش'
                        : 'رۇخسەتكە چىقىرىش'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('ئۆچۈرۈش')),
                ],
              ),
              const SizedBox(width: 6),
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: isOnLeave
                    ? null
                    : () => store.saveLesson(LessonRecord(
                          studentId: student.id,
                          date: _dateKey(today),
                          attended: !attended,
                          lesson: log?.lesson ?? '',
                          homework: log?.homework ?? '',
                          pageCount: log?.pageCount ?? 0,
                          juzCount: log?.juzCount ?? 0,
                          lineCount: log?.lineCount ?? 0,
                          isTakrar: log?.isTakrar ?? false,
                          isTeravih: log?.isTeravih ?? false,
                        )),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: attended ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: attended ? Colors.green : Colors.red),
                  ),
                  child: Text(
                    attended ? 'ئۆتكۈزدى' : 'ئۆتكۈزمىدى',
                    style: TextStyle(
                      color: attended
                          ? Colors.green.shade800
                          : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportPage extends StatefulWidget {
  const ReportPage({super.key, required this.store});
  final LocalStore store;

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  DateTime _week = _weekStart(DateTime.now());
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('دەرس ئەھۋالى'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(icon: Icon(Icons.calendar_view_week), text: 'ھەپتىلىك'),
              Tab(icon: Icon(Icons.calendar_month), text: 'ئايلىق'),
            ],
          ),
        ),
        body: AnimatedBuilder(
          animation: widget.store,
          builder: (context, _) => TabBarView(
            controller: _tabs,
            children: [
              _weeklyReport(),
              _monthlyReport(),
            ],
          ),
        ),
      );

  Widget _weeklyReport() {
    final days = List.generate(6, (i) => _week.add(Duration(days: i)));
    final active = widget.store.students.where((s) => !s.onLeave).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return Column(
      children: [
        _dateNavigator(
          label: '${_shortDate(days.first)} – ${_shortDate(days.last)}',
          previous: () =>
              setState(() => _week = _week.subtract(const Duration(days: 7))),
          next: () =>
              setState(() => _week = _week.add(const Duration(days: 7))),
        ),
        Expanded(
          child: active.isEmpty
              ? const Center(child: Text('ئوقۇغۇچى يوق'))
              : Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      child: DataTable(
                        headingRowColor:
                            WidgetStatePropertyAll(Colors.teal.shade100),
                        columns: [
                          const DataColumn(label: Text('ئوقۇغۇچى')),
                          for (var i = 0; i < days.length; i++)
                            DataColumn(
                              label: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(_weekdays[i]),
                                  Text(_shortDate(days[i]),
                                      style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                        ],
                        rows: active.map((student) {
                          return DataRow(cells: [
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 150),
                              child: Text(student.name,
                                  overflow: TextOverflow.ellipsis),
                            )),
                            for (final day in days)
                              DataCell(_reportCell(
                                  widget.store.lessonFor(student.id, day))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _monthlyReport() {
    final students = widget.store.students.where((s) => !s.onLeave).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final start = DateTime(_month.year, _month.month);
    final end = DateTime(_month.year, _month.month + 1);
    return Column(
      children: [
        _dateNavigator(
          label: '${_months[_month.month - 1]} ${_month.year}',
          previous: () =>
              setState(() => _month = DateTime(_month.year, _month.month - 1)),
          next: () =>
              setState(() => _month = DateTime(_month.year, _month.month + 1)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: students.length,
            itemBuilder: (context, index) {
              final student = students[index];
              final logs = widget.store.lessons.where((l) {
                if (l.studentId != student.id) return false;
                final date = DateTime.tryParse(l.date);
                return date != null &&
                    !date.isBefore(start) &&
                    date.isBefore(end);
              }).toList()
                ..sort((a, b) => a.date.compareTo(b.date));
              final present = logs.where((l) => l.attended).length;
              final pages = logs.fold<int>(0, (sum, l) => sum + l.pageCount);
              final juz = logs.fold<int>(0, (sum, l) => sum + l.juzCount);
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: ListTile(
                  title: Text(student.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      'قاتناشقان كۈن: $present / ${logs.length}   •   بەت: $pages   •   پارە: $juz'),
                  isThreeLine: false,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _dateNavigator(
          {required String label,
          required VoidCallback previous,
          required VoidCallback next}) =>
      Container(
        color: Colors.teal.shade50,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
                onPressed: previous, icon: const Icon(Icons.chevron_left)),
            Text(label,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(onPressed: next, icon: const Icon(Icons.chevron_right)),
          ],
        ),
      );

  Widget _reportCell(LessonRecord? log) {
    if (log == null)
      return const Text('–', style: TextStyle(color: Colors.grey));
    final color = log.attended ? Colors.teal.shade700 : Colors.red.shade700;
    final text = !log.attended
        ? 'كەلمىدى'
        : [
            if (log.lesson.isNotEmpty) log.lesson,
            if (log.pageCount > 0) '${log.pageCount} بەت',
            if (log.juzCount > 0) '${log.juzCount} پارە',
            if (log.lineCount > 0) '${log.lineCount} قۇر',
          ].join(' · ');
    return SizedBox(
      width: 118,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (log.attended && log.pageCount + log.juzCount + log.lineCount > 0)
            _tag(
              [
                if (log.pageCount > 0) '${log.pageCount} بەت',
                if (log.juzCount > 0) '${log.juzCount} پارە',
                if (log.lineCount > 0) '${log.lineCount} قۇر',
              ].join(' '),
              Colors.purple,
            ),
          Text(text.isEmpty && log.attended ? 'ئۆتكۈزدى' : text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: color)),
          if (log.isTakrar) _tag('تەكرار', Colors.orange),
          if (log.isTeravih) _tag('تەراۋىھ', Colors.green),
        ],
      ),
    );
  }
}

Widget _tag(String text, MaterialColor color) => Container(
      margin: const EdgeInsets.only(top: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color.shade800, fontSize: 10)),
    );

String _lessonSummary(LessonRecord log) {
  final parts = <String>[
    if (log.lesson.isNotEmpty) log.lesson,
    if (log.pageCount > 0) '${log.pageCount} بەت',
    if (log.juzCount > 0) '${log.juzCount} پارە',
    if (log.lineCount > 0) '${log.lineCount} قۇر',
  ];
  return parts.join(' · ');
}

Future<void> _studentDialog(BuildContext context, LocalStore store,
    {StudentRecord? student}) async {
  final controller = TextEditingController(text: student?.name ?? '');
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(student == null ? 'ئوقۇغۇچى قوشۇش' : 'ئوقۇغۇچىنى تەھرىرلەش'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'ئوقۇغۇچى ئىسمى'),
        onSubmitted: (value) => Navigator.pop(ctx, value),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('بىكار قىلىش')),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('ساقلاش')),
      ],
    ),
  );
  controller.dispose();
  if (name == null || name.trim().isEmpty) return;
  if (student == null) {
    await store.addStudent(name);
  } else {
    await store.renameStudent(student.id, name);
  }
}

Future<void> _lessonDialog(BuildContext context, LocalStore store,
    StudentRecord student, DateTime date) async {
  final old = store.lessonFor(student.id, date);
  var attended = old?.attended ?? true;
  var takrar = old?.isTakrar ?? false;
  var teravih = old?.isTeravih ?? false;
  final lesson = TextEditingController(text: old?.lesson ?? '');
  final homework = TextEditingController(text: old?.homework ?? '');
  final pages = TextEditingController(text: old?.pageCount.toString() ?? '');
  final juz = TextEditingController(text: old?.juzCount.toString() ?? '');
  final lines = TextEditingController(text: old?.lineCount.toString() ?? '');
  final save = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(student.name),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('ئۆتكۈزدى')),
                    ButtonSegment(value: false, label: Text('ئۆتكۈزمىدى')),
                  ],
                  selected: {attended},
                  onSelectionChanged: (value) =>
                      setDialogState(() => attended = value.first),
                ),
                if (attended) ...[
                  const SizedBox(height: 14),
                  TextField(
                      controller: lesson,
                      decoration: const InputDecoration(
                          labelText: 'دەرس / سۈرە ۋە ئايەت')),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: pages,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'بەت'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: juz,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'پارە'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: TextField(
                            controller: lines,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: 'قۇر'))),
                  ]),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تەكرار'),
                    value: takrar,
                    onChanged: (value) => setDialogState(() => takrar = value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تەراۋىھ'),
                    value: teravih,
                    onChanged: (value) => setDialogState(() => teravih = value),
                  ),
                  TextField(
                      controller: homework,
                      decoration: const InputDecoration(labelText: 'تاپشۇرۇق')),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('بىكار قىلىش')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ساقلاش')),
        ],
      ),
    ),
  );
  if (save == true) {
    await store.saveLesson(LessonRecord(
      studentId: student.id,
      date: _dateKey(date),
      attended: attended,
      lesson: attended ? lesson.text.trim() : '',
      homework: attended ? homework.text.trim() : '',
      pageCount: attended ? int.tryParse(pages.text) ?? 0 : 0,
      juzCount: attended ? int.tryParse(juz.text) ?? 0 : 0,
      lineCount: attended ? int.tryParse(lines.text) ?? 0 : 0,
      isTakrar: attended && takrar,
      isTeravih: attended && teravih,
    ));
  }
  lesson.dispose();
  homework.dispose();
  pages.dispose();
  juz.dispose();
  lines.dispose();
}

Future<void> _backupDialog(BuildContext context, LocalStore store) async {
  final controller = TextEditingController(text: store.exportBackup());
  String? error;
  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: const Text('سانلىق مەلۇماتنى ساقلاش / قايتۇرۇش'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'زاپاسنى ئۈسكۈنىگە JSON ھۆججىتى قىلىپ چۈشۈرۈڭ ياكى كېيىن قايتا ئەكىرىڭ.'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                minLines: 6,
                maxLines: 12,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  errorText: error,
                  hintText: 'زاپاس JSON نى بۇ يەرگە چاپلاڭ',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _downloadBackup(store),
            child: const Text('ھۆججەت قىلىپ چۈشۈرۈش'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                  ClipboardData(text: store.exportBackup()));
              if (ctx.mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('زاپاس كۆچۈرۈلدى')));
            },
            child: const Text('زاپاسنى كۆچۈرۈش'),
          ),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('تاقاش')),
          FilledButton(
            onPressed: () async {
              try {
                await store.importBackup(controller.text);
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (_) {
                setState(
                    () => error = 'زاپاس سانلىق مەلۇمات خاتا ياكى تولۇق ئەمەس');
              }
            },
            child: const Text('زاپاسنى قايتۇرۇش'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

void _downloadBackup(LocalStore store) {
  final blob = web.Blob(
    [store.exportBackup().toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download =
        'ogrenci-takip-${store.classId}-${_dateKey(DateTime.now())}.json';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  Future<void>.delayed(
    const Duration(minutes: 1),
    () => web.URL.revokeObjectURL(url),
  );
}
