# DayMate

DayMate is a simple task planner for Flutter.

## Features

- Today's date and a seven-day task view grouped by day.
- Add tasks with a title and date, plus an optional time.
- Mark timed tasks as important; important tasks require a time and appear in
  their own section.
- Complete and delete tasks.
- Tasks are stored locally in the app's SQLite database.
- Timed tasks use local notifications on Android and iOS. Notification
  permission is requested by the app; reminders are not delivered when
  permission is denied.

The current local database and reminder integrations target Android and iOS.
Run the app with `flutter run` and the checks with `flutter analyze` and
`flutter test`.
