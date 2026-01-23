
// lib/csv_exporter_io_impl.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Saves CSV to app documents folder and opens native Share sheet.
Future<void> saveCsvReport({
  required String fileNamePrefix,
  required DateTime date,
  required String csvContent,
  required String shareSubject,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final dateStr = DateFormat('yyyyMMdd').format(date);
  final file = File('${directory.path}/${fileNamePrefix}_$dateStr.csv');

  await file.writeAsString(csvContent);
  await Share.shareXFiles([XFile(file.path)], subject: shareSubject);
}
