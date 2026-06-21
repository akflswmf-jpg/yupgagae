import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/policy/app_policy_documents.dart';

class PolicyDocumentScreen extends StatelessWidget {
  final AppPolicyDocument document;

  const PolicyDocumentScreen({
    super.key,
    required this.document,
  });

  @override
  Widget build(BuildContext context) {
    const Color textStrong = Color(0xFF25211F);
    const Color textNormal = Color(0xFF4B5563);
    const Color textSoft = Color(0xFF8A817C);
    const Color border = Color(0xFFEDE7E3);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(
          document.title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: textStrong,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: textStrong,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          physics: const ClampingScrollPhysics(),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.required ? '필수 동의 항목' : '선택 동의 항목',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: textSoft,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    document.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: textStrong,
                      height: 1.25,
                      letterSpacing: -0.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(17, 17, 17, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: border),
              ),
              child: Text(
                document.body.trim(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textNormal,
                  height: 1.6,
                  letterSpacing: -0.15,
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: Get.back,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: const Color(0xFFA56E5F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  '확인',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}