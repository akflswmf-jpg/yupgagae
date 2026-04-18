import 'package:flutter/material.dart';

class HomeTopNoticeBar extends StatelessWidget {
  final String text;

  const HomeTopNoticeBar({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return _HomeTopLineBar(
      leading: const _BarBadge(label: '공지'),
      text: text,
      backgroundColor: const Color(0xFFFFFBEB),
      borderColor: const Color(0xFFF3E8B3),
      textColor: const Color(0xFF7C5A03),
    );
  }
}

class _HomeTopLineBar extends StatelessWidget {
  final Widget leading;
  final String text;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const _HomeTopLineBar({
    required this.leading,
    required this.text,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          leading,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.48,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarBadge extends StatelessWidget {
  final String label;

  const _BarBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFF4DE9A),
        ),
      ),
      child: const Text(
        '공지',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8A6508),
          height: 1.1,
        ),
      ),
    );
  }
}
