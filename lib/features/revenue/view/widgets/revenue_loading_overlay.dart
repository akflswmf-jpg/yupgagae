import 'package:flutter/material.dart';

import 'package:yupgagae/features/revenue/view/revenue_theme_tokens.dart';

class RevenueLoadingOverlay extends StatelessWidget {
  final bool visible;

  const RevenueLoadingOverlay({
    super.key,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: kRevenueLoadingOverlay,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}