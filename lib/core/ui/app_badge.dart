import 'package:flutter/material.dart';

enum UserAuthBadge { neighbor, owner, verified }

class AppBadge extends StatelessWidget {
  final UserAuthBadge authBadge;

  const AppBadge({super.key, required this.authBadge});

  @override
  Widget build(BuildContext context) {
    String label;
    IconData icon;

    switch (authBadge) {
      case UserAuthBadge.neighbor:
        label = '이웃';
        icon = Icons.person_outline;
        break;
      case UserAuthBadge.owner:
        label = '사장님';
        icon = Icons.storefront_outlined;
        break;
      case UserAuthBadge.verified:
        label = '인증';
        icon = Icons.verified_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.black.withOpacity(0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}