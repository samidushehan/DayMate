import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daymate/main.dart';
import 'package:daymate/task.dart';
import 'package:daymate/task_notifications.dart';
import 'package:daymate/task_repository.dart';

void main() {
  testWidgets('creates, completes, and deletes a task', (tester) async {
    final repository = _MemoryTaskRepository();
    await tester.pumpWidget(
      MyApp(repository: repository, reminders: _MemoryReminderService()),
    );
    await tester.pumpAndSettle();

    expect(find.text('DayMate'), findsOneWidget);
    expect(find.text('Next 7 days'), findsOneWidget);

    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Review project plan');
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();

    expect(find.text('Review project plan'), findsOneWidget);
    expect(repository.tasks, hasLength(1));

    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);

    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.tasks, isEmpty);
    expect(find.text('Review project plan'), findsNothing);
  });

  testWidgets('important tasks require a time', (tester) async {
    await tester.pumpWidget(
      MyApp(
        repository: _MemoryTaskRepository(),
        reminders: _MemoryReminderService(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Add task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Call the dentist');
    await tester.tap(find.text('Important task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save task'));
    await tester.pumpAndSettle();

    expect(find.text('Choose a time for important tasks.'), findsOneWidget);
    expect(find.text('Add a task'), findsOneWidget);
  });
}

class _MemoryTaskRepository implements TaskRepository {
  final List<Task> tasks = [];
  int _nextId = 1;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Task>> getTasks() async => List.of(tasks);

  @override
  Future<int> addTask(Task task) async {
    final id = _nextId++;
    tasks.add(task.copyWith(id: id));
    return id;
  }

  @override
  Future<void> updateTask(Task task) async {
    final index = tasks.indexWhere((existing) => existing.id == task.id);
    if (index == -1) throw StateError('Task ${task.id} not found.');
    tasks[index] = task;
  }

  @override
  Future<void> deleteTask(int id) async {
    tasks.removeWhere((task) => task.id == id);
  }
}

class _MemoryReminderService implements TaskReminderService {
  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> schedule(Task task) async => true;

  @override
  Future<void> cancel(int id) async {}
}
