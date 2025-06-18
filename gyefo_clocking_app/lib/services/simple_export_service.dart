import 'dart:io';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';
import 'package:intl/intl.dart';

class SimpleExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Export attendance data to CSV format
  static Future<String?> exportToCSV({
    required DateTimeRange dateRange,
    String? workerFilter,
  }) async {
    try {
      // Get attendance data
      final attendanceData = await _getAttendanceData(dateRange, workerFilter);

      // Prepare CSV headers
      List<List<dynamic>> csvData = [
        [
          'Employee Name',
          'Date',
          'Clock In',
          'Clock Out',
          'Duration (Hours)',
          'Status',
        ],
      ];

      // Add data rows
      for (final doc in attendanceData) {
        final data = doc.data() as Map<String, dynamic>;

        // Get worker name
        final workerId = data['userId'] ?? data['workerId'] ?? '';
        String workerName = 'Unknown';
        if (workerId.isNotEmpty) {
          final workerDoc =
              await _firestore.collection('users').doc(workerId).get();
          if (workerDoc.exists) {
            final workerData = workerDoc.data()!;
            workerName =
                '${workerData['firstName'] ?? ''} ${workerData['lastName'] ?? ''}'
                    .trim();
          }
        }

        // Parse timestamps
        final clockIn = (data['clockIn'] as Timestamp?)?.toDate();
        final clockOut = (data['clockOut'] as Timestamp?)?.toDate();

        if (clockIn == null) continue;

        // Calculate duration
        double durationHours = 0.0;
        if (clockOut != null) {
          final duration = clockOut.difference(clockIn);
          durationHours = duration.inMinutes / 60.0;
        }

        // Format times
        final clockInStr = DateFormat('HH:mm').format(clockIn);
        final clockOutStr =
            clockOut != null ? DateFormat('HH:mm').format(clockOut) : '-';

        csvData.add([
          workerName,
          DateFormat('yyyy-MM-dd').format(clockIn),
          clockInStr,
          clockOutStr,
          durationHours.toStringAsFixed(2),
          clockOut != null ? 'Complete' : 'Incomplete',
        ]);
      }

      // Convert to CSV string
      String csvString = const ListToCsvConverter().convert(csvData);

      // Save to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'attendance_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';
      final file = File('${directory.path}/$fileName');
      await file.writeAsString(csvString);

      return file.path;
    } catch (e) {
      AppLogger.error('Error exporting to CSV: $e');
      return null;
    }
  }

  /// Export attendance data to PDF format
  static Future<String?> exportToPDF({
    required DateTimeRange dateRange,
    String? workerFilter,
  }) async {
    try {
      final pdf = pw.Document();

      // Get attendance data
      final attendanceData = await _getAttendanceData(dateRange, workerFilter);

      // Prepare data for PDF table
      List<List<String>> tableData = [];

      for (final doc in attendanceData) {
        final data = doc.data() as Map<String, dynamic>;

        // Get worker name
        final workerId = data['userId'] ?? data['workerId'] ?? '';
        String workerName = 'Unknown';
        if (workerId.isNotEmpty) {
          final workerDoc =
              await _firestore.collection('users').doc(workerId).get();
          if (workerDoc.exists) {
            final workerData = workerDoc.data()!;
            workerName =
                '${workerData['firstName'] ?? ''} ${workerData['lastName'] ?? ''}'
                    .trim();
          }
        }

        // Parse timestamps
        final clockIn = (data['clockIn'] as Timestamp?)?.toDate();
        final clockOut = (data['clockOut'] as Timestamp?)?.toDate();

        if (clockIn == null) continue;

        // Calculate duration
        String durationStr = '-';
        if (clockOut != null) {
          final duration = clockOut.difference(clockIn);
          final hours = duration.inHours;
          final minutes = duration.inMinutes % 60;
          durationStr = '${hours}h ${minutes}m';
        }

        // Format times
        final dateStr = DateFormat('MM/dd').format(clockIn);
        final clockInStr = DateFormat('HH:mm').format(clockIn);
        final clockOutStr =
            clockOut != null ? DateFormat('HH:mm').format(clockOut) : '-';

        tableData.add([
          workerName,
          dateStr,
          clockInStr,
          clockOutStr,
          durationStr,
        ]);
      }

      // Create PDF
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue100,
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Gyefo Clocking System',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Attendance Report',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Period: ${DateFormat('MMM d, yyyy').format(dateRange.start)} - ${DateFormat('MMM d, yyyy').format(dateRange.end)}',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 20),

                // Table
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    // Header row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.grey200,
                      ),
                      children: [
                        _buildTableCell('Employee', isHeader: true),
                        _buildTableCell('Date', isHeader: true),
                        _buildTableCell('In', isHeader: true),
                        _buildTableCell('Out', isHeader: true),
                        _buildTableCell('Duration', isHeader: true),
                      ],
                    ),
                    // Data rows
                    for (final row in tableData)
                      pw.TableRow(
                        children: [
                          for (final cell in row) _buildTableCell(cell),
                        ],
                      ),
                  ],
                ),

                pw.Spacer(),

                // Footer
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Generated on ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      'Page ${context.pageNumber}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      // Save PDF to file
      final directory = await getApplicationDocumentsDirectory();
      final fileName =
          'attendance_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      return file.path;
    } catch (e) {
      AppLogger.error('Error exporting to PDF: $e');
      return null;
    }
  }

  /// Build table cell for PDF
  static pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: isHeader ? pw.TextAlign.center : pw.TextAlign.left,
      ),
    );
  }

  /// Get attendance data from Firestore
  static Future<List<QueryDocumentSnapshot>> _getAttendanceData(
    DateTimeRange dateRange,
    String? workerFilter,
  ) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return [];

    // Get current user's company
    final userData =
        await _firestore.collection('users').doc(currentUser.uid).get();

    final companyId = userData.data()?['companyId'];
    if (companyId == null) return [];

    Query query = _firestore
        .collection('attendance')
        .where('companyId', isEqualTo: companyId)
        .where(
          'clockIn',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateRange.start),
        )
        .where(
          'clockIn',
          isLessThanOrEqualTo: Timestamp.fromDate(
            dateRange.end.add(const Duration(days: 1)),
          ),
        );

    if (workerFilter != null && workerFilter.isNotEmpty) {
      query = query.where('userId', isEqualTo: workerFilter);
    }

    final snapshot = await query.get();
    return snapshot.docs;
  }

  /// Share exported file
  static Future<void> shareFile(String filePath, String title) async {
    try {
      await Share.shareXFiles([XFile(filePath)], text: title);
    } catch (e) {
      AppLogger.error('Error sharing file: $e');
    }
  }

  /// Print PDF file
  static Future<void> printPDF(String filePath) async {
    try {
      final file = File(filePath);
      final bytes = await file.readAsBytes();

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
    } catch (e) {
      AppLogger.error('Error printing PDF: $e');
    }
  }
}
