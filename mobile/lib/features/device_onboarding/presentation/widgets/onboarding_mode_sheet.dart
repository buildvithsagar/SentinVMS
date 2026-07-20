import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    const sheetBg = Color(0xFF14161F);
    const borderBg = Color(0xFF1F222F);
    const primaryText = Color(0xFFE2E8F0);
    const mutedText = Color(0xFF70788C);

    return Container(
      decoration: const BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Grab handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: mutedText.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ONBOARD - $categoryName',
            style: const TextStyle(
              color: mutedText,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          _ModeTile(
            icon: Icons.qr_code_scanner,
            title: 'Scan QR ID / InstaOn',
            onTap: () {
              context
                ..pop()
                ..push(
                  '/onboard/register?category=$category&mode=insta_on&scan=true',
                );
            },
          ),
          const SizedBox(height: 10),
          _ModeTile(
            icon: Icons.dns,
            title: 'IP/Domain (Manual entry)',
            onTap: () {
              context
                ..pop()
                ..push(
                  '/onboard/register?category=$category&mode=ip_domain',
                );
            },
          ),
          const SizedBox(height: 10),
          _ModeTile(
            icon: Icons.search,
            title: 'LAN Search (Local Discovery)',
            onTap: () {
              context.pop(); // Dismiss sheet
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: borderBg,
                  content: Text(
                    'LAN search is deferred to Phase 2 (Edge Auto-discovery active).',
                    style: TextStyle(color: primaryText),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const tileBg = Color(0xFF1C1E29);
    const primaryText = Color(0xFFE2E8F0);

    return Material(
      color: tileBg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: primaryText, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFF70788C),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
