import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/ui/app_toast.dart';

class BusinessVerificationScreen extends StatefulWidget {
  const BusinessVerificationScreen({super.key});

  @override
  State<BusinessVerificationScreen> createState() =>
      _BusinessVerificationScreenState();
}

class _BusinessVerificationScreenState
    extends State<BusinessVerificationScreen> {
  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);

  static const Color _kErrorBg = Color(0xFFFFFAF7);
  static const Color _kErrorBorder = Color(0xFFF0D8CE);
  static const Color _kErrorIcon = Color(0xFFC76F52);
  static const Color _kErrorText = Color(0xFF6B4D44);

  static const Color _kSuccessBorder = Color(0xFFBBF7D0);
  static const Color _kSuccessText = Color(0xFF166534);

  late final AuthController auth;
  late final TextEditingController businessNumberController;
  late final TextEditingController representativeNameController;
  late final TextEditingController openedAtController;

  bool agreed = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    auth = Get.find<AuthController>();
    businessNumberController = TextEditingController();
    representativeNameController = TextEditingController();
    openedAtController = TextEditingController();
  }

  @override
  void dispose() {
    businessNumberController.dispose();
    representativeNameController.dispose();
    openedAtController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    if (!mounted) return;

    setState(() {
      errorText = message;
    });
  }

  void _clearError() {
    if (errorText == null) return;

    setState(() {
      errorText = null;
    });
  }

  Future<void> _submit() async {
    final businessNumber = businessNumberController.text.trim();
    final representativeName = representativeNameController.text.trim();
    final openedAt = openedAtController.text.trim();

    FocusScope.of(context).unfocus();
    _clearError();

    final user = auth.currentUser.value;

    if (user == null) {
      _showError('로그인이 필요합니다.');
      return;
    }

    if (user.needsProfileSetup) {
      _showError('가입 설정을 먼저 완료해주세요.');
      return;
    }

    if (user.isBusinessVerified) {
      AppToast.show('이미 사업자 인증이 완료되었습니다.', title: '완료');
      return;
    }

    if (!_isValidBusinessNumber(businessNumber)) {
      _showError('사업자등록번호 10자리를 입력해주세요.');
      return;
    }

    if (_isRepeatedDigits(businessNumber)) {
      _showError('사업자등록번호를 다시 확인해주세요.');
      return;
    }

    if (representativeName.isEmpty) {
      _showError('대표자명을 입력해주세요.');
      return;
    }

    if (representativeName.length < 2) {
      _showError('대표자명은 2자 이상 입력해주세요.');
      return;
    }

    if (!_isValidDate8(openedAt)) {
      _showError('개업일자 8자리를 입력해주세요.\n예: 20260501');
      return;
    }

    if (_isFutureDate8(openedAt)) {
      _showError('개업일자는 미래 날짜일 수 없습니다.');
      return;
    }

    if (!agreed) {
      _showError('사업자 정보 조회 동의가 필요합니다.');
      return;
    }

    try {
      await auth.verifyBusiness(
        businessNumber: businessNumber,
        representativeName: representativeName,
        openedAt: openedAt,
      );

      if (!mounted) return;

      AppToast.show('사업자 인증이 완료되었습니다.', title: '완료');
      Get.back(result: true);
    } catch (_) {
      final message = _businessVerificationErrorMessage(
        auth.errorMessage.value,
      );

      _showError(message);
    }
  }

  String _businessVerificationErrorMessage(String? value) {
    final message = value?.trim() ?? '';

    if (message.isEmpty) {
      return '입력한 사업자 정보를 다시 확인해주세요.';
    }

    if (message.contains('현재 상태에서는 처리') ||
        message.contains('failed-precondition') ||
        message.contains('FAILED_PRECONDITION')) {
      return '입력한 정보와 사업자등록 정보가 일치하지 않습니다.\n사업자등록번호, 대표자명, 개업일자를 확인해주세요.';
    }

    if (message.contains('권한') ||
        message.contains('permission-denied') ||
        message.contains('PERMISSION_DENIED')) {
      return '사업자 인증을 진행할 수 없습니다.\n로그인 상태를 확인한 뒤 다시 시도해주세요.';
    }

    if (message.contains('요청한 정보') ||
        message.contains('찾지 못') ||
        message.contains('not-found') ||
        message.contains('NOT_FOUND')) {
      return '사업자 정보를 확인하지 못했습니다.\n입력한 정보를 다시 확인해주세요.';
    }

    if (message.contains('입력') ||
        message.contains('invalid-argument') ||
        message.contains('INVALID_ARGUMENT')) {
      return '입력한 사업자 정보를 다시 확인해주세요.';
    }

    if (message.contains('네트워크') ||
        message.contains('시간') ||
        message.contains('timeout') ||
        message.contains('deadline-exceeded') ||
        message.contains('DEADLINE_EXCEEDED')) {
      return '인증 요청이 지연되고 있습니다.\n잠시 후 다시 시도해주세요.';
    }

    if (message.contains('처리') || message.contains('문제가 발생')) {
      return '사업자 인증을 완료하지 못했습니다.\n입력한 정보를 다시 확인한 뒤 시도해주세요.';
    }

    return message;
  }

  bool _isRepeatedDigits(String value) {
    final digits = value.trim();

    if (digits.isEmpty) {
      return false;
    }

    final first = digits[0];
    return digits.split('').every((item) => item == first);
  }

  bool _isValidBusinessNumber(String value) {
    final digits = value.trim();

    if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
      return false;
    }

    return true;
  }

  bool _isValidDate8(String value) {
    final digits = value.trim();

    if (!RegExp(r'^\d{8}$').hasMatch(digits)) {
      return false;
    }

    final year = int.tryParse(digits.substring(0, 4));
    final month = int.tryParse(digits.substring(4, 6));
    final day = int.tryParse(digits.substring(6, 8));

    if (year == null || month == null || day == null) {
      return false;
    }

    if (year < 1900 || year > 2100) {
      return false;
    }

    final parsed = DateTime.tryParse(
      '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}',
    );

    if (parsed == null) {
      return false;
    }

    return parsed.year == year && parsed.month == month && parsed.day == day;
  }

  bool _isFutureDate8(String value) {
    final digits = value.trim();

    if (!RegExp(r'^\d{8}$').hasMatch(digits)) {
      return true;
    }

    final parsed = DateTime.tryParse(
      '${digits.substring(0, 4)}-${digits.substring(4, 6)}-${digits.substring(6, 8)}',
    );

    if (parsed == null) {
      return true;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return parsed.isAfter(today);
  }

  Widget _buildErrorBox() {
    final message = errorText;

    if (message == null || message.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
      decoration: BoxDecoration(
        color: _kErrorBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kErrorBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: _kErrorIcon,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.8,
                fontWeight: FontWeight.w700,
                color: _kErrorText,
                height: 1.38,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool digitsOnly = false,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      maxLength: maxLength,
      inputFormatters: digitsOnly
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ]
          : null,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        counterText: '',
        filled: true,
        fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
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
        disabledBorder: OutlineInputBorder(
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

  Widget _buildAgreementBox({
    required bool enabled,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled
          ? () {
              setState(() {
                agreed = !agreed;
              });
            }
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: enabled ? Colors.white : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: agreed ? _kPrimary : _kBorder,
            width: agreed ? 1.2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              agreed
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: enabled
                  ? agreed
                      ? _kPrimary
                      : _kTextSoft
                  : const Color(0xFFC0B8B2),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '사업자 정보 조회에 동의합니다.',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _kTextStrong,
                  height: 1.4,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton({
    required bool enabled,
    required bool alreadyVerified,
  }) {
    return Obx(() {
      final loading = auth.isVerifyingBusiness.value;

      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: enabled && !loading && !alreadyVerified ? _submit : null,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: _kPrimary,
            disabledBackgroundColor: alreadyVerified
                ? _kSuccessBorder
                : const Color(0xFFD8CDC8),
            foregroundColor: Colors.white,
            disabledForegroundColor: alreadyVerified
                ? _kSuccessText
                : Colors.white.withValues(alpha: 0.8),
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
              : Text(
                  alreadyVerified ? '인증 완료' : '인증하기',
                  style: const TextStyle(
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
    return Obx(() {
      final user = auth.currentUser.value;
      final loggedIn = user != null;
      final profileReady = !(user?.needsProfileSetup ?? true);
      final businessVerified = user?.isBusinessVerified ?? false;
      final formEnabled = loggedIn && profileReady && !businessVerified;

      return Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          title: const Text(
            '사업자 인증',
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
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 28),
            physics: const ClampingScrollPhysics(),
            children: [
              _buildTextField(
                controller: businessNumberController,
                label: '사업자등록번호',
                hint: '숫자 10자리',
                keyboardType: TextInputType.number,
                maxLength: 10,
                digitsOnly: true,
                enabled: formEnabled,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: representativeNameController,
                label: '대표자명',
                hint: '사업자등록증의 이름',
                maxLength: 20,
                enabled: formEnabled,
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: openedAtController,
                label: '개업일자',
                hint: '예: 20260501',
                keyboardType: TextInputType.number,
                maxLength: 8,
                digitsOnly: true,
                enabled: formEnabled,
              ),
              if (errorText != null) ...[
                const SizedBox(height: 10),
                _buildErrorBox(),
              ],
              const SizedBox(height: 16),
              _buildAgreementBox(enabled: formEnabled),
              const SizedBox(height: 22),
              _buildSubmitButton(
                enabled: formEnabled,
                alreadyVerified: businessVerified,
              ),
            ],
          ),
        ),
      );
    });
  }
}