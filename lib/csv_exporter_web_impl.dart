
// lib/csv_exporter_web_impl.dart
// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'package:intl/intl.dart';

/// Triggers a browser download for the CSV.
Future<void> saveCsvReport({
  required String fileNamePrefix,
  required DateTime date,
  required String csvContent,
  required String shareSubject, // not used on web
}) async {
  final dateStr = DateFormat('yyyyMMdd').format(date);
  final filename = '${fileNamePrefix}_$dateStr.csv';

  final bytes = utf8.encode(csvContent);
  final blob = html.Blob([bytes], 'text/csv;charset=utf-8;');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)..download = filename;
  html.document.body?.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}
