import 'package:yupgagae/core/auth/app_user.dart';

abstract class AuthRepository {
  Stream<AppUser?> watchCurrentUser();

  Future<AppUser?> currentUser();

  Future<AppUser> signInWithGoogle();

  Future<void> signOut();

  Future<void> mockVerifyIdentity();

  Future<void> mockVerifyBusiness();
}