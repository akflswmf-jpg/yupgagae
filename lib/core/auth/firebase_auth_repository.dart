import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart' as kakao;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/auth/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final GoogleSignIn _googleSignIn;

  bool _googleInitialized = false;
  Future<void>? _googleInitializeFuture;

  String? _cachedInternalUserId;
  Future<String?>? _resolveInternalUserIdFuture;

  FirebaseAuthRepository({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _auth.authStateChanges().asyncExpand((firebaseUser) async* {
      if (firebaseUser == null) {
        _cachedInternalUserId = null;
        _resolveInternalUserIdFuture = null;
        yield null;
        return;
      }

      final internalUserId = await _resolveInternalUserIdForFirebaseUser(
        firebaseUser,
      );

      if (internalUserId == null || internalUserId.trim().isEmpty) {
        yield null;
        return;
      }

      yield* _watchUserById(internalUserId);
    });
  }

  @override
  Future<AppUser?> currentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final internalUserId = await _resolveInternalUserIdForFirebaseUser(
      firebaseUser,
    );

    if (internalUserId == null || internalUserId.trim().isEmpty) {
      return null;
    }

    return _readUserById(internalUserId);
  }

  @override
  Future<AppUser?> refreshCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _cachedInternalUserId = null;
      _resolveInternalUserIdFuture = null;
      return null;
    }

    final internalUserId = await _resolveInternalUserIdForFirebaseUser(
      firebaseUser,
    );

    if (internalUserId == null || internalUserId.trim().isEmpty) {
      return null;
    }

    return _readUserById(internalUserId);
  }

  @override
  Future<AppUser> signInWithGoogle({
    bool forceAccountSelection = false,
  }) async {
    await _initializeGoogleSignIn();

    if (forceAccountSelection) {
      await _safeGoogleSignOut();
    }

    final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
    final GoogleSignInAuthentication googleAuth = googleUser.authentication;
    final String? idToken = googleAuth.idToken;

    if (idToken == null || idToken.trim().isEmpty) {
      throw Exception('Google idToken is empty');
    }

    final credential = firebase_auth.GoogleAuthProvider.credential(
      idToken: idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    final firebaseUser = userCredential.user;

    if (firebaseUser == null) {
      throw Exception('Firebase user is null after Google sign-in');
    }

    final serverUser = await _ensureAuthUserProfileOnServer(
      providerOverride: 'google',
      emailOverride: firebaseUser.email,
      displayNameOverride: firebaseUser.displayName,
      photoUrlOverride: firebaseUser.photoURL,
    );

    _cachedInternalUserId = serverUser.userId;
    _resolveInternalUserIdFuture = Future<String?>.value(serverUser.userId);

    return _readUserById(serverUser.userId);
  }

  @override
  Future<AppUser> signInWithApple() async {
    final isAvailable = await SignInWithApple.isAvailable();

    if (!isAvailable) {
      throw Exception(
        'Apple login is only available on supported Apple devices.',
      );
    }

    final rawNonce = _generateNonce();
    final hashedNonce = _sha256OfString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: hashedNonce,
    );

    final idToken = appleCredential.identityToken;

    if (idToken == null || idToken.trim().isEmpty) {
      throw Exception('Apple idToken is empty');
    }

    final oauthCredential =
        firebase_auth.OAuthProvider('apple.com').credential(
      idToken: idToken,
      rawNonce: rawNonce,
    );

    final userCredential = await _auth.signInWithCredential(oauthCredential);
    final firebaseUser = userCredential.user;

    if (firebaseUser == null) {
      throw Exception('Firebase user is null after Apple sign-in');
    }

    final appleDisplayName = _joinAppleName(
      givenName: appleCredential.givenName,
      familyName: appleCredential.familyName,
    );

    if (appleDisplayName != null &&
        appleDisplayName.isNotEmpty &&
        (firebaseUser.displayName == null ||
            firebaseUser.displayName!.trim().isEmpty)) {
      try {
        await firebaseUser.updateDisplayName(appleDisplayName);
      } catch (_) {}
    }

    final serverUser = await _ensureAuthUserProfileOnServer(
      providerOverride: 'apple',
      emailOverride: appleCredential.email ?? firebaseUser.email,
      displayNameOverride: appleDisplayName ?? firebaseUser.displayName,
      photoUrlOverride: firebaseUser.photoURL,
    );

    _cachedInternalUserId = serverUser.userId;
    _resolveInternalUserIdFuture = Future<String?>.value(serverUser.userId);

    return _readUserById(serverUser.userId);
  }

  @override
  Future<AppUser> signInWithKakao() async {
    final accessToken = await _signInWithKakaoAndGetAccessToken();

    final callable = _functions.httpsCallable(
      'signInWithKakao',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 20),
      ),
    );

    final result = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'accessToken': accessToken,
      },
    );

    final data = Map<String, dynamic>.from(result.data);

    final customToken = _asNullableString(data['customToken']);
    if (customToken == null || customToken.trim().isEmpty) {
      throw Exception('Kakao custom token is empty');
    }

    final internalUserId = _asString(data['userId']);
    if (internalUserId.isEmpty) {
      throw Exception('Failed to resolve internal userId');
    }

    _cachedInternalUserId = internalUserId;
    _resolveInternalUserIdFuture = Future<String?>.value(internalUserId);

    final userCredential = await _auth.signInWithCustomToken(customToken);
    final firebaseUser = userCredential.user;

    if (firebaseUser == null) {
      _cachedInternalUserId = null;
      _resolveInternalUserIdFuture = null;
      throw Exception('Firebase user is null after Kakao custom token sign-in');
    }

    return _readUserById(internalUserId);
  }

  @override
  Future<AppUser> completeProfileSetup({
    required bool termsAgreed,
    required String termsVersion,
    required bool pushAgreed,
    required String nickname,
    required String industry,
    required String region,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    final callable = _functions.httpsCallable(
      'completeUserProfileSetup',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 20),
      ),
    );

    final result = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'termsAgreed': termsAgreed,
        'termsVersion': termsVersion,
        'pushAgreed': pushAgreed,
        'nickname': nickname,
        'industry': industry,
        'region': region,
      },
    );

    final data = Map<String, dynamic>.from(result.data);
    final userId = _asString(data['userId']);

    if (userId.isEmpty) {
      throw Exception('Failed to resolve internal userId');
    }

    _cachedInternalUserId = userId;
    _resolveInternalUserIdFuture = Future<String?>.value(userId);

    return _readUserById(userId);
  }

  @override
  Future<AppUser> updateMyStoreProfile({
    required String nickname,
    required String industry,
    required String region,
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    final callable = _functions.httpsCallable(
      'updateMyStoreProfile',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 20),
      ),
    );

    final result = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'nickname': nickname,
        'industry': industry,
        'region': region,
      },
    );

    final data = Map<String, dynamic>.from(result.data);
    final userId = _asString(data['userId']);

    if (userId.isEmpty) {
      throw Exception('Failed to resolve internal userId');
    }

    _cachedInternalUserId = userId;
    _resolveInternalUserIdFuture = Future<String?>.value(userId);

    return _readUserById(userId);
  }

  @override
  Future<void> deleteAccount() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    final callable = _functions.httpsCallable(
      'deleteMyAccountOnServer',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 25),
      ),
    );

    await callable.call<Map<String, dynamic>>(<String, dynamic>{});

    _cachedInternalUserId = null;
    _resolveInternalUserIdFuture = null;

    await Future.wait<void>([
      _auth.signOut(),
      _safeGoogleSignOut(),
      _safeKakaoLogout(),
    ]);
  }

  @override
  Future<AppUser> acknowledgeLatestWarning() async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    final callable = _functions.httpsCallable(
      'acknowledgeLatestWarningOnServer',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 15),
      ),
    );

    final result = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{},
    );

    final data = Map<String, dynamic>.from(result.data);
    final userId = _asString(
      data['userId'],
      fallback: _cachedInternalUserId ?? '',
    );

    if (userId.trim().isEmpty) {
      throw Exception('Failed to resolve internal userId');
    }

    final normalizedUserId = userId.trim();

    _cachedInternalUserId = normalizedUserId;
    _resolveInternalUserIdFuture = Future<String?>.value(normalizedUserId);

    return _readUserById(normalizedUserId);
  }

  @override
  Future<AppUser> verifyBusiness({
    required String businessNumber,
    required String representativeName,
    required String openedAt,
  }) async {
    return _callAuthUserMutation(
      'verifyBusinessOnServer',
      data: <String, dynamic>{
        'businessNumber': businessNumber,
        'representativeName': representativeName,
        'openedAt': openedAt,
      },
    );
  }

  @override
  Future<void> signOut() async {
    _cachedInternalUserId = null;
    _resolveInternalUserIdFuture = null;

    await Future.wait<void>([
      _auth.signOut(),
      _safeGoogleSignOut(),
      _safeKakaoLogout(),
    ]);
  }

  Future<String?> _resolveInternalUserIdForFirebaseUser(
    firebase_auth.User firebaseUser,
  ) async {
    final cached = _cachedInternalUserId;

    if (cached != null && cached.trim().isNotEmpty) {
      return cached.trim();
    }

    final running = _resolveInternalUserIdFuture;
    if (running != null) {
      final resolved = await running;
      if (resolved != null && resolved.trim().isNotEmpty) {
        _cachedInternalUserId = resolved.trim();
      }
      return resolved;
    }

    _resolveInternalUserIdFuture = _ensureAuthUserProfileOnServer(
      providerOverride: _resolvePrimaryProvider(firebaseUser),
      emailOverride: firebaseUser.email,
      displayNameOverride: firebaseUser.displayName,
      photoUrlOverride: firebaseUser.photoURL,
    ).then((serverUser) {
      final userId = serverUser.userId.trim();

      if (userId.isEmpty) {
        throw Exception('Failed to resolve internal userId');
      }

      _cachedInternalUserId = userId;
      return userId;
    }).whenComplete(() {
      _resolveInternalUserIdFuture = null;
    });

    final resolved = await _resolveInternalUserIdFuture;

    if (resolved != null && resolved.trim().isNotEmpty) {
      _cachedInternalUserId = resolved.trim();
    }

    return resolved;
  }

  Future<AppUser> _callAuthUserMutation(
    String functionName, {
    Map<String, dynamic> data = const <String, dynamic>{},
  }) async {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      throw Exception('로그인이 필요합니다');
    }

    final callable = _functions.httpsCallable(
      functionName,
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 25),
      ),
    );

    final result = await callable.call<Map<String, dynamic>>(data);

    final responseData = Map<String, dynamic>.from(result.data);
    final userId = _asString(responseData['userId']);

    if (userId.isEmpty) {
      throw Exception('Failed to resolve internal userId');
    }

    _cachedInternalUserId = userId;
    _resolveInternalUserIdFuture = Future<String?>.value(userId);

    return _readUserById(userId);
  }

  Stream<AppUser> _watchUserById(String userId) {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw Exception('Failed to resolve internal userId');
    }

    return _firestore
        .collection('users')
        .doc(normalizedUserId)
        .snapshots()
        .map((snapshot) {
      final data = snapshot.data();

      if (data == null) {
        throw Exception('User document does not exist');
      }

      return _mapUserDocument(data);
    });
  }

  Future<AppUser> _ensureAuthUserProfileOnServer({
    required String providerOverride,
    String? emailOverride,
    String? displayNameOverride,
    String? photoUrlOverride,
  }) async {
    final callable = _functions.httpsCallable(
      'ensureAuthUserProfile',
      options: HttpsCallableOptions(
        timeout: const Duration(seconds: 20),
      ),
    );

    final result = await callable.call<Map<String, dynamic>>(
      <String, dynamic>{
        'provider': providerOverride,
        'email': emailOverride,
        'displayName': displayNameOverride,
        'photoUrl': photoUrlOverride,
      },
    );

    final data = Map<String, dynamic>.from(result.data);
    final userId = _asString(data['userId']);

    if (userId.isEmpty) {
      throw Exception('Failed to resolve internal userId');
    }

    return AppUser(
      userId: userId,
      firebaseUid: _asString(data['firebaseUid']),
      provider: _asString(data['provider'], fallback: providerOverride),
      email: _asNullableString(data['email']),
      displayName: _asNullableString(data['displayName']),
      photoUrl: _asNullableString(data['photoUrl']),
      role: _asString(data['role'], fallback: 'user'),
      accountStatus: _asString(
        data['accountStatus'],
        fallback: _asString(data['status'], fallback: 'active'),
      ),
      sanctionStatus: _asString(data['sanctionStatus'], fallback: 'normal'),
      sanctionReason: _asNullableString(data['sanctionReason']),
      sanctionUntil: _asDateTime(
        data['sanctionUntil'] ?? data['sanctionUntilIso'],
      ),
      sanctionUpdatedAt: _asDateTime(
        data['sanctionUpdatedAt'] ?? data['sanctionUpdatedAtIso'],
      ),
      sanctionUpdatedBy: _asNullableString(data['sanctionUpdatedBy']),
      lastSanctionId: _asNullableString(data['lastSanctionId']),
      lastWarningAcknowledgedAt: _asDateTime(
        data['lastWarningAcknowledgedAt'] ??
            data['lastWarningAcknowledgedAtIso'],
      ),
      identityStatus: _asString(data['identityStatus'], fallback: 'none'),
      businessStatus: _asString(data['businessStatus'], fallback: 'none'),
      isOfficial: _asBool(data['isOfficial']),
      profileSetupCompleted: _asBool(data['profileSetupCompleted']),
      termsAgreed: _asBool(data['termsAgreed']),
      nickname: _asNullableString(data['nickname']),
      industry: _asNullableString(data['industry']),
      region: _asNullableString(data['region']),
      createdAt: null,
      updatedAt: null,
      lastLoginAt: null,
    );
  }

  Future<AppUser> _readUserById(String userId) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw Exception('Failed to resolve internal userId');
    }

    final snapshot = await _firestore
        .collection('users')
        .doc(normalizedUserId)
        .get(const GetOptions(source: Source.server));

    final data = snapshot.data();

    if (data == null) {
      throw Exception('User document does not exist');
    }

    return _mapUserDocument(data);
  }

  Future<String> _signInWithKakaoAndGetAccessToken() async {
    kakao.OAuthToken token;

    final installed = await kakao.isKakaoTalkInstalled();

    if (installed) {
      try {
        token = await kakao.UserApi.instance.loginWithKakaoTalk();
      } catch (_) {
        token = await kakao.UserApi.instance.loginWithKakaoAccount();
      }
    } else {
      token = await kakao.UserApi.instance.loginWithKakaoAccount();
    }

    final accessToken = token.accessToken.trim();

    if (accessToken.isEmpty) {
      throw Exception('Kakao access token is empty');
    }

    return accessToken;
  }

  Future<void> _initializeGoogleSignIn() {
    if (_googleInitialized) return Future<void>.value();

    final running = _googleInitializeFuture;
    if (running != null) return running;

    _googleInitializeFuture = _googleSignIn.initialize().then((_) {
      _googleInitialized = true;
    });

    return _googleInitializeFuture!;
  }

  Future<void> _safeGoogleSignOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
  }

  Future<void> _safeKakaoLogout() async {
    try {
      await kakao.UserApi.instance.logout();
    } catch (_) {}
  }

  AppUser _mapUserDocument(Map<String, dynamic> data) {
    final identity = _asMap(data['identity']);
    final business = _asMap(data['business']);
    final terms = _asMap(data['terms']);
    final storeProfile = _asMap(data['storeProfile']);

    return AppUser(
      userId: _asString(data['userId']),
      firebaseUid: _asString(data['firebaseUid']),
      provider: _asString(data['provider']),
      email: _asNullableString(data['email']),
      displayName: _asNullableString(data['displayName']),
      photoUrl: _asNullableString(data['photoUrl']),
      role: _asString(data['role'], fallback: 'user'),
      accountStatus: _asString(
        data['accountStatus'],
        fallback: _asString(data['status'], fallback: 'active'),
      ),
      sanctionStatus: _asString(data['sanctionStatus'], fallback: 'normal'),
      sanctionReason: _asNullableString(data['sanctionReason']),
      sanctionUntil: _asDateTime(
        data['sanctionUntil'] ?? data['sanctionUntilIso'],
      ),
      sanctionUpdatedAt: _asDateTime(
        data['sanctionUpdatedAt'] ?? data['sanctionUpdatedAtIso'],
      ),
      sanctionUpdatedBy: _asNullableString(data['sanctionUpdatedBy']),
      lastSanctionId: _asNullableString(data['lastSanctionId']),
      lastWarningAcknowledgedAt: _asDateTime(
        data['lastWarningAcknowledgedAt'] ??
            data['lastWarningAcknowledgedAtIso'],
      ),
      identityStatus: _asString(identity['status'], fallback: 'none'),
      businessStatus: _asString(business['status'], fallback: 'none'),
      isOfficial: _asBool(data['isOfficial']),
      profileSetupCompleted: _asBool(data['profileSetupCompleted']),
      termsAgreed: _asBool(terms['agreed']),
      nickname: _asNullableString(storeProfile['nickname']),
      industry: _asNullableString(storeProfile['industry']),
      region: _asNullableString(storeProfile['region']),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
      lastLoginAt: _asDateTime(data['lastLoginAt']),
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return <String, dynamic>{};
  }

  String _asString(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return fallback;
  }

  String? _asNullableString(Object? value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  bool _asBool(Object? value, {bool fallback = false}) {
    if (value is bool) return value;
    return fallback;
  }

  DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  String _resolvePrimaryProvider(firebase_auth.User firebaseUser) {
    final providerData = firebaseUser.providerData;
    if (providerData.isEmpty) return 'firebase';

    final providerId = providerData.first.providerId;

    if (providerId == 'google.com') return 'google';
    if (providerId == 'apple.com') return 'apple';
    if (providerId == 'password') return 'password';
    if (providerId == 'firebase') return 'firebase';

    return providerId;
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List<String>.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String? _joinAppleName({
    required String? givenName,
    required String? familyName,
  }) {
    final parts = <String>[
      if (givenName != null && givenName.trim().isNotEmpty) givenName.trim(),
      if (familyName != null && familyName.trim().isNotEmpty)
        familyName.trim(),
    ];

    if (parts.isEmpty) return null;

    return parts.join(' ');
  }
}