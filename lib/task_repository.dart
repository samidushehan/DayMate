import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

import 'task.dart';

abstract interface class TaskRepository {
  Future<void> initialize();

  Future<List<Task>> getTasks();

  Future<int> addTask(Task task);

  Future<void> updateTask(Task task);

  Future<void> deleteTask(int id);
}

class SqliteTaskRepository implements TaskRepository {
  Database? _database;

  @override
  Future<void> initialize() async {
    if (_database != null) return;
    final databasePath = await getDatabasesPath();
    _database = await openDatabase(
      path.join(databasePath, 'daymate.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            due_at TEXT NOT NULL,
            has_time INTEGER NOT NULL,
            is_important INTEGER NOT NULL,
            is_completed INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Database get _db {
    final database = _database;
    if (database == null) {
      throw StateError('Task database has not been initialized.');
    }
    return database;
  }

  @override
  Future<List<Task>> getTasks() async {
    final rows = await _db.query('tasks', orderBy: 'due_at ASC, id ASC');
    return rows.map(Task.fromMap).toList();
  }

  @override
  Future<int> addTask(Task task) async {
    return _db.insert(
      'tasks',
      task.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
  }

  @override
  Future<void> updateTask(Task task) async {
    final affected = await _db.update(
      'tasks',
      task.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [task.id],
    );
    if (affected != 1) {
      throw StateError('Task ${task.id} no longer exists.');
    }
  }

  @override
  Future<void> deleteTask(int id) async {
    final affected = await _db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (affected != 1) {
      throw StateError('Task $id no longer exists.');
    }
  }
}
