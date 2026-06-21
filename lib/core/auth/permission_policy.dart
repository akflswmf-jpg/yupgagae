import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/features/community/domain/post.dart';

enum UserRole {
  user,
  admin,
}

enum AccountStatus {
  active,
  suspended,
  withdrawn,
}

enum IdentityStatus {
  none,
  verified,
}

enum BusinessStatus {
  none,
  pending,
  verified,
  rejected,
}

class PermissionPolicy {
  const PermissionPolicy._();

  static UserRole roleOf(AppUser? user) {
    final raw = user?.role.trim().toLowerCase() ?? '';

    switch (raw) {
      case 'admin':
        return UserRole.admin;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  static AccountStatus accountStatusOf(AppUser? user) {
    final raw = user?.accountStatus.trim().toLowerCase() ?? '';

    switch (raw) {
      case 'suspended':
        return AccountStatus.suspended;
      case 'withdrawn':
        return AccountStatus.withdrawn;
      case 'active':
      default:
        return AccountStatus.active;
    }
  }

  static IdentityStatus identityStatusOf(AppUser? user) {
    final raw = user?.identityStatus.trim().toLowerCase() ?? '';

    switch (raw) {
      case 'verified':
        return IdentityStatus.verified;
      case 'none':
      default:
        return IdentityStatus.none;
    }
  }

  static BusinessStatus businessStatusOf(AppUser? user) {
    final raw = user?.businessStatus.trim().toLowerCase() ?? '';

    switch (raw) {
      case 'verified':
        return BusinessStatus.verified;
      case 'pending':
        return BusinessStatus.pending;
      case 'rejected':
        return BusinessStatus.rejected;
      case 'none':
      default:
        return BusinessStatus.none;
    }
  }

  static bool isAdmin(AppUser? user) {
    if (user == null) return false;
    return roleOf(user) == UserRole.admin;
  }

  static bool isOfficial(AppUser? user) {
    return user?.isOfficial == true;
  }

  static bool isActiveAccount(AppUser? user) {
    if (user == null) return false;
    if (user.isWithdrawn) return false;
    if (user.isAccountSuspended) return false;
    if (user.isPermanentlyBanned) return false;

    return accountStatusOf(user) == AccountStatus.active;
  }

  static bool isCommunityRestricted(AppUser? user) {
    if (user == null) return false;
    return user.isCommunityRestricted;
  }

  static bool hasCompletedProfileSetup(AppUser? user) {
    if (user == null) return false;

    final userId = user.userId.trim();
    if (userId.isEmpty) return false;

    if (user.needsProfileSetup) return false;

    return true;
  }

  static bool canEnterApp(AppUser? user) {
    if (user == null) return false;
    if (user.isWithdrawn) return false;

    return true;
  }

  static bool canParticipate(AppUser? user) {
    if (user == null) return false;
    if (!isActiveAccount(user)) return false;
    if (isCommunityRestricted(user)) return false;
    if (!hasCompletedProfileSetup(user)) return false;

    return true;
  }

  static bool canViewBoard({
    required AppUser? user,
    required BoardType boardType,
  }) {
    switch (boardType) {
      case BoardType.free:
        return true;
      case BoardType.used:
        return true;
      case BoardType.owner:
        return canViewOwnerBoard(user);
    }
  }

  static bool canViewOwnerBoard(AppUser? user) {
    return true;
  }

  static bool canWritePost({
    required AppUser? user,
    required BoardType boardType,
  }) {
    if (!canParticipate(user)) return false;

    if (isAdmin(user)) return true;
    if (isOfficial(user)) return true;

    switch (boardType) {
      case BoardType.free:
        return canWriteFreeBoard(user);
      case BoardType.used:
        return canWriteUsedBoard(user);
      case BoardType.owner:
        return canWriteOwnerBoard(user);
    }
  }

  static bool canWriteFreeBoard(AppUser? user) {
    return canParticipate(user);
  }

  static bool canWriteUsedBoard(AppUser? user) {
    return canParticipate(user);
  }

  static bool canWriteOwnerBoard(AppUser? user) {
    if (!canParticipate(user)) return false;

    if (isAdmin(user)) return true;
    if (isOfficial(user)) return true;

    return businessStatusOf(user) == BusinessStatus.verified;
  }

  static bool canWriteComment(AppUser? user) {
    return canParticipate(user);
  }

  static bool canWriteOwnerBoardComment(AppUser? user) {
    if (!canParticipate(user)) return false;

    if (isAdmin(user)) return true;
    if (isOfficial(user)) return true;

    return businessStatusOf(user) == BusinessStatus.verified;
  }

  static bool canTogglePostLike(AppUser? user) {
    return canParticipate(user);
  }

  static bool canToggleCommentLike(AppUser? user) {
    return canParticipate(user);
  }

  static bool canReportPost({
    required AppUser? user,
    required Post post,
  }) {
    if (!canParticipate(user)) return false;

    final userId = user?.userId.trim() ?? '';
    if (userId.isEmpty) return false;

    if (post.authorId == userId) return false;

    return true;
  }

  static bool canDeletePost({
    required AppUser? user,
    required Post post,
  }) {
    if (!canParticipate(user)) return false;

    if (isAdmin(user)) return true;

    final userId = user?.userId.trim() ?? '';
    if (userId.isEmpty) return false;

    return post.authorId == userId;
  }

  static bool canToggleSold({
    required AppUser? user,
    required Post post,
  }) {
    if (!canParticipate(user)) return false;

    final userId = user?.userId.trim() ?? '';
    if (userId.isEmpty) return false;

    return post.boardType == BoardType.used && post.authorId == userId;
  }

  static bool canAccessAdmin(AppUser? user) {
    if (user == null) return false;
    if (!isActiveAccount(user)) return false;
    if (isCommunityRestricted(user)) return false;

    return isAdmin(user);
  }

  static String participationBlockedMessage(AppUser? user) {
    if (user == null) {
      return '로그인이 필요한 기능입니다.';
    }

    if (user.isPermanentlyBanned) {
      return '운영정책 위반으로 커뮤니티 이용이 제한되었습니다.';
    }

    if (user.isCurrentlySuspendedBySanction) {
      return '정지 기간 중에는 커뮤니티 기능을 이용할 수 없습니다.\n해제 예정: ${user.sanctionUntilLabel}';
    }

    if (user.isAccountSuspended) {
      return '정지된 계정입니다.';
    }

    if (user.isWithdrawn) {
      return '탈퇴 처리된 계정입니다.';
    }

    if (!hasCompletedProfileSetup(user)) {
      return '가입 설정을 먼저 완료해주세요.';
    }

    return '권한이 없습니다.';
  }

  static String writePostBlockedMessage({
    required AppUser? user,
    required BoardType boardType,
  }) {
    if (!canParticipate(user)) {
      return participationBlockedMessage(user);
    }

    switch (boardType) {
      case BoardType.free:
      case BoardType.used:
        return '글을 작성할 수 없습니다.';
      case BoardType.owner:
        return '사업자 인증 후 이용할 수 있습니다.';
    }
  }

  static String writeCommentBlockedMessage({
    required AppUser? user,
    required BoardType boardType,
  }) {
    if (!canParticipate(user)) {
      return participationBlockedMessage(user);
    }

    switch (boardType) {
      case BoardType.owner:
        return '사업자 인증 후 댓글을 작성할 수 있습니다.';
      case BoardType.free:
      case BoardType.used:
        return '댓글을 작성할 수 없습니다.';
    }
  }

  static String toggleLikeBlockedMessage(AppUser? user) {
    if (!canParticipate(user)) {
      return participationBlockedMessage(user);
    }

    return '좋아요를 누를 수 없습니다.';
  }

  static String reportBlockedMessage(AppUser? user) {
    if (!canParticipate(user)) {
      return participationBlockedMessage(user);
    }

    return '신고할 수 없습니다.';
  }

  static String ownerBoardWriteBlockedMessage(AppUser? user) {
    if (!canParticipate(user)) {
      return participationBlockedMessage(user);
    }

    return '사업자 인증 후 사장님 게시판에 글을 작성할 수 있습니다.';
  }

  static String adminBlockedMessage(AppUser? user) {
    if (user == null) {
      return '로그인이 필요한 기능입니다.';
    }

    if (!isActiveAccount(user) || isCommunityRestricted(user)) {
      return participationBlockedMessage(user);
    }

    return '관리자 권한이 없습니다.';
  }
}