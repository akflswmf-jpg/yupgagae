import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/policy/app_policy_documents.dart';
import 'package:yupgagae/routes/app_routes.dart';

class PolicyListScreen extends StatelessWidget {
  const PolicyListScreen({super.key});

  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kPrimarySoft = Color(0xFFF6EEEA);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);

  Future<void> _openDocument(AppPolicyDocument document) async {
    await Get.toNamed(
      AppRoutes.policyDocument,
      arguments: document,
    );
  }

  String _subtitleOf(AppPolicyDocument document) {
    switch (document.type) {
      case AppPolicyDocumentType.terms:
        return '옆가게 서비스 이용 기준을 확인합니다';
      case AppPolicyDocumentType.privacy:
        return '개인정보 수집과 이용 기준을 확인합니다';
      case AppPolicyDocumentType.community:
        return '커뮤니티 이용 기준을 확인합니다';
      case AppPolicyDocumentType.moderation:
        return '신고와 제재 기준을 확인합니다';
      case AppPolicyDocumentType.revenueData:
        return '하루결 데이터 활용 기준을 확인합니다';
      case AppPolicyDocumentType.push:
        return '알림 설정에서 별도로 선택할 수 있습니다';
    }
  }

  IconData _iconOf(AppPolicyDocument document) {
    switch (document.type) {
      case AppPolicyDocumentType.terms:
        return Icons.description_rounded;
      case AppPolicyDocumentType.privacy:
        return Icons.privacy_tip_rounded;
      case AppPolicyDocumentType.community:
        return Icons.forum_rounded;
      case AppPolicyDocumentType.moderation:
        return Icons.gavel_rounded;
      case AppPolicyDocumentType.revenueData:
        return Icons.bar_chart_rounded;
      case AppPolicyDocumentType.push:
        return Icons.notifications_rounded;
    }
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '약관 및 정책',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: _kTextStrong,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          SizedBox(height: 8),
          Text(
            '옆가게 이용 기준과 개인정보 처리 기준을\n필요할 때 다시 확인할 수 있습니다.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: _kTextNormal,
              height: 1.45,
              letterSpacing: -0.15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentTile({
    required AppPolicyDocument document,
    required bool showDivider,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _openDocument(document),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 14, 15),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _kPrimarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      _iconOf(document),
                      size: 19,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _kTextStrong,
                            letterSpacing: -0.25,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _subtitleOf(document),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _kTextSoft,
                            height: 1.35,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB0B8C1),
                  ),
                ],
              ),
            ),
            if (showDivider)
              const Divider(
                height: 1,
                indent: 65,
                color: Color(0xFFF1F3F5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    final documents = AppPolicyDocuments.requiredDocuments;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        children: [
          for (int i = 0; i < documents.length; i++)
            _buildDocumentTile(
              document: documents[i],
              showDivider: i != documents.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        '푸시 알림 수신 여부는 내가게의 알림 설정에서\n언제든지 따로 변경할 수 있습니다.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _kTextSoft,
          height: 1.45,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          '약관 및 정책',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _kTextStrong,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _kTextStrong,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
          physics: const ClampingScrollPhysics(),
          children: [
            _buildHeader(),
            const SizedBox(height: 14),
            _buildList(),
            const SizedBox(height: 18),
            _buildFooter(),
          ],
        ),
      ),
    );
  }
}