abstract class AuthSessionService {
  String get currentUserId;

  bool get isSignedIn;

  bool get isAnonymous;
}