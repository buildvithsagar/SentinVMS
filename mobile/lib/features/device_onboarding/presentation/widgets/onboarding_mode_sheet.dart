import 'dart:ui';

import 'package:app/core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Glassmorphic Onboarding Mode Selection Sheet
/// Refined Apple/Verkada Dark Glassmorphism modal styling with subtle slate badges & soft blue accents.
class OnboardingModeSheet extends StatelessWidget {
  const OnboardingModeSheet({
    required this.category,
    required this.categoryName,
    super.key,
  });

  final String category;
  final String categoryName;

  @override
  Widget build(BuildContext context) {
    const baseCanvas = VmsColors.surface;
    const primaryText = VmsColors.textPrimary;
    const mutedText = VmsColors.textSecondary;
    const glassBorder = VmsColors.border;
    const activeBlue = VmsColors.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: baseCanvas.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
            border: Border.all(color: glassBorder.withValues(alpha: 0.6)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 10,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: mutedText.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title & Category Chip Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ONBOARDING METHOD',
                          style: TextStyle(
                            color: mutedText,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          categoryName,
                          style: const TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: VmsColors.surfaceHigh,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: glassBorder),
                    ),
                    child: Text(
                      category.toUpperCase(),
                      style: const TextStyle(
                        color: VmsColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Mode Tiles
              _ModeTile(
                icon: Icons.qr_code_scanner_rounded,
                title: 'Scan QR ID / InstaOn',
                subtitle:
                    'Instant P2P pairing via device label barcode or QR scan',
                badgeText: 'RECOMMENDED',
                onTap: () {
                  context
                    ..pop()
                    ..push(
                      '/onboard/register?category=$category&mode=insta_on&scan=true&name=${Uri.encodeComponent(categoryName)}',
                    );
                },
              ),
              const SizedBox(height: 12),
              _ModeTile(
                icon: Icons.dns_rounded,
                title: 'IP / Domain (Manual Entry)',
                subtitle:
                    'Direct network IP, RTSP/HTTP port & credential configuration',
                badgeText: 'MANUAL',
                onTap: () {
                  context
                    ..pop()
                    ..push(
                      '/onboard/register?category=$category&mode=ip_domain&name=${Uri.encodeComponent(categoryName)}',
                    );
                },
              ),
              const SizedBox(height: 12),
              _ModeTile(
                icon: Icons.travel_explore_rounded,
                title: 'LAN Search (Subnet Discovery)',
                subtitle: 'Automated ONVIF Profile S/T/M local broadcast scan',
                badgeText: 'EDGE DISCOVERY',
                onTap: () {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: VmsColors.surfaceHigh,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: activeBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      content: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: activeBlue,
                            size: 20,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'LAN discovery is active via Edge Loopback proxy.',
                              style: TextStyle(
                                color: primaryText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic Animated Mode Option Tile
class _ModeTile extends StatefulWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badgeText,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? badgeText;
  final VoidCallback onTap;

  @override
  State<_ModeTile> createState() => _ModeTileState();
}

class _ModeTileState extends State<_ModeTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const primaryText = VmsColors.textPrimary;
    const mutedText = VmsColors.textSecondary;
    const glassBorder = VmsColors.border;
    const activeBlue = VmsColors.primary;

    return AnimatedScale(
      scale: _isPressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: _isPressed
                ? VmsColors.surfaceHighest
                : VmsColors.surfaceHigh,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isPressed
                  ? activeBlue
                  : glassBorder.withValues(alpha: 0.6),
              width: _isPressed ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: VmsColors.surfaceHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: glassBorder.withValues(alpha: 0.6)),
                ),
                child: Icon(
                  widget.icon,
                  color: _isPressed ? activeBlue : VmsColors.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: primaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.badgeText != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: VmsColors.surfaceHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.badgeText!,
                              style: const TextStyle(
                                color: VmsColors.textSecondary,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: TextStyle(
                        color: mutedText.withValues(alpha: 0.85),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: _isPressed
                    ? activeBlue
                    : mutedText.withValues(alpha: 0.5),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
