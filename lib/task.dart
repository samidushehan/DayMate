class Task {
  const Task({
    required this.id,
    required this.title,
    required this.dueAt,
    required this.hasTime,
    required this.isImportant,
    required this.isCompleted,
  }) : assert(!isImportant || hasTime);

  final int id;
  final String title;
  final DateTime dueAt;
  final bool hasTime;
  final bool isImportant;
  final bool isCompleted;

  Task copyWith({
    int? id,
    String? title,
    DateTime? dueAt,
    bool? hasTime,
    bool? isImportant,
    bool? isCompleted,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    dueAt: dueAt ?? this.dueAt,
    hasTime: hasTime ?? this.hasTime,
    isImportant: isImportant ?? this.isImportant,
    isCompleted: isCompleted ?? this.isCompleted,
  );

  Map<String, Object?> toMap() => {
    'id': id == 0 ? null : id,
    'title': title,
    'due_at': dueAt.toIso8601String(),
    'has_time': hasTime ? 1 : 0,
    'is_important': isImportant ? 1 : 0,
    'is_completed': isCompleted ? 1 : 0,
  };

  factory Task.fromMap(Map<String, Object?> map) => Task(
    id: map['id']! as int,
    title: map['title']! as String,
    dueAt: DateTime.parse(map['due_at']! as String),
    hasTime: map['has_time'] == 1,
    isImportant: map['is_important'] == 1,
    isCompleted: map['is_completed'] == 1,
  );
}
