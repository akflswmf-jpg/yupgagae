import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/region_catalog.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class WritePostController extends GetxController {
  static const int maxImages = 3;

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

  final ImagePicker _picker = ImagePicker();

  late BoardType _resolvedBoardType = initialBoardType;

  String get currentUserId => session.anonId;

  bool get isEditMode => editingPostId != null && editingPostId!.isNotEmpty;

  BoardType get boardType => _resolvedBoardType;

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

    isSubmitting.value = false;
    isLoadingEdit.value = false;
    error.value = null;
    _resolvedBoardType = initialBoardType;
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
      final files = await _picker.pickMultiImage(imageQuality: 90);

      if (files.isEmpty) return;

      for (final f in files.take(remain)) {
        imagePaths.add(f.path);
      }
    } catch (_) {
      error.value = '사진을 불러오지 못했어요.';
    }
  }

  void removeImageAt(int index) {
    if (index < 0 || index >= imagePaths.length) return;
    imagePaths.removeAt(index);
  }

  bool _validate() {
    final b = body.value.trim();

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

      if (!isEditMode) {
        final profile = await storeProfileRepo.fetchProfile();

        if (_resolvedBoardType == BoardType.owner && !profile.isOwnerVerified) {
          error.value = '사장님 게시판 글쓰기는 사업자 인증 후 이용할 수 있습니다.';
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
          body: body.value.trim(),
          boardType: _resolvedBoardType,
          industryId: industryId,
          locationLabel: regionLabel,
          imagePaths: imagePaths.toList(growable: false),
        );
      } else {
        await repo.updatePost(
          postId: editingPostId!,
          userId: currentUserId,
          title: resolvedTitle,
          body: body.value.trim(),
          imagePaths: imagePaths.toList(growable: false),
        );
      }

      title.value = resolvedTitle;
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