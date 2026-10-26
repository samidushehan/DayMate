import 'package:flutter/material.dart';

import 'task.dart';
import 'task_notifications.dart';
import 'task_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.repository, this.reminders});

  final TaskRepository? repository;
  final TaskReminderService? reminders;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF2F776B);
    return MaterialApp(
      title: 'DayMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          surface: const Color(0xFFF7F8F4),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F8F4),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F8F4),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: TaskHomePage(
        repository: repository ?? SqliteTaskRepository(),
        reminders: reminders ?? LocalTaskReminderService(),
      ),
    );
  }
}

class TaskHomePage extends StatefulWidget {
  const TaskHomePage({
    super.key,
    required this.repository,
    required this.reminders,
  });

  final TaskRepository repository;
  final TaskReminderService reminders;

  @override
  State<TaskHomePage> createState() => _TaskHomePageState();
}

class _TaskHomePageState extends State<TaskHomePage> {
  List<Task> _tasks = [];
  Object? _loadError;
  bool _isLoading = true;
  bool _reminderPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      await widget.repository.initialize();
      _reminderPermissionGranted = await widget.reminders.initialize();
      final tasks = await widget.repository.getTasks();
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _addTask() async {
    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _TaskFormSheet(),
    );
    if (draft == null || !mounted) return;

    try {
      final id = await widget.repository.addTask(draft.toTask());
      final task = draft.toTask().copyWith(id: id);
      await _reloadTasks();
      if (task.hasTime) {
        final scheduled = await widget.reminders.schedule(task);
        if (!mounted) return;
        _showMessage(
          scheduled
              ? 'Task saved with a reminder.'
              : 'Task saved. Enable notifications to receive reminders.',
        );
      } else {
        _showMessage('Task added.');
      }
    } catch (error) {
      _showMessage('Could not add task: $error');
    }
  }

  Future<void> _toggleTask(Task task, bool isCompleted) async {
    final updated = task.copyWith(isCompleted: isCompleted);
    try {
      await widget.repository.updateTask(updated);
      await _reloadTasks();
      if (isCompleted) {
        await widget.reminders.cancel(task.id);
      } else if (updated.hasTime) {
        final scheduled = await widget.reminders.schedule(updated);
        if (!scheduled && mounted) {
          _showMessage(
            'Task updated. Enable notifications to receive reminders.',
          );
          return;
        }
      }
    } catch (error) {
      _showMessage('Could not update task: $error');
    }
  }

  Future<void> _deleteTask(Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.repository.deleteTask(task.id);
      await widget.reminders.cancel(task.id);
      await _reloadTasks();
      if (mounted) _showMessage('Task deleted.');
    } catch (error) {
      _showMessage('Could not delete task: $error');
    }
  }

  Future<void> _reloadTasks() async {
    final tasks = await widget.repository.getTasks();
    if (!mounted) return;
    setState(() => _tasks = tasks);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final upcoming = List<DateTime>.generate(
      7,
      (index) => today.add(Duration(days: index)),
    );
    final importantTasks = _tasks.where((task) => task.isImportant).toList()
      ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'DayMate',
          style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
        ),
        actions: [
          IconButton(
            tooltip: 'Add task',
            onPressed: _isLoading ? null : _addTask,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _addTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add task'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? _LoadErrorView(error: _loadError!, onRetry: _loadTasks)
          : RefreshIndicator(
              onRefresh: _reloadTasks,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 104),
                children: [
                  _TodayBanner(
                    date: today,
                    remaining: _tasks.where((task) => !task.isCompleted).length,
                  ),
                  if (!_reminderPermissionGranted)
                    const _ReminderPermissionNotice(),
                  const SizedBox(height: 28),
                  _SectionHeading(
                    title: 'Important tasks',
                    subtitle: 'The things you don’t want to miss',
                    icon: Icons.star_rounded,
                    color: const Color(0xFFD99A3D),
                  ),
                  const SizedBox(height: 12),
                  if (importantTasks.isEmpty)
                    const _EmptyImportantCard()
                  else
                    ...importantTasks.map(
                      (task) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _TaskTile(
                          task: task,
                          showDate: true,
                          onChanged: (value) =>
                              _toggleTask(task, value ?? false),
                          onDelete: () => _deleteTask(task),
                        ),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const _SectionHeading(
                    title: 'Next 7 days',
                    subtitle: 'A little plan goes a long way',
                    icon: Icons.calendar_month_rounded,
                    color: Color(0xFF2F776B),
                  ),
                  const SizedBox(height: 12),
                  for (final date in upcoming)
                    _DayGroup(
                      date: date,
                      tasks:
                          _tasks
                              .where((task) => _sameDate(task.dueAt, date))
                              .toList()
                            ..sort((a, b) => a.dueAt.compareTo(b.dueAt)),
                      onChanged: _toggleTask,
                      onDelete: _deleteTask,
                    ),
                  if (_tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: OutlinedButton.icon(
                        onPressed: _addTask,
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Plan your first task'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _TodayBanner extends StatelessWidget {
  const _TodayBanner({required this.date, required this.remaining});

  final DateTime date;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F1EB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullDate(date),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: const Color(0xFF52675C),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  remaining == 0
                      ? 'A fresh start.'
                      : '$remaining ${remaining == 1 ? 'task' : 'tasks'} to go.',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF244D42),
                  ),
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 27,
            backgroundColor: Color(0xFFCEE2D7),
            child: Icon(Icons.wb_sunny_outlined, color: Color(0xFF2F776B)),
          ),
        ],
      ),
    );
  }
}

