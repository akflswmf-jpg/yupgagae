import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:yupgagae/features/notification/domain/push_notification_repository.dart';

class CloudFunctionsPushNotificationRepository
    implements PushNotificationRepository {
  final FirebaseFunctions functions;
  final FirebaseAuth auth;

  CloudFunctionsPushNotificationRepository({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
        auth = auth ?? FirebaseAuth.instance;

  @override
  Future<void> registerToken({
    required String token,
    required String platform,
  }) async {
    final normalizedToken = token.trim();
    final normalizedPlatform = platform.trim();

    if (normalizedToken.isEmpty) return;
    if (normalizedPlatform.isEmpty) return;

    final user = auth.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken();
    final normalizedIdToken = idToken?.trim() ?? '';

    if (normalizedIdToken.isEmpty) return;

    final callable = functions.httpsCallable('registerPushToken');

    await callable.call({
      'token': normalizedToken,
      'platform': normalizedPlatform,
      'firebaseIdToken': normalizedIdToken,
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

    final user = auth.currentUser;
    if (user == null) return;

    final idToken = await user.getIdToken();
    final normalizedIdToken = idToken?.trim() ?? '';

    if (normalizedIdToken.isEmpty) return;

    final callable = functions.httpsCallable('deletePushToken');

    await callable.call({
      'token': normalizedToken,
      'platform': normalizedPlatform,
      'firebaseIdToken': normalizedIdToken,
    });
  }
}