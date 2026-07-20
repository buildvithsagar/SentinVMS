import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasDetected = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryBg = Color(0xFF0D0E12);
    const primaryText = Color(0xFFE2E8F0);
    const accentGreen = Color(0xFF02965E);

    return Scaffold(
      backgroundColor: primaryBg,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.4),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: primaryText),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Scan QR / Barcode',
          style: TextStyle(color: primaryText, fontWeight: FontWeight.w600),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (barcodeCapture) {
              if (_hasDetected) return;
              final barcodes = barcodeCapture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue;
                if (code != null && code.isNotEmpty) {
                  setState(() {
                    _hasDetected = true;
                  });
                  context.pop(code); // Return scanned code
                }
              }
            },
          ),
          // Custom tactical overlay (glassmorphism look & target finder box)
          _buildScannerOverlay(context, accentGreen),
        ],
      ),
    );
  }

  Widget _buildScannerOverlay(BuildContext context, Color themeColor) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.7;

    return Stack(
      children: [
        // Dark translucent backgrounds surrounding target area
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.6),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                child: Container(
                  width: scanAreaSize,
                  height: scanAreaSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Target Box corners decoration
        Align(
          child: SizedBox(
            width: scanAreaSize,
            height: scanAreaSize,
            child: CustomPaint(
              painter: _ScannerTargetPainter(color: themeColor, strokeWidth: 4),
            ),
          ),
        ),
        // Scan label instruction
        const Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              'Align QR / Barcode inside the frame to scan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ScannerTargetPainter extends CustomPainter {
  _ScannerTargetPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const cornerLength = 24.0;
    final w = size.width;
    final h = size.height;

    // Top-Left corner
    canvas
      ..drawPath(
        Path()
          ..moveTo(0, cornerLength)
          ..lineTo(0, 0)
          ..lineTo(cornerLength, 0),
        paint,
      )
      // Top-Right corner
      ..drawPath(
        Path()
          ..moveTo(w - cornerLength, 0)
          ..lineTo(w, 0)
          ..lineTo(w, cornerLength),
        paint,
      )
      // Bottom-Left corner
      ..drawPath(
        Path()
          ..moveTo(0, h - cornerLength)
          ..lineTo(0, h)
          ..lineTo(cornerLength, h),
        paint,
      )
      // Bottom-Right corner
      ..drawPath(
        Path()
          ..moveTo(w - cornerLength, h)
          ..lineTo(w, h)
          ..lineTo(w, h - cornerLength),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
