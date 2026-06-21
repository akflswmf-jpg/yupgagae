import 'package:yupgagae/core/auth/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchCurrentUser();

  Future<AppUser?> currentUser();

  Future<AppUser> signInWithGoogle({
    bool forceAccountSelection = false,
  });

  Future<AppUser> signInWithApple();

  Future<AppUser> signInWithKakao();

  Future<AppUser> completeProfileSetup({
    required bool termsAgreed,
    required String termsVersion,
    required bool pushAgreed,
    required String nickname,
    required String industry,
    required String region,
  });

  Future<AppUser> updateMyStoreProfile({
    required String nickname,
    required String industry,
    required String region,
  });

  Future<void> deleteAccount();

  Future<AppUser> acknowledgeLatestWarning();

  Future<void> signOut();

  Future<AppUser?> refreshCurrentUser();

  Future<AppUser> verifyBusiness({
    required String businessNumber,
    required String representativeName,
    required String openedAt,
  });
}