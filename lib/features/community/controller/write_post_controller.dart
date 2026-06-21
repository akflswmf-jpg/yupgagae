import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
import 'package:yupgagae/core/image/app_image_provider_resolver.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_image_repository.dart';
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
  final PostImageRepository imageRepo;
  final AuthSessionService auth;
  final AuthController authController;
  final StoreProfileRepository storeProfileRepo;

  final String? editingPostId;
  final BoardType initialBoardType;

  WritePostController({
    required this.repo,
    required this.imageRepo,
    required this.auth,
    required this.authController,
    required this.storeProfileRepo,
    this.editingPostId,
    this.initialBoardType = BoardType.free,
  });

  final title = ''.obs;
  final body = ''.obs;

  /// 작성 중에는 로컬 파일 경로와 기존 서버 URL이 함께 들어올 수 있다.
  ///
  /// - 새로 고른 사진: 압축된 로컬 path
  /// - 수정 화면 기존 사진: Firebase Storage download URL
  ///
  /// 저장 시점에는 PostImageRepository가 로컬 파일만 Storage에 올리고,
  /// 네트워크 URL은 그대로 유지한다.
  final RxList<String> imagePaths = <String>[].obs;

  final isSubmitting = false.obs;
  final isLoadingEdit = false.obs;
  final error = RxnString();

  final selectedUsedType = Rxn<UsedPostType>();

  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  late BoardType _resolvedBoardType = initialBoardType;

  AppUser? get currentUser {
    return authController.currentUser.value;
  }

  String get currentUserId {
    final user = currentUser;
    if (user == null) return '';

    return user.userId.trim();
  }

  bool get isEditMode => editingPostId != null && editingPostId!.isNotEmpty;

  BoardType get boardType => _resolvedBoardType;

  bool get isUsedBoard => _resolvedBoardType == BoardType.used;

  bool get canWriteCurrentBoard {
    return PermissionPolicy.canWritePost(
      user: currentUser,
      boardType: _resolvedBoardType,
    );
  }

  bool get canPickImage {
    if (isEditMode) {
      return PermissionPolicy.canParticipate(currentUser);
    }

    return canWriteCurrentBoard;
  }

  @override
  void onInit() {
    super.onInit();

    error.value = null;

    if (!PermissionPolicy.canParticipate(currentUser)) {
      error.value = PermissionPolicy.participationBlockedMessage(currentUser);
      isSubmitting.value = false;
      isLoadingEdit.value = false;
      return;
    }

    if (isEditMode) {
      _loadForEdit();
    } else {
      _resetForCreate();
    }
  }

  void _resetForCreate() {
    _resolvedBoardType = initialBoardType;
    title.value = '';
    body.value = '';
    selectedUsedType.value = null;
    imagePaths.clear();

    if (_resolvedBoardType == BoardType.used) {
      selectedUsedType.value = UsedPostType.store;
      body.value = _templateFor(selectedUsedType.value);
    }
  }

  void setTitle(String value) {
    title.value = value;
  }

  void setBody(String value) {
    body.value = value;
  }

  void _ensureParticipationAllowed() {
    final user = currentUser;

    if (!PermissionPolicy.canParticipate(user)) {
      throw Exception(PermissionPolicy.participationBlockedMessage(user));
    }
  }

  void _ensureCreatePermissionAllowed() {
    final user = currentUser;

    if (!PermissionPolicy.canWritePost(
      user: user,
      boardType: _resolvedBoardType,
    )) {
      throw Exception(
        PermissionPolicy.writePostBlockedMessage(
          user: user,
          boardType: _resolvedBoardType,
        ),
      );
    }
  }

  bool _canCreateInCurrentBoard() {
    return PermissionPolicy.canWritePost(
      user: currentUser,
      boardType: _resolvedBoardType,
    );
  }

  String _permissionDeniedMessage() {
    return PermissionPolicy.writePostBlockedMessage(
      user: currentUser,
      boardType: _resolvedBoardType,
    );
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
    final shouldSwapTemplate = before.isEmpty || _isKnownUsedTemplate(before);

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
    return '${singleLine.substring(0, 26)}.';
  }

  Future<void> _loadForEdit() async {
    if (!isEditMode) return;

    if (!PermissionPolicy.canParticipate(currentUser)) {
      error.value = PermissionPolicy.participationBlockedMessage(currentUser);
      return;
    }

    isLoadingEdit.value = true;
    error.value = null;

    try {
      final post = await repo.getPostById(editingPostId!);
      final userId = currentUserId;

      if (userId.isEmpty || post.authorId != userId) {
        error.value = '작성자만 수정할 수 있습니다.';
        return;
      }

      if (post.isDeleted || post.isHiddenFromPublic) {
        error.value = '수정할 수 없는 게시글입니다.';
        return;
      }

      _resolvedBoardType = post.boardType;
      title.value = post.title;
      body.value = post.body;
      selectedUsedType.value = post.usedType;

      imagePaths
        ..clear()
        ..addAll(post.imageUrls.take(maxImages));
    } catch (_) {
      error.value = '게시글을 불러오지 못했어요.';
    } finally {
      isLoadingEdit.value = false;
    }
  }

  Future<void> pickImages() async {
    error.value = null;

    try {
      _ensureParticipationAllowed();

      if (!isEditMode) {
        _ensureCreatePermissionAllowed();
      }
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      return;
    }

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
    final source = originalPath.trim();

    if (source.isEmpty) return null;
    if (AppImageProviderResolver.isNetworkSource(source)) return source;

    final originalFile = File(source);
    if (!await originalFile.exists()) return null;

    final tempDir = await getTemporaryDirectory();
    final targetPath =
        '${tempDir.path}/post_${DateTime.now().microsecondsSinceEpoch}.jpg';

    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        source,
        targetPath,
        quality: _uploadQuality,
        minWidth: _uploadLongSide,
        minHeight: _uploadLongSide,
        format: CompressFormat.jpeg,
        keepExif: false,
      );

      if (compressed == null) {
        return source;
      }

      final compressedFile = File(compressed.path);
      if (!await compressedFile.exists()) {
        return source;
      }

      final originalLength = await originalFile.length();
      final compressedLength = await compressedFile.length();

      if (compressedLength >= originalLength) {
        return source;
      }

      return compressed.path;
    } catch (_) {
      return source;
    }
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= imagePaths.length) return;
    imagePaths.removeAt(index);
  }

  bool _validate() {
    final manualTitle = title.value.trim();
    final resolvedBody = body.value.trim();

    if (manualTitle.length > maxTitleLength) {
      error.value = '제목은 $maxTitleLength자 이내로 입력해주세요.';
      return false;
    }

    if (resolvedBody.isEmpty) {
      error.value = '내용을 입력해주세요.';
      return false;
    }

    if (resolvedBody.length > maxBodyLength) {
      error.value = '내용은 $maxBodyLength자 이내로 입력해주세요.';
      return false;
    }

    if (imagePaths.length > maxImages) {
      error.value = '사진은 최대 $maxImages장까지 첨부할 수 있습니다.';
      return false;
    }

    if (_resolvedBoardType == BoardType.used && selectedUsedType.value == null) {
      error.value = '거래 유형을 선택해주세요.';
      return false;
    }

    return true;
  }

  Future<bool> submit() async {
    if (isSubmitting.value) return false;

    error.value = null;

    try {
      _ensureParticipationAllowed();

      if (!isEditMode) {
        _ensureCreatePermissionAllowed();
      }
    } catch (e) {
      error.value = e.toString().replaceFirst('Exception: ', '');
      return false;
    }

    if (!_validate()) {
      return false;
    }

    isSubmitting.value = true;

    final resolvedTitle = _resolvedTitle();
    final resolvedBody = body.value.trim();
    final userId = currentUserId;

    if (userId.isEmpty) {
      error.value = '로그인이 필요한 기능입니다.';
      isSubmitting.value = false;
      return false;
    }

    try {
      if (!isEditMode) {
        if (!_canCreateInCurrentBoard()) {
          error.value = _permissionDeniedMessage();
          return false;
        }

        final profile = await storeProfileRepo.fetchProfile();
        final industryId = _industryIdFromProfile(profile);
        final regionLabel = RegionCatalog.normalize(profile.region);

        final postId = _uuid.v4();

        final uploaded = await imageRepo.uploadPostImages(
          postId: postId,
          authorId: userId,
          localImagePaths: imagePaths.toList(growable: false),
        );

        try {
          await repo.createPost(
            postId: postId,
            title: resolvedTitle,
            body: resolvedBody,
            boardType: _resolvedBoardType,
            usedType: _resolvedBoardType == BoardType.used
                ? selectedUsedType.value
                : null,
            industryId: industryId,
            locationLabel: regionLabel,
            imageUrls: uploaded.imageUrls,
          );
        } catch (_) {
          await imageRepo.deletePostImages(
            imageUrls: uploaded.imageUrls,
          );
          rethrow;
        }

        imagePaths
          ..clear()
          ..addAll(uploaded.imageUrls);
      } else {
        final targetPostId = editingPostId!.trim();

        final post = await repo.getPostById(targetPostId);

        if (userId.isEmpty || post.authorId != userId) {
          error.value = '작성자만 수정할 수 있습니다.';
          return false;
        }

        if (post.isDeleted || post.isHiddenFromPublic) {
          error.value = '수정할 수 없는 게시글입니다.';
          return false;
        }

        final beforeImageUrls = post.imageUrls;

        final uploaded = await imageRepo.uploadPostImages(
          postId: targetPostId,
          authorId: userId,
          localImagePaths: imagePaths.toList(growable: false),
        );

        await repo.updatePost(
          postId: targetPostId,
          title: resolvedTitle,
          body: resolvedBody,
          usedType: _resolvedBoardType == BoardType.used
              ? selectedUsedType.value
              : null,
          imageUrls: uploaded.imageUrls,
        );

        final nextUrlSet = uploaded.imageUrls.toSet();
        final removedUrls = beforeImageUrls
            .where((url) => !nextUrlSet.contains(url))
            .toList(growable: false);

        await imageRepo.deletePostImages(
          imageUrls: removedUrls,
        );

        imagePaths
          ..clear()
          ..addAll(uploaded.imageUrls);
      }

      title.value = resolvedTitle;
      body.value = resolvedBody;
      error.value = null;
      return true;
    } catch (e) {
      final message = e.toString();

      if (message.contains('로그인이 필요한 기능입니다')) {
        error.value = '로그인이 필요한 기능입니다.';
        return false;
      }

      if (message.contains('본인 인증') ||
          message.contains('사업자 인증') ||
          message.contains('정지된 계정') ||
          message.contains('탈퇴 처리된 계정') ||
          message.contains('가입 설정')) {
        error.value = message.replaceFirst('Exception: ', '');
        return false;
      }

      if (message.contains('사진')) {
        error.value = message.replaceFirst('Exception: ', '');
        return false;
      }

      error.value = isEditMode
          ? '수정에 실패했어요. 잠시 후 다시 시도해주세요.'
          : '등록에 실패했어요. 잠시 후 다시 시도해주세요.';
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }
}