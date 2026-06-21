import 'package:cloud_functions/cloud_functions.dart';

import 'package:yupgagae/features/notification/domain/push_notification_repository.dart';

class CloudFunctionsPushNotificationRepository
    implements PushNotificationRepository {
  final FirebaseFunctions functions;

  CloudFunctionsPushNotificationRepository({
    FirebaseFunctions? functions,
  }) : functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    final normalizedToken = token.trim();
    final normalizedPlatform = platform.trim();

    if (normalizedToken.isEmpty) return;
    if (normalizedPlatform.isEmpty) return;

    final callable = functions.httpsCallable('registerPushToken');

    await callable.call({
      'token': normalizedToken,
      'platform': normalizedPlatform,
    });
  }

  @override
  Future<void> deleteToken({
    required String token,
    required String platform,
  }) async {
    final normalizedToken = token.trim();
    final normalizedPlatform = platform.trim();

    if (normalizedToken.isEmpty) return;
    if (normalizedPlatform.isEmpty) return;

    final callable = functions.httpsCallable('deletePushToken');

    await callable.call({
      'token': normalizedToken,
      'platform': normalizedPlatform,
    });
  }
}