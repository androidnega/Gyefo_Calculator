import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:gyefo_clocking_app/models/attendance_model.dart';
import 'package:gyefo_clocking_app/models/user_model.dart';
import 'package:gyefo_clocking_app/utils/logger.dart';

class ExportService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Helper methods to check platform safely
  static bool get _isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Fetches all attendance records for a specific worker
  static Future<List<AttendanceModel>> getWorkerAttendanceRecords(
    String workerId,
  ) async {
    try {
      final snapshot =
          await _firestore
              .collection('attendance')
              .doc(workerId)
              .collection('records')
              .orderBy('clockIn', descending: true)
              .get();

      return snapshot.docs
          .map((doc) => AttendanceModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      AppLogger.error('Error fetching attendance records: $e');
      return [];
    }
  }

  /// Fetches worker information
  static Future<UserModel?> getWorkerInfo(String workerId) async {
    try {
      final doc = await _firestore.collection('users').doc(workerId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, workerId);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching worker info: $e');
      return null;
    }
  }

  /// Exports worker attendance records to CSV format
  static Future<File?> exportWorkerAttendanceToCSV(
    String workerId, {
    List<AttendanceModel>? records,
    UserModel? workerInfo,
  }) async {
    try {      AppLogger.info('Starting CSV export for worker: $workerId');

      // Request storage permission for Android (not on web)
      if (_isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          AppLogger.warning('Storage permission denied');
          return null;
        }
      }

      // Fetch records if not provided
      final attendanceRecords =
          records ?? await getWorkerAttendanceRecords(workerId);
      final worker = workerInfo ?? await getWorkerInfo(workerId);

      if (attendanceRecords.isEmpty) {
        AppLogger.warning('No attendance records found for worker: $workerId');
        return null;
      }

      // Prepare CSV data with headers
      List<List<dynamic>> rows = [
        [
          'Worker Name',
          'Worker ID',
          'Date',
          'Clock In Time',
          'Clock Out Time',
          'Hours Worked',
          'Status',
        ],
      ];

      // Add data rows
      for (final record in attendanceRecords) {
        final clockInFormatted = DateFormat('HH:mm:ss').format(record.clockIn);
        final clockOutFormatted =
            record.clockOut != null
                ? DateFormat('HH:mm:ss').format(record.clockOut!)
                : '---';

        String hoursWorked = 'In Progress';
        String status = 'Incomplete';

        if (record.clockOut != null) {
          final duration = record.clockOut!.difference(record.clockIn);
          final hours = duration.inHours;
          final minutes = duration.inMinutes % 60;
          hoursWorked = '${hours}h ${minutes}m';
          status = 'Complete';
        }

        rows.add([
          worker?.name ?? 'Unknown Worker',
          workerId,
          record.date,
          clockInFormatted,
          clockOutFormatted,
          hoursWorked,
          status,
        ]);
      }

      // Convert to CSV string
      final csvData = const ListToCsvConverter().convert(
        rows,
      );      // Get the appropriate directory for saving files
      Directory? directory;
      if (kIsWeb) {
        // For web, we'll use direct download instead of file system
        directory = null;
      } else if (_isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (_isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (!kIsWeb) {
        directory =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }

      // Create filename with timestamp
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final workerName = worker?.name.replaceAll(' ', '_') ?? 'worker';
      final filename = '${workerName}_attendance_$timestamp.csv';
      if (kIsWeb) {
        // For web, trigger download directly
        final bytes = Uint8List.fromList(csvData.codeUnits);
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')],
          text:
              'Attendance report for ${worker?.name ?? 'Worker'} from Gyefo Clocking App',
          subject: 'Attendance Report - ${worker?.name ?? 'Worker'} (CSV)',
        );

        AppLogger.success('CSV shared successfully on web');
        return null; // Web doesn't return a file
      } else {
        // Save to file for mobile/desktop
        final file = File('${directory!.path}/$filename');
        await file.writeAsString(csvData);

        AppLogger.success('CSV exported successfully: ${file.path}');
        return file;
      }
    } catch (e) {
      AppLogger.error('Error exporting CSV: $e');
      return null;
    }
  }

  /// Shares the CSV file using the device's share functionality
  static Future<void> shareCSVFile(File file, String workerName) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance report for $workerName from Gyefo Clocking App',
        subject: 'Attendance Report - $workerName',
      );
      AppLogger.success('CSV file shared successfully');
    } catch (e) {
      AppLogger.error('Error sharing CSV file: $e');
    }
  }

  /// Exports attendance for all workers (Manager only)
  static Future<File?> exportAllWorkersAttendance() async {
    try {
      AppLogger.info('Starting export for all workers');

      // Get all workers
      final workersSnapshot =
          await _firestore
              .collection('users')
              .where('role', isEqualTo: 'worker')
              .get();

      if (workersSnapshot.docs.isEmpty) {
        AppLogger.warning('No workers found');
        return null;
      }

      // Prepare CSV data
      List<List<dynamic>> rows = [
        [
          'Worker Name',
          'Worker Email',
          'Worker ID',
          'Date',
          'Clock In Time',
          'Clock Out Time',
          'Hours Worked',
          'Status',
        ],
      ];

      // Fetch attendance for each worker
      for (final workerDoc in workersSnapshot.docs) {
        final worker = UserModel.fromMap(workerDoc.data(), workerDoc.id);
        final records = await getWorkerAttendanceRecords(worker.uid);

        for (final record in records) {
          final clockInFormatted = DateFormat(
            'HH:mm:ss',
          ).format(record.clockIn);
          final clockOutFormatted =
              record.clockOut != null
                  ? DateFormat('HH:mm:ss').format(record.clockOut!)
                  : '---';

          String hoursWorked = 'In Progress';
          String status = 'Incomplete';

          if (record.clockOut != null) {
            final duration = record.clockOut!.difference(record.clockIn);
            final hours = duration.inHours;
            final minutes = duration.inMinutes % 60;
            hoursWorked = '${hours}h ${minutes}m';
            status = 'Complete';
          }

          rows.add([
            worker.name,
            worker.email ?? 'No email',
            worker.uid,
            record.date,
            clockInFormatted,
            clockOutFormatted,
            hoursWorked,
            status,
          ]);
        }
      }

      if (rows.length <= 1) {
        AppLogger.warning('No attendance records found for any worker');
        return null;
      }

      // Convert to CSV
      final csvData = const ListToCsvConverter().convert(rows);      // Save file
      Directory? directory;
      if (_isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (_isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (!kIsWeb) {
        directory =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }

      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'all_workers_attendance_$timestamp.csv';

      if (kIsWeb) {
        // For web, trigger download directly
        final bytes = Uint8List.fromList(csvData.codeUnits);
        await Share.shareXFiles(
          [XFile.fromData(bytes, name: filename, mimeType: 'text/csv')],
          text: 'All workers attendance report from Gyefo Clocking App',
          subject: 'All Workers Attendance Report (CSV)',
        );

        AppLogger.success('All workers CSV shared successfully on web');
        return null; // Web doesn't return a file
      } else {
        // Save to file for mobile/desktop
        final file = File('${directory!.path}/$filename');
        await file.writeAsString(csvData);

        AppLogger.success('All workers CSV exported: ${file.path}');
        return file;
      }
    } catch (e) {
      AppLogger.error('Error exporting all workers CSV: $e');
      return null;
    }
  }

  /// Exports worker attendance records to PDF format
  static Future<File?> exportWorkerAttendanceToPDF(
    String workerId, {
    List<AttendanceModel>? records,
    UserModel? workerInfo,
  }) async {
    try {
      AppLogger.info('Starting PDF export for worker: $workerId');      // Request storage permission for Android (not on web)
      if (_isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          AppLogger.warning('Storage permission denied');
          return null;
        }
      }

      // Fetch records if not provided
      final attendanceRecords =
          records ?? await getWorkerAttendanceRecords(workerId);
      final worker = workerInfo ?? await getWorkerInfo(workerId);

      if (attendanceRecords.isEmpty) {
        AppLogger.warning('No attendance records found for worker: $workerId');
        return null;
      }

      // Create PDF document
      final pdf = pw.Document();

      // Calculate total hours worked
      double totalHours = 0;
      int completeDays = 0;
      for (final record in attendanceRecords) {
        if (record.clockOut != null) {
          final duration = record.clockOut!.difference(record.clockIn);
          totalHours += duration.inMinutes / 60.0;
          completeDays++;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build:
              (context) => [
                // Header
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Gyefo Attendance Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        DateFormat('MMM dd, yyyy').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Worker Information
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Worker Information',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Name: ${worker?.name ?? 'Unknown Worker'}'),
                      pw.Text('Worker ID: $workerId'),
                      if (worker?.email != null)
                        pw.Text('Email: ${worker!.email}'),
                      pw.SizedBox(height: 8),
                      pw.Text('Total Records: ${attendanceRecords.length}'),
                      pw.Text('Complete Days: $completeDays'),
                      pw.Text(
                        'Total Hours: ${totalHours.toStringAsFixed(2)} hours',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Attendance Records Table
                pw.Text(
                  'Attendance Records',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue600,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.all(8),
                  headers: [
                    'Date',
                    'Clock In',
                    'Clock Out',
                    'Hours Worked',
                    'Status',
                  ],
                  data:
                      attendanceRecords.map((record) {
                        final clockInFormatted = DateFormat(
                          'HH:mm:ss',
                        ).format(record.clockIn);
                        final clockOutFormatted =
                            record.clockOut != null
                                ? DateFormat(
                                  'HH:mm:ss',
                                ).format(record.clockOut!)
                                : '---';

                        String hoursWorked = 'In Progress';
                        String status = 'Incomplete';

                        if (record.clockOut != null) {
                          final duration = record.clockOut!.difference(
                            record.clockIn,
                          );
                          final hours = duration.inHours;
                          final minutes = duration.inMinutes % 60;
                          hoursWorked = '${hours}h ${minutes}m';
                          status = 'Complete';
                        }

                        return [
                          record.date,
                          clockInFormatted,
                          clockOutFormatted,
                          hoursWorked,
                          status,
                        ];
                      }).toList(),
                ),

                pw.SizedBox(height: 20),

                // Footer
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated by Gyefo Clocking App on ${DateFormat('MMMM dd, yyyy at HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
        ),
      ); // Get the appropriate directory for saving files
      Directory? directory;
      if (kIsWeb) {
        // For web, we'll use a fallback directory or direct sharing
        // Web doesn't support file system access like mobile        directory = null;
      } else if (_isAndroid) {
        directory = await getExternalStorageDirectory();
      } else if (_isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else if (!kIsWeb) {
        directory =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
      }

      if (kIsWeb) {
        // For web, directly share the PDF instead of saving to file
        final pdfBytes = await pdf.save();
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final workerName = worker?.name.replaceAll(' ', '_') ?? 'worker';
        final filename = '${workerName}_attendance_$timestamp.pdf';

        await Printing.sharePdf(bytes: pdfBytes, filename: filename);

        AppLogger.success('PDF shared successfully on web');
        return null; // Web doesn't return a file
      } else {
        // Create filename with timestamp
        final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final workerName = worker?.name.replaceAll(' ', '_') ?? 'worker';
        final filename = '${workerName}_attendance_$timestamp.pdf';

        // Save to file
        final file = File('${directory!.path}/$filename');
        await file.writeAsBytes(await pdf.save());

        AppLogger.success('PDF exported successfully: ${file.path}');
        return file;
      }
    } catch (e) {
      AppLogger.error('Error exporting PDF: $e');
      return null;
    }
  }

  /// Shares the PDF file using the device's share functionality
  static Future<void> sharePDFFile(File file, String workerName) async {
    try {
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Attendance report for $workerName from Gyefo Clocking App',
        subject: 'Attendance Report - $workerName (PDF)',
      );
      AppLogger.success('PDF file shared successfully');
    } catch (e) {
      AppLogger.error('Error sharing PDF file: $e');
    }
  }

  /// Preview PDF using the printing package
  static Future<void> previewWorkerAttendancePDF(
    String workerId, {
    List<AttendanceModel>? records,
    UserModel? workerInfo,
  }) async {
    try {
      AppLogger.info('Starting PDF preview for worker: $workerId');

      // Fetch records if not provided
      final attendanceRecords =
          records ?? await getWorkerAttendanceRecords(workerId);
      final worker = workerInfo ?? await getWorkerInfo(workerId);

      if (attendanceRecords.isEmpty) {
        AppLogger.warning('No attendance records found for worker: $workerId');
        return;
      }

      // Create PDF document (same logic as export but for preview)
      final pdf = pw.Document();

      // Calculate total hours worked
      double totalHours = 0;
      int completeDays = 0;
      for (final record in attendanceRecords) {
        if (record.clockOut != null) {
          final duration = record.clockOut!.difference(record.clockIn);
          totalHours += duration.inMinutes / 60.0;
          completeDays++;
        }
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build:
              (context) => [
                // Header
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Gyefo Attendance Report',
                        style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        DateFormat('MMM dd, yyyy').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),

                // Worker Information
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300),
                    borderRadius: const pw.BorderRadius.all(
                      pw.Radius.circular(8),
                    ),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Worker Information',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text('Name: ${worker?.name ?? 'Unknown Worker'}'),
                      pw.Text('Worker ID: $workerId'),
                      if (worker?.email != null)
                        pw.Text('Email: ${worker!.email}'),
                      pw.SizedBox(height: 8),
                      pw.Text('Total Records: ${attendanceRecords.length}'),
                      pw.Text('Complete Days: $completeDays'),
                      pw.Text(
                        'Total Hours: ${totalHours.toStringAsFixed(2)} hours',
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20), // Attendance Records Table
                pw.Text(
                  'Attendance Records',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 10),

                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration: const pw.BoxDecoration(
                    color: PdfColors.blue600,
                  ),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding: const pw.EdgeInsets.all(8),
                  headers: [
                    'Date',
                    'Clock In',
                    'Clock Out',
                    'Hours Worked',
                    'Status',
                  ],
                  data:
                      attendanceRecords.map((record) {
                        final clockInFormatted = DateFormat(
                          'HH:mm:ss',
                        ).format(record.clockIn);
                        final clockOutFormatted =
                            record.clockOut != null
                                ? DateFormat(
                                  'HH:mm:ss',
                                ).format(record.clockOut!)
                                : '---';

                        String hoursWorked = 'In Progress';
                        String status = 'Incomplete';

                        if (record.clockOut != null) {
                          final duration = record.clockOut!.difference(
                            record.clockIn,
                          );
                          final hours = duration.inHours;
                          final minutes = duration.inMinutes % 60;
                          hoursWorked = '${hours}h ${minutes}m';
                          status = 'Complete';
                        }

                        return [
                          record.date,
                          clockInFormatted,
                          clockOutFormatted,
                          hoursWorked,
                          status,
                        ];
                      }).toList(),
                ),

                pw.SizedBox(height: 20),

                // Footer
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Generated by Gyefo Clocking App on ${DateFormat('MMMM dd, yyyy at HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
        ),
      ); // Preview the PDF
      if (kIsWeb) {
        // For web, open PDF in a new tab instead of preview
        final pdfBytes = await pdf.save();
        await Printing.sharePdf(
          bytes: pdfBytes,
          filename:
              '${worker?.name ?? 'Worker'}_attendance_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        );
      } else {
        // For mobile/desktop, use the layout preview
        await Printing.layoutPdf(
          onLayout: (format) async => pdf.save(),
          name:
              '${worker?.name ?? 'Worker'}_attendance_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
        );
      }

      AppLogger.success('PDF preview opened successfully');
    } catch (e) {
      AppLogger.error('Error previewing PDF: $e');
    }
  }
}
