import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/ui/app_toast.dart';
import 'package:yupgagae/features/community/controller/comment_controller.dart';

class CommentWriteScreen extends StatefulWidget {
  const CommentWriteScreen({super.key});

  @override
  State<CommentWriteScreen> createState() => _CommentWriteScreenState();
}

class _CommentWriteScreenState extends State<CommentWriteScreen> {
  late final CommentController commentC;

  final TextEditingController _textC = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  late final String _postId;
  late final String? _parentCommentId;
  late final String? _editingCommentId;
  late final String? _initialText;

  String get _commentTag => 'comment:$_postId';

  bool get _isEditMode => _editingCommentId != null;
  bool get _isReplyMode => _parentCommentId != null && !_isEditMode;

  @override
  void initState() {
    super.initState();

    final args = (Get.arguments as Map?)?.cast<String, dynamic>() ?? {};

    _postId = (args['postId'] ?? '').toString();
    _parentCommentId = args['parentCommentId']?.toString();
    _editingCommentId = args['editingCommentId']?.toString();
    _initialText = args['initialText']?.toString();

    commentC = Get.find<CommentController>(tag: _commentTag);

    final text = (_initialText ?? '').trim();
    if (text.isNotEmpty) {
      _textC.text = text;
      _textC.selection = TextSelection.fromPosition(
        TextPosition(offset: _textC.text.length),
      );
    }
  }

  @override
  void dispose() {
    _textC.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _titleText {
    if (_isEditMode) return '댓글 수정';
    if (_isReplyMode) return '답글 작성';
    return '댓글 작성';
  }

  String get _hintText {
    if (_isEditMode) return '댓글을 수정하세요';
    if (_isReplyMode) return '답글을 입력하세요';
    return '댓글을 입력하세요';
  }

  Future<void> _submit() async {
    final text = _textC.text.trim();
    if (text.isEmpty) {
      AppToast.show('내용을 입력하세요.', title: '안내');
      return;
    }

    if (commentC.isSubmitting.value) return;

    commentC.isSubmitting.value = true;

    try {
      if (_editingCommentId != null) {
        await commentC.updateComment(
          commentId: _editingCommentId!,
          text: text,
        );
      } else if (_parentCommentId != null) {
        await commentC.reply(
          parentCommentId: _parentCommentId!,
          text: text,
        );
      } else {
        await commentC.add(text);
      }

      if (!mounted) return;
      Get.back(result: true);
    } catch (e) {
      AppToast.show('댓글 처리 실패: $e', title: '실패');
    } finally {
      commentC.isSubmitting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111111)),
          onPressed: () => Get.back(),
        ),
        title: Text(
          _titleText,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          Obx(() {
            final submitting = commentC.isSubmitting.value;
            return TextButton(
              onPressed: submitting ? null : _submit,
              child: Text(
                '완료',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: submitting
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF111111),
                ),
              ),
            );
          }),
        ],
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: _textC,
              focusNode: _focusNode,
              autofocus: true,
              maxLines: null,
              minLines: 8,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: _hintText,
                border: InputBorder.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}