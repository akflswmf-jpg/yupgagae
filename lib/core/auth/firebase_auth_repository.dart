import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/auth/auth_repository.dart';

class FirebaseAuthRepository implements AuthRepository {
  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final GoogleSignIn _googleSignIn;

  bool _googleInitialized = false;
  Future<void>? _googleInitializeFuture;

  FirebaseAuthRepository({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  })  : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  @override
  Stream<AppUser?> watchCurrentUser() {
    return _auth.authStateChanges().asyncExpand((firebaseUser) async* {
      if (firebaseUser == null) {
        yield null;
        return;
      }

      final ensuredUser = await _ensureUserProfile(firebaseUser);
      final userId = ensuredUser.userId;

      yield* _firestore.collection('users').doc(userId).snapshots().map(
        (snapshot) {
          final data = snapshot.data();
          if (data == null) return ensuredUser;
          return _mapUserDocument(data);
        },
      );
    });
  }

  @override
  Future<AppUser?> currentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return _ensureUserProfile(firebaseUser);
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    await _initializeGoogleSignIn();

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

    return _ensureUserProfile(firebaseUser);
  }

  @override
  Future<void> signOut() async {
    await Future.wait<void>([
      _auth.signOut(),
      _safeGoogleSignOut(),
    ]);
  }

  @override
  Future<void> mockVerifyIdentity() async {
    final user = await currentUser();

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final userRef = _firestore.collection('users').doc(user.userId);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        throw Exception('사용자 문서를 찾을 수 없습니다.');
      }

      final data = snapshot.data() ?? <String, dynamic>{};
      final currentRole = _asString(data['role'], fallback: 'user');
      final nextRole = _nextRoleAfterIdentityVerified(currentRole);

      transaction.set(
        userRef,
        <String, dynamic>{
          'role': nextRole,
          'identity': <String, dynamic>{
            'status': 'verified',
            'verifiedAt': now,
            'provider': 'mock',
            'failureCount': 0,
            'lockedUntil': null,
          },
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    });
  }

  @override
  Future<void> mockVerifyBusiness() async {
    final user = await currentUser();

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    final userRef = _firestore.collection('users').doc(user.userId);
    final now = FieldValue.serverTimestamp();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);

      if (!snapshot.exists) {
        throw Exception('사용자 문서를 찾을 수 없습니다.');
      }

      transaction.set(
        userRef,
        <String, dynamic>{
          'role': 'owner',
          'business': <String, dynamic>{
            'status': 'verified',
            'businessNumberHash': 'mock_business_hash',
            'businessNumberMasked': '123-**-67890',
            'representativeNameHash': 'mock_representative_hash',
            'openedAt': '2020-01-01',
            'verifiedAt': now,
            'failureCount': 0,
            'lockedUntil': null,
            'ownershipSlot': 1,
          },
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _initializeGoogleSignIn() {
    if (_googleInitialized) {
      return Future<void>.value();
    }

    final running = _googleInitializeFuture;
    if (running != null) {
      return running;
    }

    _googleInitializeFuture = _googleSignIn.initialize().then((_) {
      _googleInitialized = true;
    });

    return _googleInitializeFuture!;
  }

  Future<void> _safeGoogleSignOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Firebase 로그아웃이 우선이다.
      // Google 로그아웃 실패는 앱 세션 정리에 치명적이지 않으므로 삼킨다.
    }
  }

  Future<AppUser> _ensureUserProfile(
    firebase_auth.User firebaseUser,
  ) async {
    final firebaseUid = firebaseUser.uid;
    final provider = _resolvePrimaryProvider(firebaseUser);

    final linkRef = _firestore.collection('auth_links').doc(firebaseUid);
    final now = FieldValue.serverTimestamp();

    String? resolvedUserId;

    await _firestore.runTransaction((transaction) async {
      final linkSnapshot = await transaction.get(linkRef);

      if (linkSnapshot.exists) {
        final data = linkSnapshot.data() ?? <String, dynamic>{};
        final existingUserId = data['userId'];

        if (existingUserId is String && existingUserId.trim().isNotEmpty) {
          resolvedUserId = existingUserId.trim();

          final userRef = _firestore.collection('users').doc(resolvedUserId);
          transaction.set(
            userRef,
            <String, dynamic>{
              'firebaseUid': firebaseUid,
              'provider': provider,
              'email': firebaseUser.email,
              'displayName': firebaseUser.displayName,
              'photoUrl': firebaseUser.photoURL,
              'updatedAt': now,
              'lastLoginAt': now,
            },
            SetOptions(merge: true),
          );
        }
        return;
      }

      final newUserId = _createInternalUserId();
      resolvedUserId = newUserId;

      final userRef = _firestore.collection('users').doc(newUserId);

      transaction.set(linkRef, <String, dynamic>{
        'firebaseUid': firebaseUid,
        'userId': newUserId,
        'provider': provider,
        'createdAt': now,
        'updatedAt': now,
      });

      transaction.set(userRef, <String, dynamic>{
        'userId': newUserId,
        'firebaseUid': firebaseUid,
        'provider': provider,
        'email': firebaseUser.email,
        'displayName': firebaseUser.displayName,
        'photoUrl': firebaseUser.photoURL,
        'role': 'user',
        'identity': <String, dynamic>{
          'status': 'none',
          'verifiedAt': null,
          'provider': null,
          'failureCount': 0,
          'lockedUntil': null,
        },
        'business': <String, dynamic>{
          'status': 'none',
          'businessNumberHash': null,
          'businessNumberMasked': null,
          'representativeNameHash': null,
          'openedAt': null,
          'verifiedAt': null,
          'failureCount': 0,
          'lockedUntil': null,
          'ownershipSlot': null,
        },
        'createdAt': now,
        'updatedAt': now,
        'lastLoginAt': now,
        'isDeleted': false,
        'sanctionStatus': 'normal',
      });
    });

    final userId = resolvedUserId;

    if (userId == null || userId.trim().isEmpty) {
      throw Exception('Failed to resolve internal userId');
    }

    final userSnapshot = await _firestore.collection('users').doc(userId).get();
    final userData = userSnapshot.data();

    if (userData == null) {
      throw Exception('User document does not exist');
    }

    return _mapUserDocument(userData);
  }

  AppUser _mapUserDocument(Map<String, dynamic> data) {
    final identity = _asMap(data['identity']);
    final business = _asMap(data['business']);

    return AppUser(
      userId: _asString(data['userId']),
      firebaseUid: _asString(data['firebaseUid']),
      provider: _asString(data['provider']),
      email: _asNullableString(data['email']),
      displayName: _asNullableString(data['displayName']),
      photoUrl: _asNullableString(data['photoUrl']),
      role: _asString(data['role'], fallback: 'user'),
      identityStatus: _asString(identity['status'], fallback: 'none'),
      businessStatus: _asString(business['status'], fallback: 'none'),
      createdAt: _asDateTime(data['createdAt']),
      updatedAt: _asDateTime(data['updatedAt']),
      lastLoginAt: _asDateTime(data['lastLoginAt']),
    );
  }

  Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return <String, dynamic>{};
  }

  String _asString(Object? value, {String fallback = ''}) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return fallback;
  }

  String? _asNullableString(Object? value) {
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  DateTime? _asDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _resolvePrimaryProvider(firebase_auth.User firebaseUser) {
    final providerData = firebaseUser.providerData;

    if (providerData.isEmpty) {
      return 'firebase';
    }

    final providerId = providerData.first.providerId;

    if (providerId == 'google.com') {
      return 'google';
    }

    if (providerId == 'apple.com') {
      return 'apple';
    }

    if (providerId == 'password') {
      return 'password';
    }

    return providerId;
  }

  String _nextRoleAfterIdentityVerified(String currentRole) {
    if (currentRole == 'admin') return 'admin';
    if (currentRole == 'owner') return 'owner';
    if (currentRole == 'seed') return 'seed';
    if (currentRole == 'banned') return 'banned';
    return 'verified';
  }

  String _createInternalUserId() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final random = const Uuid().v4().replaceAll('-', '').substring(0, 12);
    return 'usr_${millis}_$random';
  }
}