class _ReminderPermissionNotice extends StatelessWidget {
  const _ReminderPermissionNotice();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2D9),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Row(
      children: [
        Icon(Icons.notifications_off_outlined, color: Color(0xFF9B6820)),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Notifications are off. Tasks will still be saved, but reminders need notification permission.',
          ),
        ),
      ],
    ),
  );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: color),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    ],
  );
}

class _EmptyImportantCard extends StatelessWidget {
  const _EmptyImportantCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: const Row(
      children: [
        Icon(Icons.star_border_rounded, color: Color(0xFFD99A3D)),
        SizedBox(width: 12),
        Expanded(child: Text('Mark a task important to keep it close.')),
      ],
    ),
  );
}

class _DayGroup extends StatelessWidget {
  const _DayGroup({
    required this.date,
    required this.tasks,
    required this.onChanged,
    required this.onDelete,
  });

  final DateTime date;
  final List<Task> tasks;
  final void Function(Task, bool) onChanged;
  final void Function(Task) onDelete;

  @override
  Widget build(BuildContext context) {
    final today = _sameDate(date, DateTime.now());
    final tomorrow = _sameDate(
      date,
      DateTime.now().add(const Duration(days: 1)),
    );
    final label = today
        ? 'Today'
        : tomorrow
        ? 'Tomorrow'
        : _weekday(date);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.day} ${_month(date.month)}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.black54),
                ),
                const Spacer(),
                Text(
                  '${tasks.where((task) => !task.isCompleted).length}',
                  style: Theme.of(context).textTheme.labelMedium
                      ?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          if (tasks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Nothing planned',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            ...tasks.map(
              (task) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TaskTile(
                  task: task,
                  onChanged: (value) => onChanged(task, value ?? false),
                  onDelete: () => onDelete(task),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.onChanged,
    required this.onDelete,
    this.showDate = false,
  });

  final Task task;
  final bool showDate;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final subline = [
      if (showDate)
        '${_weekday(task.dueAt)}, ${task.dueAt.day} ${_month(task.dueAt.month)}',
      task.hasTime ? _time(task.dueAt) : 'All day',
    ].join(' · ');
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 6, right: 4),
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: onChanged,
          shape: const CircleBorder(),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            decoration: task.isCompleted ? TextDecoration.lineThrough : null,
            color: task.isCompleted ? Colors.black45 : null,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(subline),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.isImportant)
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFD99A3D),
                size: 19,
              ),
            IconButton(
              tooltip: 'Delete task',
              visualDensity: VisualDensity.compact,
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 21),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFormSheet extends StatefulWidget {
  const _TaskFormSheet();

  @override
  State<_TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<_TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _date = _dateOnly(DateTime.now());
  TimeOfDay? _time;
  bool _isImportant = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: _dateOnly(DateTime.now()),
      lastDate: _dateOnly(DateTime.now()).add(const Duration(days: 3650)),
    );
    if (selected != null) setState(() => _date = _dateOnly(selected));
  }

  Future<void> _selectTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
    );
    if (selected != null) setState(() => _time = selected);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_isImportant && _time == null) {
      setState(() {});
      return;
    }
    final time = _time;
    final dueAt = time == null
        ? _date
        : DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);
    Navigator.of(context).pop(
      TaskDraft(
        title: _titleController.text.trim(),
        dueAt: dueAt,
        hasTime: time != null,
        isImportant: _isImportant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add a task',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _titleController,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Task title',
                  hintText: 'What do you need to do?',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a task title.'
                    : null,
              ),
              const SizedBox(height: 12),
              _FormOption(
                icon: Icons.calendar_today_rounded,
                title: 'Date',
                value:
                    '${_weekday(_date)}, ${_date.day} ${_month(_date.month)}',
                onTap: _selectDate,
              ),
              _FormOption(
                icon: Icons.schedule_rounded,
                title: 'Time',
                value: _time == null ? 'Optional' : _time!.format(context),
                onTap: _selectTime,
                trailing: _time == null
                    ? const Icon(Icons.add_rounded)
                    : IconButton(
                        tooltip: 'Clear time',
                        onPressed: () => setState(() => _time = null),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(
                  Icons.star_outline_rounded,
                  color: Color(0xFFD99A3D),
                ),
                title: const Text('Important task'),
                subtitle: Text(
                  _time == null
                      ? 'Important tasks need a reminder time.'
                      : 'Keep this in your Important Tasks list.',
                ),
                value: _isImportant,
                onChanged: (value) => setState(() => _isImportant = value),
              ),
              if (_isImportant && _time == null)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Choose a time for important tasks.',
                    style: TextStyle(color: Color(0xFFB3261E)),
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save task'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormOption extends StatelessWidget {
  const _FormOption({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(value),
    trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}

class _LoadErrorView extends StatelessWidget {
  const _LoadErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: 12),
          const Text(
            'DayMate could not load your tasks.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('$error', textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class TaskDraft {
  const TaskDraft({
    required this.title,
    required this.dueAt,
    required this.hasTime,
    required this.isImportant,
  });

  final String title;
  final DateTime dueAt;
  final bool hasTime;
  final bool isImportant;

  Task toTask() => Task(
    id: 0,
    title: title,
    dueAt: dueAt,
    hasTime: hasTime,
    isImportant: isImportant,
    isCompleted: false,
  );
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _sameDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _fullDate(DateTime date) =>
    '${_weekday(date)}, ${_month(date.month)} ${date.day}';

String _weekday(DateTime date) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][date.weekday - 1];

String _month(int month) => const [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
][month - 1];

String _time(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}
