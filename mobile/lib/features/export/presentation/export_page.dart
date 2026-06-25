import 'package:app/features/export/models/export_job_model.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Export wizard page with two sections:
/// 1. Create New Export – camera ID, time pickers, and submit button.
/// 2. Export History – list of past/in-progress export jobs.
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  // ── Create export form state ──────────────────────────────────────────
  final TextEditingController _cameraIdController = TextEditingController();
  DateTime _startTime = DateTime.now().subtract(const Duration(hours: 1));
  DateTime _endTime = DateTime.now();

  // ── Mock export history ───────────────────────────────────────────────
  late final List<ExportJob> _exportJobs;

  @override
  void initState() {
    super.initState();
    _exportJobs = [
      ExportJob(
        id: 'exp-a1b2c3d4-e5f6-7890-abcd-ef1234567890',
        cameraId: 'cam-front-gate',
        siteId: 'site-001',
        startTime: DateTime.now().subtract(const Duration(hours: 6)),
        endTime: DateTime.now().subtract(const Duration(hours: 5)),
        status: 'COMPLETED',
        downloadUrl: 'https://cdn.vms.io/exports/exp-a1b2.mp4',
        progress: 1,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      ExportJob(
        id: 'exp-b2c3d4e5-f6a7-8901-bcde-f12345678901',
        cameraId: 'cam-parking-b',
        siteId: 'site-001',
        startTime: DateTime.now().subtract(const Duration(hours: 3)),
        endTime: DateTime.now().subtract(const Duration(hours: 2)),
        status: 'PROCESSING',
        progress: 0.65,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      ExportJob(
        id: 'exp-c3d4e5f6-a7b8-9012-cdef-123456789012',
        cameraId: 'cam-warehouse',
        siteId: 'site-001',
        startTime: DateTime.now().subtract(const Duration(hours: 2)),
        endTime: DateTime.now().subtract(const Duration(hours: 1)),
        status: 'FAILED',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  @override
  void dispose() {
    _cameraIdController.dispose();
    super.dispose();
  }

  // ── Date-time picker ──────────────────────────────────────────────────

  Future<void> _pickDateTime({required bool isStart}) async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: isStart ? _startTime : _endTime,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now,
      builder: (context, child) => _dateTimePickerTheme(child),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isStart ? _startTime : _endTime,
      ),
      builder: (context, child) => _dateTimePickerTheme(child),
    );
    if (pickedTime == null || !mounted) return;

    final combined = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      if (isStart) {
        _startTime = combined;
      } else {
        _endTime = combined;
      }
    });
  }

  Widget _dateTimePickerTheme(Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF02965E),
          surface: Color(0xFF2A2D35),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D23),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2D35),
        elevation: 0,
        title: const Text(
          'Export',
          style: TextStyle(
            color: Color(0xFFE0E0E0),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFFE0E0E0)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ═══ Section 1: Create New Export ════════════════════════
            _buildSectionHeader('Create New Export'),
            const SizedBox(height: 12),
            _buildCreateExportForm(),

            const SizedBox(height: 32),

            // ═══ Section 2: Export History ═══════════════════════════
            _buildSectionHeader('Export History'),
            const SizedBox(height: 12),
            ..._exportJobs.map(_buildExportJobCard),
          ],
        ),
      ),
    );
  }

  // ── Section header ────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFE0E0E0),
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  // ── Create export form ────────────────────────────────────────────────

  Widget _buildCreateExportForm() {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Camera ID field
          TextField(
            controller: _cameraIdController,
            style: const TextStyle(color: Color(0xFFE0E0E0)),
            decoration: InputDecoration(
              labelText: 'Camera ID',
              labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
              hintText: 'e.g. cam-front-gate',
              hintStyle: TextStyle(
                color: const Color(0xFF9E9E9E).withValues(alpha: 0.5),
              ),
              prefixIcon: const Icon(
                Icons.videocam_outlined,
                color: Color(0xFF9E9E9E),
              ),
              filled: true,
              fillColor: const Color(0xFF1A1D23),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3A3D45)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF3A3D45)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF02965E)),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Start time picker
          _buildTimePicker(
            label: 'Start Time',
            value: dateFormat.format(_startTime),
            onTap: () => _pickDateTime(isStart: true),
          ),

          const SizedBox(height: 12),

          // End time picker
          _buildTimePicker(
            label: 'End Time',
            value: dateFormat.format(_endTime),
            onTap: () => _pickDateTime(isStart: false),
          ),

          const SizedBox(height: 20),

          // Start Export button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF02965E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.file_download, size: 20),
              label: const Text(
                'Start Export',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Export initiated'),
                    backgroundColor: const Color(0xFF02965E),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1D23),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3A3D45)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule,
              color: Color(0xFF9E9E9E),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF9E9E9E),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar,
              color: Color(0xFF9E9E9E),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── Export job card ────────────────────────────────────────────────────

  Widget _buildExportJobCard(ExportJob job) {
    final statusColor = _statusColor(job.status);
    final truncatedId =
        job.id.length > 12 ? '${job.id.substring(0, 12)}…' : job.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2D35),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: Job ID + status badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file_outlined,
                    color: Color(0xFF9E9E9E),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    truncatedId,
                    style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  job.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Camera + time info
          Text(
            'Camera: ${job.cameraId}',
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${DateFormat('HH:mm').format(job.startTime)}'
            ' – ${DateFormat('HH:mm').format(job.endTime)}',
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 12,
            ),
          ),

          // Progress bar for PROCESSING
          if (job.status == 'PROCESSING' && job.progress != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: job.progress,
                      backgroundColor: const Color(0xFF1A1D23),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        statusColor,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(job.progress! * 100).toInt()}%',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],

          // Download button for COMPLETED
          if (job.isCompleted) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF02965E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                icon: const Icon(Icons.download, size: 16),
                label: const Text(
                  'Download',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Downloading ${job.id}'),
                      backgroundColor: const Color(0xFF02965E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return const Color(0xFF02965E);
      case 'PROCESSING':
        return const Color(0xFFFF9800);
      case 'FAILED':
        return const Color(0xFFD32F2F);
      case 'PENDING':
      default:
        return const Color(0xFF9E9E9E);
    }
  }
}
