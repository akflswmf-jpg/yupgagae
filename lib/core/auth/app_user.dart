class AppUser {
  final String userId;
  final String firebaseUid;
  final String provider;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String role;
  final String identityStatus;
  final String businessStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  const AppUser({
    required this.userId,
    required this.firebaseUid,
    required this.provider,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.role,
    required this.identityStatus,
    required this.businessStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLoginAt,
  });

  bool get isLoggedIn => firebaseUid.isNotEmpty;

  bool get isIdentityVerified => identityStatus == 'verified';

  bool get isBusinessVerified => businessStatus == 'verified';

  bool get isOwner => role == 'owner' || role == 'admin';

  bool get isAdmin => role == 'admin';

  AppUser copyWith({
    String? userId,
    String? firebaseUid,
    String? provider,
    String? email,
    String? displayName,
    String? photoUrl,
    String? role,
    String? identityStatus,
    String? businessStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      provider: provider ?? this.provider,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      identityStatus: identityStatus ?? this.identityStatus,
      businessStatus: businessStatus ?? this.businessStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}