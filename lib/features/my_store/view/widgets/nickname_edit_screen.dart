import 'package:flutter/material.dart';

class NicknameEditScreen extends StatefulWidget {
  final String initialValue;
  final Future<void> Function(String nickname) onSave;

  const NicknameEditScreen({
    super.key,
    required this.initialValue,
    required this.onSave,
  });

  @override
  State<NicknameEditScreen> createState() => _NicknameEditScreenState();
}

class _NicknameEditScreenState extends State<NicknameEditScreen> {
  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kTextStrong = Color(0xFF111111);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF9CA3AF);
  static const Color _kBorder = Color(0xFFE5E7EB);
  static const Color _kError = Color(0xFFE11D48);

  static const int _nicknameMinLength = 2;
  static const int _nicknameMaxLength = 10;

  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: _normalizeNickname(widget.initialValue),
    );

    _focusNode = FocusNode();

    // 중요:
    // 기존에는 진입 직후 requestFocus()로 키보드를 강제로 올렸다.
    // 화면 push 애니메이션 + 키보드 애니메이션 + resize가 겹치면서
    // 닉네임 변경 화면 진입 시 버벅임이 발생할 수 있어 자동 포커스를 제거한다.
    //
    // 사용자가 직접 입력칸을 눌렀을 때만 키보드가 올라오게 한다.
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving) return;

    final normalized = _normalizeNickname(_controller.text);
    final validationMessage = _validateNickname(normalized);

    if (validationMessage != null) {
      setState(() {
        _errorText = validationMessage;
      });
      return;
    }

    if (normalized == _normalizeNickname(widget.initialValue)) {
      Navigator.of(context).pop(false);
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      await widget.onSave(normalized);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorText = _friendlyNicknameError(e);
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });
    }
  }

  void _handleBack() {
    if (_isSaving) return;

    FocusScope.of(context).unfocus();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              onPressed: _isSaving ? null : _handleBack,
              icon: Icon(
                Icons.arrow_back,
                color: _isSaving ? _kTextSoft : _kTextStrong,
              ),
            ),
            title: const Text(
              '닉네임 변경',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _kTextStrong,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: false,
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kPrimary,
                        ),
                      )
                    : const Text(
                        '저장',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: _kPrimary,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                const Text(
                  '새 닉네임',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _kTextStrong,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_isSaving,
                  maxLength: _nicknameMaxLength,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) {
                    if (_errorText == null) return;
                    setState(() {
                      _errorText = null;
                    });
                  },
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '닉네임을 입력하세요',
                    hintStyle: const TextStyle(
                      color: _kTextSoft,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _errorText == null ? _kBorder : _kError,
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _errorText == null ? _kPrimary : _kError,
                        width: 1.4,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _kBorder,
                        width: 1,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: _kTextStrong,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 20),
                  child: _errorText == null
                      ? const Text(
                          '최대 10자',
                          style: TextStyle(
                            fontSize: 12,
                            color: _kTextSoft,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      : Text(
                          _errorText!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _kError,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                ),
                if (_isSaving) ...[
                  const SizedBox(height: 14),
                  const Row(
                    children: [
                      SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _kPrimary,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        '닉네임을 확인하고 있어요.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _kTextNormal,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _normalizeNickname(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '');
  }

  String? _validateNickname(String value) {
    if (value.isEmpty) {
      return '닉네임을 입력해주세요.';
    }

    if (value.length < _nicknameMinLength) {
      return '닉네임은 $_nicknameMinLength자 이상으로 입력해주세요.';
    }

    if (value.length > _nicknameMaxLength) {
      return '닉네임은 $_nicknameMaxLength자 이하로 입력해주세요.';
    }

    if (!RegExp(r'^[가-힣a-zA-Z0-9_]+$').hasMatch(value)) {
      return '닉네임은 한글, 영문, 숫자, 밑줄(_)만 사용할 수 있어요.';
    }

    return null;
  }

  String _friendlyNicknameError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('이미 사용 중인 닉네임') ||
        raw.contains('already-exists') ||
        raw.contains('nickname already exists') ||
        raw.contains('already exists') ||
        raw.contains('duplicate')) {
      return '이미 사용 중인 닉네임입니다.';
    }

    if (raw.contains('사용할 수 없는 닉네임') ||
        raw.contains('nickname is reserved') ||
        raw.contains('reserved')) {
      return '사용할 수 없는 닉네임입니다.';
    }

    if (raw.contains('사용할 수 없는 표현') ||
        raw.contains('blocked words') ||
        raw.contains('contains blocked') ||
        raw.contains('blocked')) {
      return '사용할 수 없는 표현이 포함된 닉네임입니다.';
    }

    if (raw.contains('nickname format is invalid')) {
      return '닉네임은 한글, 영문, 숫자, 밑줄(_)만 사용할 수 있어요.';
    }

    if (raw.contains('nickname is required')) {
      return '닉네임을 입력해주세요.';
    }

    if (raw.contains('nickname must be at least')) {
      return '닉네임은 $_nicknameMinLength자 이상으로 입력해주세요.';
    }

    if (raw.contains('nickname must be $_nicknameMaxLength') ||
        raw.contains(
          'nickname must be $_nicknameMaxLength characters or less',
        )) {
      return '닉네임은 $_nicknameMaxLength자 이하로 입력해주세요.';
    }

    if (raw.contains('unauthenticated') || raw.contains('로그인이 필요')) {
      return '로그인이 필요합니다.';
    }

    if (raw.contains('permission-denied')) {
      return '계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.';
    }

    if (raw.contains('unavailable') ||
        raw.contains('deadline-exceeded') ||
        raw.contains('timeout') ||
        raw.contains('network')) {
      return '서버 연결이 불안정합니다. 잠시 후 다시 시도해주세요.';
    }

    return '닉네임을 변경하지 못했습니다. 잠시 후 다시 시도해주세요.';
  }
}