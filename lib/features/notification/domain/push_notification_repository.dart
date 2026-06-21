abstract class PushNotificationRepository {
  Future<void> registerToken({
    required String token,
    required String platform,
  });

  Future<void> deleteToken({
    required String token,
    required String platform,
  });
}