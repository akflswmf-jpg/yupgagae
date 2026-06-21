import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/image/app_image_provider_resolver.dart';
import 'package:yupgagae/core/navigation/route_input_resolver.dart';
import 'package:yupgagae/core/ui/app_messenger.dart';
import 'package:yupgagae/features/community/controller/write_post_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/widgets/post_compose_text_formatter.dart';

const Color kWriteAccent = Color(0xFFA56E5F);
const Color kWriteAccentDark = Color(0xFF875646);
const Color kWriteAccentSoft = Color(0xFFF5ECE8);

const TextStyle _kWriteHintStyle = TextStyle(
  fontSize: 15,
  height: 1.7,
  color: Color(0xFF9CA3AF),
  fontWeight: FontWeight.w500,
);

const TextStyle _kWriteInputStyle = TextStyle(
  fontSize: 15,
  height: 1.7,
  color: Color(0xFF111111),
  fontWeight: FontWeight.w500,
);

class WritePostScreen extends StatefulWidget {
  const WritePostScreen({super.key});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  late final WritePostController c;
  late final TextEditingController titleCtrl;
  late final TextEditingController bodyCtrl;

  bool _didApplyEditText = false;

  late final Worker _editWorker;
  late final Worker _titleWorker;
  late final Worker _bodyWorker;

  late final List<TextInputFormatter> _titleInputFormatters = [
    LengthLimitingTextInputFormatter(WritePostController.maxTitleLength),
  ];

  late final List<TextInputFormatter> _bodyInputFormatters = [
    const PostComposeTextFormatter(),
    LengthLimitingTextInputFormatter(WritePostController.maxBodyLength),
  ];

  @override
  void initState() {
    super.initState();

    final rawPostId = RouteInputResolver.string('postId');
    final postId =
        (rawPostId == null || rawPostId.trim().isEmpty) ? null : rawPostId.trim();

    final rawBoardType = RouteInputResolver.string('boardType');
    final boardType = boardTypeFromKey(rawBoardType);

    final tag = postId == null ? 'create:${boardType.key}' : 'edit:$postId';

    c = Get.find<WritePostController>(tag: tag);

    titleCtrl = TextEditingController();
    bodyCtrl = TextEditingController();

    titleCtrl.text = c.title.value == '제목 없음' ? '' : c.title.value;
    bodyCtrl.text = c.body.value;

    _titleWorker = ever<String>(c.title, (value) {
      final next = value == '제목 없음' ? '' : value;
      if (titleCtrl.text == next) return;

      titleCtrl.value = titleCtrl.value.copyWith(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
        composing: TextRange.empty,
      );
    });

    _bodyWorker = ever<String>(c.body, (value) {
      if (bodyCtrl.text == value) return;

      bodyCtrl.value = bodyCtrl.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.closeAllSnackbars();
      AppMessenger.clearAll();
      WidgetsBinding.instance.addPostFrameCallback((__) {
        AppMessenger.clearAll();
      });
    });

    _editWorker = ever<bool>(c.isLoadingEdit, (loading) {
      if (!c.isEditMode) return;
      if (loading) return;
      if (_didApplyEditText) return;

      _didApplyEditText = true;

      final nextTitle = c.title.value == '제목 없음' ? '' : c.title.value;
      final nextBody = c.body.value;

      titleCtrl.value = titleCtrl.value.copyWith(
        text: nextTitle,
        selection: TextSelection.collapsed(offset: nextTitle.length),
        composing: TextRange.empty,
      );
      bodyCtrl.value = bodyCtrl.value.copyWith(
        text: nextBody,
        selection: TextSelection.collapsed(offset: nextBody.length),
        composing: TextRange.empty,
      );
    });
  }

  @override
  void dispose() {
    _editWorker.dispose();
    _titleWorker.dispose();
    _bodyWorker.dispose();
    titleCtrl.dispose();
    bodyCtrl.dispose();
    super.dispose();
  }

  String _screenTitle() {
    if (c.isEditMode) return '글 수정';

    switch (c.boardType) {
      case BoardType.owner:
        return '사장님 글쓰기';
      case BoardType.used:
        return '거래게시판 글쓰기';
      case BoardType.free:
        return '자유 글쓰기';
    }
  }

