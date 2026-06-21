import 'package:flutter/material.dart';
import 'package:yupgagae/shared/widgets/card_stub.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: CardStub(text: '설정(내 업종/사업자 인증 상태/알림 등)'),
      ),
    );
  }
}