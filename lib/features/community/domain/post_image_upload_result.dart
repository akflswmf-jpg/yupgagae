class PostImageUploadResult {
  final List<String> imageUrls;

  const PostImageUploadResult({
    required this.imageUrls,
  });

  bool get isEmpty => imageUrls.isEmpty;

  bool get isNotEmpty => imageUrls.isNotEmpty;

  int get length => imageUrls.length;
}