  String _bodyHint() {
    switch (c.boardType) {
      case BoardType.owner:
        return '가게 운영 이야기, 고민, 팁을 편하게 공유하세요';
      case BoardType.used:
        return '양식을 넣어서 빠르게 작성하거나 자유롭게 적어주세요';
      case BoardType.free:
        return '동네 이야기, 질문, 정보 등을 편하게 공유하세요';
    }
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 80));

    final ok = await c.submit();
    if (ok) {
      Get.back(result: true);
    }
  }

  String _usedTypeLabel(UsedPostType type) {
    switch (type) {
      case UsedPostType.store:
        return '가게양도';
      case UsedPostType.item:
        return '중고거래';
    }
  }

  String _usedTemplateGuide(UsedPostType? type) {
    switch (type) {
      case UsedPostType.store:
        return '업종, 지역, 보증금/권리금, 월세 등의 양식입니다.';
      case UsedPostType.item:
        return '품목명, 사용 기간, 희망 가격, 거래 지역 등의 양식입니다.';
      case null:
        return '거래 유형을 먼저 선택해주세요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bodyHint = _bodyHint();
    final screenTitle = _screenTitle();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(screenTitle),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          Obx(() {
            final disabled = c.isSubmitting.value || c.isLoadingEdit.value;
            final text = c.isEditMode ? '완료' : '등록';

            return TextButton(
              onPressed: disabled ? null : _submit,
              style: TextButton.styleFrom(
                foregroundColor: kWriteAccentDark,
              ),
              child: Text(
                text,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                ),
              ),
            );
          }),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF3F4F6),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            Obx(() {
              if (!c.isLoadingEdit.value) return const SizedBox.shrink();

              return const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _InfoBanner(
                  text: '게시글을 불러오는 중입니다.',
                  icon: Icons.hourglass_top,
                ),
              );
            }),
            Obx(() {
              final msg = c.error.value?.trim();
              if (msg == null || msg.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ErrorBanner(text: msg),
              );
            }),
            if (c.boardType == BoardType.used) ...[
              const _SectionLabel(label: '거래 유형'),
              const SizedBox(height: 10),
              Obx(() {
                final selected = c.selectedUsedType.value;

                return Row(
                  children: UsedPostType.values.map((type) {
                    final isSelected = selected == type;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: type == UsedPostType.store ? 8 : 0,
                          left: type == UsedPostType.item ? 8 : 0,
                        ),
                        child: _UsedTypeChoiceCard(
                          label: _usedTypeLabel(type),
                          selected: isSelected,
                          onTap: () => c.setUsedType(type),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 10),
              Obx(() {
                final selected = c.selectedUsedType.value;

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _usedTemplateGuide(selected),
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          onPressed: selected == null
                              ? null
                              : () => c.applyUsedTemplate(force: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kWriteAccentDark,
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            '양식 넣기',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 18),
            ],
            _UnderlineInputSection(
              child: TextField(
                controller: titleCtrl,
                inputFormatters: _titleInputFormatters,
                maxLength: WritePostController.maxTitleLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                textInputAction: TextInputAction.next,
                maxLines: 1,
                onChanged: c.setTitle,
                decoration: const InputDecoration(
                  hintText: '제목을 입력하세요',
                  hintStyle: _kWriteHintStyle,
                  counterStyle: TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  fillColor: Colors.transparent,
                  filled: false,
                ),
                style: _kWriteInputStyle,
              ),
            ),
            const SizedBox(height: 16),
            _UnderlineInputSection(
              child: TextField(
                controller: bodyCtrl,
                inputFormatters: _bodyInputFormatters,
                maxLength: WritePostController.maxBodyLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                maxLines: null,
                minLines: 14,
                textAlignVertical: TextAlignVertical.top,
                onChanged: c.setBody,
                decoration: InputDecoration(
                  hintText: bodyHint,
                  hintStyle: _kWriteHintStyle,
                  counterStyle: const TextStyle(
                    fontSize: 11,
                    height: 1.2,
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w600,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                  fillColor: Colors.transparent,
                  filled: false,
                ),
                style: _kWriteInputStyle,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              c.boardType == BoardType.used
                  ? '허위 매물·사기 의심·과도한 광고글은 제재될 수 있습니다.'
                  : '비방·허위정보·과도한 광고글은 제재될 수 있습니다.',
              style: const TextStyle(
                fontSize: 11.8,
                height: 1.35,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                const Text(
                  '사진',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const Spacer(),
                Obx(() {
                  final canAdd =
                      c.imagePaths.length < WritePostController.maxImages;

                  return TextButton.icon(
                    onPressed: canAdd ? c.pickImages : null,
                    style: TextButton.styleFrom(
                      foregroundColor: kWriteAccentDark,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                    label: Text(
                      '${c.imagePaths.length}/${WritePostController.maxImages}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  );
                }),
              ],
            ),
            const SizedBox(height: 6),
            Obx(() {
              if (c.imagePaths.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      '첨부된 사진이 없습니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: c.imagePaths.length,
                  separatorBuilder: (_, __) => const Padding(
                    padding: EdgeInsets.only(left: 88),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F3F5),
                    ),
                  ),
                  itemBuilder: (_, i) {
                    final path = c.imagePaths[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 12,
                      ),
                      child: _ImagePreviewRow(
                        path: path,
                        indexLabel: '${i + 1}',
                        onRemove: () => c.removeImageAt(i),
                      ),
                    );
                  },
                ),
              );
            }),
            const SizedBox(height: 28),
            Obx(() {
              final disabled = c.isSubmitting.value || c.isLoadingEdit.value;
              final text = disabled
                  ? (c.isEditMode ? '수정 중...' : '등록 중...')
                  : (c.isEditMode ? '수정하기' : '등록하기');

              return SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: disabled ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: kWriteAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                    disabledForegroundColor: const Color(0xFF9CA3AF),
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _UsedTypeChoiceCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _UsedTypeChoiceCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? kWriteAccentSoft : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? kWriteAccent : const Color(0xFFE5E7EB),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? kWriteAccentDark : const Color(0xFF374151),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnderlineInputSection extends StatelessWidget {
  final Widget child;

  const _UnderlineInputSection({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
      ),
      child: child,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;
  final IconData icon;

  const _InfoBanner({
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: const Color(0xFF6B7280)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String text;

  const _ErrorBanner({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            size: 16,
            color: Color(0xFFD92D20),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImagePreviewRow extends StatelessWidget {
  final String path;
  final String indexLabel;
  final VoidCallback onRemove;

  const _ImagePreviewRow({
    required this.path,
    required this.indexLabel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final provider = AppImageProviderResolver.resolve(
      path,
      resizeWidth: 320,
    );

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: provider == null
                ? const _ImageFallback()
                : Image(
                    image: provider,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const _ImageFallback();
                    },
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            '사진 $indexLabel',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kWriteAccentSoft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: kWriteAccent.withOpacity(0.25),
                ),
              ),
              child: const Icon(
                Icons.close,
                size: 18,
                color: kWriteAccentDark,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}