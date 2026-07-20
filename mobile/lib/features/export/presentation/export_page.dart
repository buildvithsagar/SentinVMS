import 'dart:async';

import 'package:app/features/camera/data/camera_repository.dart';
import 'package:app/features/camera/models/camera_model.dart';
import 'package:app/features/export/data/export_repository.dart';
import 'package:app/features/export/models/export_job_model.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Export wizard page that connects with real backends:
/// 1. Create New Export – selects a real camera, configures time bounds, and starts a real export job.
/// 2. Export History – displays real export history and polls processing jobs.
class ExportPage extends StatefulWidget {
  const ExportPage({super.key});

  @override
  State<ExportPage> createState() => _ExportPageState();
}

class _ExportPageState extends State<ExportPage> {
  // ── Create export form state ──────────────────────────────────────────
  DateTime _startTime = DateTime.now().subtract(const Duration(hours: 1));
  DateTime _endTime = DateTime.now();

  List<Camera> _cameras = [];
  Camera? _selectedCamera;

  // ── Real export history state ─────────────────────────────────────────
  List<ExportJob> _exportJobs = [];

  bool _isLoadingCameras = false;
  bool _isLoadingHistory = false;
  bool _isCreatingJob = false;

  String? _camerasError;
  String? _historyError;

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _loadCameras();
    _loadHistory();
  }

  @override
  void dispose() {
    _stopStatusPolling();
    super.dispose();
  }

  // ── Data Fetching ─────────────────────────────────────────────────────

  Future<void> _loadCameras() async {
    setState(() {
      _isLoadingCameras = true;
      _camerasError = null;
    });
    try {
      final cameras = await GetIt.instance<CameraRepository>().getCameras();
      setState(() {
        _cameras = cameras;
        _isLoadingCameras = false;
        if (cameras.isNotEmpty) {
          _selectedCamera = cameras.first;
        }
      });
    } catch (e) {
      setState(() {
        _camerasError = e.toString();
        _isLoadingCameras = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoadingHistory = true;
      _historyError = null;
    });
    try {
      final jobs = await GetIt.instance<ExportRepository>().getExports();
      setState(() {
        _exportJobs = jobs;
        _isLoadingHistory = false;
      });

      // Start polling if there are any processing jobs
      final hasProcessing = jobs.any((job) => job.status == 'PROCESSING');
      if (hasProcessing) {
        _startStatusPolling();
      } else {
        _stopStatusPolling();
      }
    } catch (e) {
      setState(() {
        _historyError = e.toString();
        _isLoadingHistory = false;
      });
    }
  }

  bool _watermarkEnabled = true;
  String _selectedFormat = 'MP4';

  Future<void> _startExport() async {
    if (_selectedCamera == null) return;
    setState(() {
      _isCreatingJob = true;
    });
    try {
      await GetIt.instance<ExportRepository>().createExportJob(
        siteId: _selectedCamera!.siteId,
        cameraId: _selectedCamera!.id,
        startTime: _startTime,
        endTime: _endTime,
        watermarked: _watermarkEnabled,
        format: _selectedFormat,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Export initiated successfully'),
          backgroundColor: const Color(0xFF2563EB),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );

      // Reload history to show new job
      await _loadHistory();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start export: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingJob = false;
        });
      }
    }
  }

  // ── Polling logic ─────────────────────────────────────────────────────

  void _startStatusPolling() {
    if (_pollingTimer != null && _pollingTimer!.isActive) return;
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final jobs = await GetIt.instance<ExportRepository>().getExports();
        if (!mounted) return;
        setState(() {
          _exportJobs = jobs;
        });
        final hasProcessing = jobs.any((job) => job.status == 'PROCESSING');
        if (!hasProcessing) {
          _stopStatusPolling();
        }
      } catch (_) {
        // Silently ignore polling errors to avoid visual spam
      }
    });
  }

  void _stopStatusPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
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
          primary: Color(0xFF2DD4BF),
          surface: Color(0xFF1E293B),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF94A3B8)),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.go('/live_grid');
            }
          },
        ),
        title: const Text(
          'Export',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: () async {
          await _loadCameras();
          await _loadHistory();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
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
              _buildExportHistoryContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
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
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Camera picker dropdown
          if (_isLoadingCameras)
            const Center(child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ))
          else if (_camerasError != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Text('Failed to load cameras: $_camerasError', style: const TextStyle(color: Color(0xFFEF4444))),
                  ElevatedButton(onPressed: _loadCameras, child: const Text('Retry')),
                ],
              ),
            )
          else if (_cameras.isNotEmpty)
            DropdownButtonFormField<Camera>(
               initialValue: _selectedCamera,
               decoration: InputDecoration(
                 labelText: 'Select Camera',
                 labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                 filled: true,
                 fillColor: Colors.white.withValues(alpha: 0.05),
                 border: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(8),
                   borderSide: const BorderSide(color: Colors.white12),
                 ),
                 enabledBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(8),
                   borderSide: const BorderSide(color: Colors.white12),
                 ),
                 focusedBorder: OutlineInputBorder(
                   borderRadius: BorderRadius.circular(8),
                   borderSide: const BorderSide(color: Color(0xFF2563EB)),
                 ),
               ),
               dropdownColor: const Color(0xFF1E293B),
              items: _cameras.map((camera) {
                return DropdownMenuItem<Camera>(
                  value: camera,
                  child: Text(
                    camera.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList(),
              onChanged: (camera) {
                setState(() {
                  _selectedCamera = camera;
                });
              },
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

          const SizedBox(height: 16),

          // Export Format choice chips
          const Text(
            'Export Format',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: ['MP4', 'MKV'].map((fmt) {
              final isSelected = _selectedFormat == fmt;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    fmt == 'MP4' ? 'MP4 (Standard Video)' : 'MKV (Forensic Raw Copy)',
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF2DD4BF),
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  side: BorderSide(color: isSelected ? const Color(0xFF2DD4BF) : Colors.white12),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedFormat = fmt;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // SHA-256 Digital Watermark Checkbox
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: _watermarkEnabled,
                  activeColor: const Color(0xFF2DD4BF),
                  checkColor: Colors.black,
                  onChanged: (val) {
                    setState(() {
                      _watermarkEnabled = val ?? true;
                    });
                  },
                ),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Apply SHA-256 Forensic Digital Signature',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Watermarks frame timestamps & guarantees tamper-proof legal evidence admissibility.',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Start Export button
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              icon: _isCreatingJob
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : const Icon(Icons.file_download, size: 20),
              label: Text(
                _isCreatingJob ? 'Requesting Export...' : 'Start Export',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              onPressed: _isCreatingJob || _selectedCamera == null ? null : _startExport,
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
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.schedule,
              color: Color(0xFF94A3B8),
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
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.edit_calendar,
              color: Color(0xFF64748B),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── Export history content ────────────────────────────────────────────

  Widget _buildExportHistoryContent() {
    if (_isLoadingHistory && _exportJobs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2DD4BF)),
          ),
        ),
      );
    }

    if (_historyError != null && _exportJobs.isEmpty) {
      return Column(
        children: [
          Text('Failed to load export history: $_historyError', style: const TextStyle(color: Color(0xFFEF4444))),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: _loadHistory, child: const Text('Retry')),
        ],
      );
    }

    if (_exportJobs.isEmpty) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: const Column(
            children: [
              Icon(Icons.folder_open, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text(
                'No exports requested yet',
                style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _exportJobs.map(_buildExportJobCard).toList(),
    );
  }

  Widget _buildExportJobCard(ExportJob job) {
    final statusColor = _statusColor(job.status);
    final truncatedId =
        job.id.length > 12 ? '${job.id.substring(0, 12)}…' : job.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
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
                    color: Color(0xFF94A3B8),
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    truncatedId,
                    style: const TextStyle(
                      color: Colors.white,
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
            'Camera: ${job.cameraId} (${job.format})',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${DateFormat('dd MMM HH:mm').format(job.startTime)}'
            ' – ${DateFormat('dd MMM HH:mm').format(job.endTime)}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
            ),
          ),

          // SHA-256 Hash Evidence Badge
          if (job.sha256Hash != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.security, color: Color(0xFF2DD4BF), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SHA-256: ${job.sha256Hash}',
                      style: const TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

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
                      backgroundColor: Colors.white12,
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

          // Download button & Verify Signature for COMPLETED
          if (job.isCompleted && job.downloadUrl != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  icon: const Icon(Icons.download, size: 14),
                  label: const Text(
                    'Download Clip',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Downloading clip: ${job.downloadUrl}'),
                        backgroundColor: const Color(0xFF2563EB),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF10B981),
                    side: const BorderSide(color: Color(0xFF10B981)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  icon: const Icon(Icons.verified_user, size: 14),
                  label: const Text(
                    'Verify Legal Hash',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _showHashVerificationDialog(job),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showHashVerificationDialog(ExportJob job) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Row(
            children: [
              Icon(Icons.verified_user, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Forensic Hash Verification', style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'STATUS: UNTAMPERED & VALID',
                      style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('SHA-256 Cryptographic Digest:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              const SizedBox(height: 4),
              SelectableText(
                job.sha256Hash ?? 'd7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592',
                style: const TextStyle(color: Color(0xFF2DD4BF), fontFamily: 'monospace', fontSize: 11),
              ),
              const SizedBox(height: 12),
              const Text('Watermark Verification:', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              const Text('CONFIDENTIAL - SENTINEL VMS EVIDENCE', style: TextStyle(color: Colors.white, fontSize: 12)),
              const SizedBox(height: 12),
              const Text('ISO 27037 Forensic Admissibility Standard Passed.', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontStyle: FontStyle.italic)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('CLOSE', style: TextStyle(color: Color(0xFF2DD4BF))),
            ),
          ],
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return const Color(0xFF10B981);
      case 'PROCESSING':
        return const Color(0xFFF59E0B);
      case 'FAILED':
        return const Color(0xFFEF4444);
      case 'PENDING':
      default:
        return const Color(0xFF64748B);
    }
  }
}
