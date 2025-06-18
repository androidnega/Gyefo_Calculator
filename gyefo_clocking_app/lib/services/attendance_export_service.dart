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
import 'package:intl/intl.dart';
import '../models/attendance_model.dart';
import '../models/user_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class ExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Export attendance data to CSV format
  static Future<String?> exportToCSV({
    required List<AttendanceModel> attendanceData,
    required DateTimeRange dateRange,
    String? workerFilter,
    String? flagFilter,
  }) async {
    try {
      // Prepare CSV headers
      List<List<dynamic>> csvData = [
        [
          'Employee Name',
          'Date',
          'Clock In',
          'Clock Out',
          'Duration (Hours)',
          'Location In',
          'Location Out',
          'Lateness (Minutes)',
          'Overtime (Minutes)',
          'Flag Status',
          'Justification Status',
          'Manager Note',
        ],
      ]; // Add data rows
      for (final attendance in attendanceData) {
        // Get worker details
        final workerData =
            await _firestore.collection('users').doc(attendance.workerId).get();

        final workerName =
            workerData.exists
                ? '${workerData.data()?['firstName'] ?? ''} ${workerData.data()?['lastName'] ?? ''}'
                    .trim()
                : 'Unknown Worker';

        // Calculate duration
        double durationHours = 0.0;
        if (attendance.clockOut != null) {
          final duration = attendance.clockOut!.difference(attendance.clockIn);
          durationHours = duration.inMinutes / 60.0;
        }

        // Format times
        final clockInStr = DateFormat('HH:mm').format(attendance.clockIn);
        final clockOutStr =
            attendance.clockOut != null
                ? DateFormat('HH:mm').format(attendance.clockOut!)
                : '-';

        // Format locations
        final locationIn =
            attendance.clockInLocation != null
                ? '${attendance.clockInLocation!.latitude.toStringAsFixed(4)}, ${attendance.clockInLocation!.longitude.toStringAsFixed(4)}'
                : '-';

        final locationOut =
            attendance.clockOutLocation != null
                ? '${attendance.clockOutLocation!.latitude.toStringAsFixed(4)}, ${attendance.clockOutLocation!.longitude.toStringAsFixed(4)}'
                : '-';

        // Format flags
        final flagStatus =
            attendance.flags.isNotEmpty
                ? attendance.flags
                    .map((f) => f.toString().split('.').last)
                    .join(', ')
                : 'None';

        // Get lateness and overtime minutes
        final latenessMinutes = attendance.latenessMinutes?.inMinutes ?? 0;
        final overtimeMinutes = attendance.overtimeMinutes?.inMinutes ?? 0;

        csvData.add([
          workerName,
          DateFormat('yyyy-MM-dd').format(attendance.clockIn),
          clockInStr,
          clockOutStr,
          durationHours.toStringAsFixed(2),
          locationIn,
          locationOut,
          latenessMinutes,
          overtimeMinutes,
          flagStatus,
          attendance.justification?.status.toString().split('.').last ?? 'None',
          attendance.justification?.rejectionReason ?? '',
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
    required List<AttendanceModel> attendanceData,
    required DateTimeRange dateRange,
    String? workerFilter,
    String? flagFilter,
  }) async {
    try {
      final pdf = pw.Document();

      // Get company info for header
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;

      final userData =
          await _firestore.collection('users').doc(currentUser.uid).get();

      final companyName =
          userData.data()?['companyName'] ?? 'Gyefo Clocking System';

      // Prepare data for PDF table
      List<List<String>> tableData = [];

      for (final attendance in attendanceData) {
        // Get worker details
        final workerData =
            await _firestore.collection('users').doc(attendance.workerId).get();

        final workerName =
            workerData.exists
                ? '${workerData.data()?['firstName'] ?? ''} ${workerData.data()?['lastName'] ?? ''}'
                    .trim()
                : 'Unknown'; // Calculate duration
        String durationStr = '-';
        if (attendance.clockOut != null) {
          final duration = attendance.clockOut!.difference(attendance.clockIn);
          final hours = duration.inHours;
          final minutes = duration.inMinutes % 60;
          durationStr = '${hours}h ${minutes}m';
        } // Format times
        final dateStr = DateFormat('MM/dd').format(attendance.clockIn);
        final clockInStr = DateFormat('HH:mm').format(attendance.clockIn);
        final clockOutStr =
            attendance.clockOut != null
                ? DateFormat('HH:mm').format(attendance.clockOut!)
                : '-';

        // Format flags (shortened for PDF)
        String flagStatus = 'None';
        if (attendance.flags.isNotEmpty) {
          flagStatus = attendance.flags.take(2).join(', ');
          if (attendance.flags.length > 2) {
            flagStatus += '...';
          }
        }

        tableData.add([
          workerName,
          dateStr,
          clockInStr,
          clockOutStr,
          durationStr,
          flagStatus,
        ]);
      }

      // Create PDF pages
      const int rowsPerPage = 30;
      for (int i = 0; i < tableData.length; i += rowsPerPage) {
        final pageData = tableData.skip(i).take(rowsPerPage).toList();

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
                          companyName,
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
                        if (workerFilter != null)
                          pw.Text(
                            'Worker: $workerFilter',
                            style: const pw.TextStyle(fontSize: 12),
                          ),
                        if (flagFilter != null)
                          pw.Text(
                            'Flag Filter: $flagFilter',
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
                          _buildTableCell('Flags', isHeader: true),
                        ],
                      ),
                      // Data rows
                      ...pageData.map(
                        (row) => pw.TableRow(
                          children:
                              row.map((cell) => _buildTableCell(cell)).toList(),
                        ),
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
                        'Page ${context.pageNumber} of ${context.pagesCount}',
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
      }

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

  /// Get attendance data for export
  static Future<List<AttendanceModel>> getAttendanceForExport({
    required DateTimeRange dateRange,
    String? workerId,
    String? flagFilter,
  }) async {
    try {
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

      if (workerId != null && workerId.isNotEmpty) {
        query = query.where('userId', isEqualTo: workerId);
      }

      final snapshot = await query.get();
      List<AttendanceModel> attendanceList = [];

      for (final doc in snapshot.docs) {
        try {
          final attendance = AttendanceModel.fromMap(
            doc.data() as Map<String, dynamic>,
          );

          // Apply flag filter if specified
          if (flagFilter != null &&
              flagFilter.isNotEmpty &&
              flagFilter != 'All') {
            if (flagFilter == 'None' && attendance.flags.isNotEmpty) {
              continue;
            }
            if (flagFilter != 'None' &&
                !attendance.flags.any(
                  (f) => f.toString().split('.').last == flagFilter,
                )) {
              continue;
            }
          }

          attendanceList.add(attendance);
        } catch (e) {
          AppLogger.error('Error parsing attendance document ${doc.id}: $e');
        }
      }

      // Sort by date
      attendanceList.sort((a, b) {
        final aTime = a.clockIn;
        final bTime = b.clockIn;
        return aTime.compareTo(bTime);
      });

      return attendanceList;
    } catch (e) {
      AppLogger.error('Error getting attendance for export: $e');
      return [];
    }
  }

  /// Get available workers for filter
  static Future<List<UserModel>> getAvailableWorkers() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return [];

      // Get current user's company
      final userData =
          await _firestore.collection('users').doc(currentUser.uid).get();

      final companyId = userData.data()?['companyId'];
      if (companyId == null) return [];

      final snapshot =
          await _firestore
              .collection('users')
              .where('companyId', isEqualTo: companyId)
              .where('role', isEqualTo: 'worker')
              .get();

      return snapshot.docs
          .map((doc) => UserModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      AppLogger.error('Error getting available workers: $e');
      return [];
    }
  }

  /// Get available flag types for filter
  static List<String> getAvailableFlagTypes() {
    return [
      'All',
      'None',
      'Late Arrival',
      'Early Departure',
      'Missing Clock Out',
      'Location Issue',
      'Overtime',
      'Long Break',
      'Unusual Pattern',
    ];
  }

  /// Generate summary statistics for export
  static Map<String, dynamic> generateSummaryStats(
    List<AttendanceModel> attendanceData,
  ) {
    if (attendanceData.isEmpty) {
      return {
        'totalRecords': 0,
        'totalHours': 0.0,
        'averageHours': 0.0,
        'totalLateness': 0,
        'totalOvertime': 0,
        'flaggedRecords': 0,
        'uniqueWorkers': 0,
      };
    }

    double totalHours = 0.0;
    int totalLateness = 0;
    int totalOvertime = 0;
    int flaggedRecords = 0;
    Set<String> uniqueWorkers = {};
    for (final attendance in attendanceData) {
      // Calculate hours
      if (attendance.clockOut != null) {
        final duration = attendance.clockOut!.difference(attendance.clockIn);
        totalHours += duration.inMinutes / 60.0;
      }

      // Sum lateness and overtime
      totalLateness += attendance.latenessMinutes?.inMinutes ?? 0;
      totalOvertime += attendance.overtimeMinutes?.inMinutes ?? 0;

      // Count flagged records
      if (attendance.flags.isNotEmpty) {
        flaggedRecords++;
      }

      // Track unique workers
      uniqueWorkers.add(attendance.workerId);
    }

    return {
      'totalRecords': attendanceData.length,
      'totalHours': totalHours,
      'averageHours': totalHours / attendanceData.length,
      'totalLateness': totalLateness,
      'totalOvertime': totalOvertime,
      'flaggedRecords': flaggedRecords,
      'uniqueWorkers': uniqueWorkers.length,
    };
  }
}
