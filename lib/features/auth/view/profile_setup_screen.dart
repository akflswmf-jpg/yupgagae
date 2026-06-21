import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/policy/app_policy_documents.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/routes/app_routes.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kPrimarySoft = Color(0xFFF6EEEA);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);
  static const Color _kInputFill = Color(0xFFFFFFFF);

  late final AuthController controller;
  late final TextEditingController nicknameController;

  final Set<AppPolicyDocumentType> agreedRequiredPolicyTypes =
      <AppPolicyDocumentType>{};

  bool pushAgreed = false;
  String? selectedIndustry;
  String? selectedRegion;

  bool get allRequiredPoliciesAgreed {
    return AppPolicyDocuments.requiredDocuments.every(
      (document) => agreedRequiredPolicyTypes.contains(document.type),
    );
  }

  @override
  void initState() {
    super.initState();

    controller = Get.find<AuthController>();

    final user = controller.currentUser.value;

    nicknameController = TextEditingController(
      text: user?.nickname ?? '',
    );

    selectedIndustry = user?.industry;
    selectedRegion = user?.region;
  }

  @override
  void dispose() {
    nicknameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final nickname = nicknameController.text.trim();
    final industry = selectedIndustry?.trim() ?? '';
    final region = selectedRegion?.trim() ?? '';

    FocusScope.of(context).unfocus();

    if (!allRequiredPoliciesAgreed) {
      _showSnack('필수 약관에 모두 동의해주세요.');
      return;
    }

    if (nickname.isEmpty) {
      _showSnack('닉네임을 입력해주세요.');
      return;
    }

    if (nickname.length < 2) {
      _showSnack('닉네임은 2자 이상이어야 합니다.');
      return;
    }

    if (nickname.length > 12) {
      _showSnack('닉네임은 12자 이하로 입력해주세요.');
      return;
    }

    if (industry.isEmpty) {
      _showSnack('업종을 선택해주세요.');
      return;
    }

    if (region.isEmpty) {
      _showSnack('지역을 선택해주세요.');
      return;
    }

    try {
      await controller.completeProfileSetup(
        termsAgreed: allRequiredPoliciesAgreed,
        termsVersion: AppPolicyDocuments.bundleVersion,
        pushAgreed: pushAgreed,
        nickname: nickname,
        industry: industry,
        region: region,
      );

      if (!mounted) return;

      Get.offAllNamed(AppRoutes.root);
    } catch (_) {
      final message = controller.errorMessage.value;
      if (message != null && message.trim().isNotEmpty) {
        _showSnack(message);
      }
    }
  }

  void _showSnack(String message) {
    Get.snackbar(
      '안내',
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      borderRadius: 14,
      backgroundColor: Colors.black.withValues(alpha: 0.82),
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  List<String> _industryOptions() {
    return IndustryCatalog.ordered()
        .map((e) => e.name)
        .where((e) => e.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  List<String> _regionOptions() {
    return StoreProfile.regionOptions
        .where((e) => e.trim().isNotEmpty)
        .toList(growable: false);
  }

  void _toggleRequiredPolicy(AppPolicyDocument document) {
    setState(() {
      if (agreedRequiredPolicyTypes.contains(document.type)) {
        agreedRequiredPolicyTypes.remove(document.type);
      } else {
        agreedRequiredPolicyTypes.add(document.type);
      }
    });
  }

  void _setAllRequiredPolicies(bool checked) {
    setState(() {
      if (checked) {
        agreedRequiredPolicyTypes
          ..clear()
          ..addAll(
            AppPolicyDocuments.requiredDocuments.map((e) => e.type),
          );
      } else {
        agreedRequiredPolicyTypes.clear();
      }
    });
  }

  void _setPushAgreed(bool value) {
    setState(() {
      pushAgreed = value;
    });
  }

  void _openPolicyDocument(AppPolicyDocument document) {
    Get.toNamed(
      AppRoutes.policyDocument,
      arguments: document,
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '기본 정보를 설정해주세요',
          style: TextStyle(
            fontSize: 27,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: _kTextStrong,
            height: 1.15,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '옆가게에서 사용할 닉네임, 업종, 지역을 설정합니다.\n게시글 작성과 커뮤니티 이용 기준으로 사용됩니다.',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: _kTextNormal,
            height: 1.45,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: _kPrimarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D8D0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: 18,
            color: _kPrimary,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '가입 후 바로 옆가게를 이용할 수 있습니다.\n사장님 전용 기능은 사업자 인증 후 열립니다.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B4D44),
                height: 1.4,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNicknameField() {
    return TextField(
      controller: nicknameController,
      maxLength: 12,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: _kInputFill,
        labelText: '닉네임',
        hintText: '예: 옆자리',
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _kTextSoft,
        ),
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFC0B8B2),
        ),
        contentPadding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _kPrimary, width: 1.2),
        ),
      ),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: _kTextStrong,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildIndustryDropdown() {
    final options = _industryOptions();

    return DropdownButtonFormField<String>(
      initialValue: _safeInitialValue(selectedIndustry, options),
      items: options
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        setState(() {
          selectedIndustry = value;
        });
      },
      decoration: _dropdownDecoration(
        label: '업종',
        hint: '업종을 선택해주세요',
      ),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: _kTextStrong,
        letterSpacing: -0.2,
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(16),
      isExpanded: true,
    );
  }

  Widget _buildRegionDropdown() {
    final options = _regionOptions();

    return DropdownButtonFormField<String>(
      initialValue: _safeInitialValue(selectedRegion, options),
      items: options
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        setState(() {
          selectedRegion = value;
        });
      },
      decoration: _dropdownDecoration(
        label: '지역',
        hint: '지역을 선택해주세요',
      ),
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: _kTextStrong,
        letterSpacing: -0.2,
      ),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(16),
      isExpanded: true,
    );
  }

  String? _safeInitialValue(String? value, List<String> options) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (!options.contains(normalized)) return null;
    return normalized;
  }

  InputDecoration _dropdownDecoration({
    required String label,
    required String hint,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: _kInputFill,
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: _kTextSoft,
      ),
      hintStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFFC0B8B2),
      ),
      contentPadding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: _kPrimary, width: 1.2),
      ),
    );
  }

  Widget _buildPolicySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: allRequiredPoliciesAgreed ? _kPrimary : _kBorder,
          width: allRequiredPoliciesAgreed ? 1.2 : 1,
        ),
      ),
      child: Column(
        children: [
          _buildAllRequiredPolicyRow(),
          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFF1F3F5)),
          const SizedBox(height: 8),
          for (final document in AppPolicyDocuments.requiredDocuments)
            _buildRequiredPolicyRow(document),
        ],
      ),
    );
  }

  Widget _buildAllRequiredPolicyRow() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _setAllRequiredPolicies(!allRequiredPoliciesAgreed),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            allRequiredPoliciesAgreed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 23,
            color: allRequiredPoliciesAgreed ? _kPrimary : _kTextSoft,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '필수 약관 전체 동의',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: _kTextStrong,
                height: 1.35,
                letterSpacing: -0.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequiredPolicyRow(AppPolicyDocument document) {
    final checked = agreedRequiredPolicyTypes.contains(document.type);

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _toggleRequiredPolicy(document),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 7, 8, 7),
              child: Icon(
                checked
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 21,
                color: checked ? _kPrimary : _kTextSoft,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _toggleRequiredPolicy(document),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Text(
                  '[필수] ${document.label} 동의',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _kTextStrong,
                    height: 1.35,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => _openPolicyDocument(document),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: _kTextSoft,
            ),
            child: const Text(
              '보기',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPushNotificationSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: pushAgreed ? _kPrimarySoft : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              Icons.notifications_rounded,
              size: 19,
              color: pushAgreed ? _kPrimary : _kTextSoft,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '푸시알림 받기',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w900,
                color: _kTextStrong,
                height: 1.3,
                letterSpacing: -0.25,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: pushAgreed,
            activeThumbColor: _kPrimary,
            onChanged: _setPushAgreed,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Obx(() {
      final loading = controller.isCompletingProfileSetup.value;

      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: loading ? null : _submit,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: _kPrimary,
            disabledBackgroundColor: const Color(0xFFD8C8C1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '가입 완료',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          '가입 설정',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _kTextStrong,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
          physics: const ClampingScrollPhysics(),
          children: [
            _buildHeader(),
            const SizedBox(height: 18),
            _buildNoticeBox(),
            const SizedBox(height: 18),
            _buildNicknameField(),
            const SizedBox(height: 12),
            _buildIndustryDropdown(),
            const SizedBox(height: 12),
            _buildRegionDropdown(),
            const SizedBox(height: 16),
            _buildPolicySection(),
            const SizedBox(height: 12),
            _buildPushNotificationSection(),
            const SizedBox(height: 22),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }
}