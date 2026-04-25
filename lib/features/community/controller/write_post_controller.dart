import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/domain/region_catalog.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class WritePostController extends GetxController {
  static const int maxTitleLength = 40;
  static const int maxBodyLength = 1000;
  static const int maxImages = 5;

  static const int _uploadLongSide = 1600;
  static const int _uploadQuality = 84;

  final PostRepository repo;
  final AnonSessionService session;
  final StoreProfileRepository storeProfileRepo;

  final String? editingPostId;
  final BoardType initialBoardType;

  WritePostController({
    required this.repo,
    required this.session,
    required this.storeProfileRepo,
    this.editingPostId,
    this.initialBoardType = BoardType.free,
  });

  final title = ''.obs;
  final body = ''.obs;
  final RxList<String> imagePaths = <String>[].obs;

  final isSubmitting = false.obs;
  final isLoadingEdit = false.obs;
  final error = RxnString();

  final selectedUsedType = Rxn<UsedPostType>();

  final ImagePicker _picker = ImagePicker();

  late BoardType _resolvedBoardType = initialBoardType;

  String get currentUserId => session.anonId;

  bool get isEditMode => editingPostId != null && editingPostId!.isNotEmpty;

  BoardType get boardType => _resolvedBoardType;
  bool get isUsedBoard => _resolvedBoardType == BoardType.used;

  @override
  void onInit() {
    super.onInit();

    error.value = null;

    if (isEditMode) {
      _loadForEdit();
    } else {
      _resetForCreate();
    }
  }

  void _resetForCreate() {
    title.value = '';
    body.value = '';
    imagePaths.clear();
    selectedUsedType.value = isUsedBoard ? UsedPostType.store : null;

    if (isUsedBoard && body.value.trim().isEmpty) {
      body.value = _templateFor(selectedUsedType.value);
    }

    isSubmitting.value = false;
    isLoadingEdit.value = false;
    error.value = null;
    _resolvedBoardType = initialBoardType;
  }

  void setTitle(String value) {
    final next = value.replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (next.length <= maxTitleLength) {
      title.value = next;
      return;
    }

    title.value = next.substring(0, maxTitleLength);
  }

  void setBody(String value) {
    if (value.length <= maxBodyLength) {
      body.value = value;
      return;
    }

    body.value = value.substring(0, maxBodyLength);
  }

  String _templateFor(UsedPostType? type) {
    switch (type) {
      case UsedPostType.store:
        return '''
[가게양도]

업종:
지역:
보증금 / 권리금:
월세:
양도 사유:
양도 가능 시기:
추가 설명:
''';
      case UsedPostType.item:
        return '''
[중고거래]

품목명:
사용 기간:
희망 가격:
거래 지역:
거래 방식:
제품 상태:
추가 설명:
''';
      case null:
        return '';
    }
  }

  bool _isKnownUsedTemplate(String text) {
    final normalized = text.trim();
    if (normalized.isEmpty) return false;

    return normalized == _templateFor(UsedPostType.store).trim() ||
        normalized == _templateFor(UsedPostType.item).trim();
  }

  void setUsedType(UsedPostType? type) {
    if (!isUsedBoard) return;

    final before = body.value.trim();
    final shouldSwapTemplate =
        before.isEmpty || _isKnownUsedTemplate(before);

    selectedUsedType.value = type;

    if (shouldSwapTemplate) {
      body.value = _templateFor(type);
    }
  }

  void applyUsedTemplate({bool force = true}) {
    if (!isUsedBoard) return;

    final template = _templateFor(selectedUsedType.value);
    if (template.trim().isEmpty) return;

    final current = body.value.trim();
    if (!force && current.isNotEmpty) return;

    body.value = template;
  }

  String? _industryIdFromProfile(StoreProfile profile) {
    final raw = profile.industry.trim();
    if (raw.isEmpty) return null;

    for (final item in IndustryCatalog.ordered()) {
      if (item.id.trim() == raw) {
        return item.id;
      }
    }

    final normalizedRaw = raw.toLowerCase().replaceAll(' ', '');

    for (final item in IndustryCatalog.ordered()) {
      final normalizedName = item.name.toLowerCase().replaceAll(' ', '');
      if (normalizedName == normalizedRaw) {
        return item.id;
      }
    }

    for (final item in IndustryCatalog.ordered()) {
      if (item.name.trim() == raw) {
        return item.id;
      }
    }

    return null;
  }

  String _resolvedTitle() {
    final manual = title.value.trim();
    if (manual.isNotEmpty) return manual;

    final content = body.value.trim();
    if (content.isEmpty) return '제목 없음';

    final singleLine =
        content.replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.isEmpty) return '제목 없음';

    if (singleLine.length <= 26) return singleLine;
    return '${singleLine.substring(0, 26)}...';
  }

  Future<void> _loadForEdit() async {
    if (!isEditMode) return;

    isLoadingEdit.value = true;
    error.value = null;

    try {
      final post = await repo.getPostById(editingPostId!);

      if (post.authorId != currentUserId) {
        error.value = '작성자만 수정할 수 있습니다.';
        return;
      }

      _resolvedBoardType = post.boardType;
      title.value = post.title;
      body.value = post.body;
      selectedUsedType.value = post.usedType;

      imagePaths
        ..clear()
        ..addAll(post.imagePaths.take(maxImages));
    } catch (_) {
      error.value = '게시글을 불러오지 못했어요.';
    } finally {
      isLoadingEdit.value = false;
    }
  }

  Future<void> pickImages() async {
    error.value = null;

    if (imagePaths.length >= maxImages) return;

    try {
      final remain = maxImages - imagePaths.length;
      final files = await _picker.pickMultiImage();

      if (files.isEmpty) return;

      final compressedPaths = await _compressPickedImages(
        pickedFiles: files,
        remain: remain,
      );

      if (compressedPaths.isEmpty) {
        error.value = '사진을 처리하지 못했어요.';
        return;
      }

      imagePaths.addAll(compressedPaths);
    } catch (_) {
      error.value = '사진을 불러오지 못했어요.';
    }
  }

  Future<List<String>> _compressPickedImages({
    required List<XFile> pickedFiles,
    required int remain,
  }) async {
    final out = <String>[];
    final filesToUse = pickedFiles.take(remain);

    for (final picked in filesToUse) {
      final compressedPath = await _compressSingleImage(picked.path);
      if (compressedPath != null && compressedPath.trim().isNotEmpty) {
        out.add(compressedPath);
      }
    }

    return out;
  }

  Future<String?> _compressSingleImage(String originalPath) async {
    final originalFile = File(originalPath);
    if (!await originalFile.exists()) return null;

    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/post_${DateTime.now().microsecondsSinceEpoch}.jpg';

    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        originalPath,
        targetPath,
        quality: _uploadQuality,
        minWidth: _uploadLongSide,
        minHeight: _uploadLongSide,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (compressed == null) {
        return originalPath;
      }

      final compressedFile = File(compressed.path);
      if (!await compressedFile.exists()) {
        return originalPath;
      }

      final originalLength = await originalFile.length();
      final compressedLength = await compressedFile.length();

      if (compressedLength >= originalLength) {
        return originalPath;
      }

      return compressed.path;
    } catch (_) {
      return originalPath;
    }
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= imagePaths.length) return;
    imagePaths.removeAt(index);
  }

  bool _validate() {
    final manualTitle = title.value.trim();
    final b = body.value.trim();

    if (manualTitle.length > maxTitleLength) {
      error.value = '제목은 $maxTitleLength자 이내로 입력해주세요.';
      return false;
    }

    if (b.length > maxBodyLength) {
      error.value = '내용은 $maxBodyLength자 이내로 입력해주세요.';
      return false;
    }

    if (isUsedBoard && selectedUsedType.value == null) {
      error.value = '가게양도 또는 중고거래를 선택해주세요.';
      return false;
    }

    if (b.isEmpty) {
      error.value = '내용을 입력해주세요.';
      return false;
    }

    error.value = null;
    return true;
  }

  Future<bool> submit() async {
    if (isSubmitting.value) return false;
    if (isLoadingEdit.value) return false;
    if (!_validate()) return false;

    isSubmitting.value = true;

    try {
      final resolvedTitle = _resolvedTitle();
      final resolvedBody = body.value.trim();

      if (resolvedTitle.length > maxTitleLength) {
        error.value = '제목은 $maxTitleLength자 이내로 입력해주세요.';
        return false;
      }

      if (resolvedBody.length > maxBodyLength) {
        error.value = '내용은 $maxBodyLength자 이내로 입력해주세요.';
        return false;
      }

      if (!isEditMode) {
        final profile = await storeProfileRepo.fetchProfile();

        if ((_resolvedBoardType == BoardType.owner ||
                _resolvedBoardType == BoardType.used) &&
            !profile.isOwnerVerified) {
          error.value = _resolvedBoardType == BoardType.owner
              ? '사장님 게시판 글쓰기는 사업자 인증 후 이용할 수 있습니다.'
              : '거래게시판 글쓰기는 사업자 인증 후 이용할 수 있습니다.';
          return false;
        }

        final authorLabel =
            profile.nickname.trim().isEmpty ? '익명' : profile.nickname.trim();

        final industryId = _industryIdFromProfile(profile);
        final regionLabel = RegionCatalog.normalize(profile.region);

        await repo.createPost(
          authorId: currentUserId,
          authorLabel: authorLabel,
          isOwnerVerified: profile.isOwnerVerified,
          title: resolvedTitle,
          body: resolvedBody,
          boardType: _resolvedBoardType,
          usedType: _resolvedBoardType == BoardType.used
              ? selectedUsedType.value
              : null,
          industryId: industryId,
          locationLabel: regionLabel,
          imagePaths: imagePaths.toList(growable: false),
        );
      } else {
        await repo.updatePost(
          postId: editingPostId!,
          userId: currentUserId,
          title: resolvedTitle,
          body: resolvedBody,
          usedType: _resolvedBoardType == BoardType.used
              ? selectedUsedType.value
              : null,
          imagePaths: imagePaths.toList(growable: false),
        );
      }

      title.value = resolvedTitle;
      body.value = resolvedBody;
      error.value = null;
      return true;
    } catch (_) {
      error.value = isEditMode
          ? '수정에 실패했어요. 잠시 후 다시 시도해주세요.'
          : '등록에 실패했어요. 잠시 후 다시 시도해주세요.';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}