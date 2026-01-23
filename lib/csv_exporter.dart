
// lib/csv_exporter.dart
//
// One import for your UI code:
//   import 'csv_exporter.dart';
//   await saveCsvReport(...);
//
// Under the hood, this delegates to the right implementation at compile time.

export 'csv_exporter_io_impl.dart'
  if (dart.library.html) 'csv_exporter_web_impl.dart'
  if (dart.library.io) 'csv_exporter_io_impl.dart'
  show saveCsvReport;
