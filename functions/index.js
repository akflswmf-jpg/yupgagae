const axios = require("axios");
const crypto = require("crypto");
const admin = require("firebase-admin");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();

const db = admin.firestore();

const harugyeol = require("./src/harugyeol");
const community = require("./src/community");
const notification = require("./src/notification");

exports.submitHarugyeolEntry = harugyeol.submitHarugyeolEntry;
exports.toggleHarugyeolCommentLike = harugyeol.toggleHarugyeolCommentLike;

exports.reportPost = community.reportPost;
exports.reportComment = community.reportComment;
exports.deletePostOnServer = community.deletePostOnServer;
exports.deleteCommentOnServer = community.deleteCommentOnServer;
exports.hidePostByAdminOnServer = community.hidePostByAdminOnServer;
exports.unhidePostByAdminOnServer = community.unhidePostByAdminOnServer;
exports.clearPostReportThresholdByAdminOnServer =
  community.clearPostReportThresholdByAdminOnServer;
exports.removePostByAdminOnServer = community.removePostByAdminOnServer;
exports.hideCommentByAdminOnServer = community.hideCommentByAdminOnServer;
exports.unhideCommentByAdminOnServer = community.unhideCommentByAdminOnServer;
exports.clearCommentReportThresholdByAdminOnServer =
  community.clearCommentReportThresholdByAdminOnServer;
exports.removeCommentByAdminOnServer = community.removeCommentByAdminOnServer;
exports.sanctionUserByAdminOnServer = community.sanctionUserByAdminOnServer;
exports.clearUserSanctionByAdminOnServer =
  community.clearUserSanctionByAdminOnServer;

exports.fetchMyBlockedUsersOnServer = community.fetchMyBlockedUsersOnServer;
exports.blockUserOnServer = community.blockUserOnServer;
exports.unblockUserOnServer = community.unblockUserOnServer;

exports.registerPushToken = notification.registerPushToken;
exports.deletePushToken = notification.deletePushToken;
exports.sendTestPushToMe = notification.sendTestPushToMe;
exports.onCommunityCommentCreated = notification.onCommunityCommentCreated;
exports.sendHarugyeolMiddayReminder = notification.sendHarugyeolMiddayReminder;
exports.sendHarugyeolEveningReminder = notification.sendHarugyeolEveningReminder;

const NTS_BUSINESS_SERVICE_KEY = defineSecret("NTS_BUSINESS_SERVICE_KEY");

const KAKAO_USER_ME_URL = "https://kapi.kakao.com/v2/user/me";
const NTS_BUSINESS_VALIDATE_URL =
  "https://api.odcloud.kr/api/nts-businessman/v1/validate";

const NICKNAME_MIN_LENGTH = 2;
const NICKNAME_MAX_LENGTH = 10;

const RESERVED_NICKNAME_KEYS = new Set([
  "admin",
  "administrator",
  "manager",
  "master",
  "official",
  "operator",
  "owner",
  "staff",
  "support",
  "system",
  "yupgagae",
  "yeopgagae",
  "옆가게",
  "관리자",
  "운영자",
  "운영팀",
  "공식",
  "공식계정",
  "시스템",
  "고객센터",
  "고객지원",
  "관리팀",
  "운영진",
  "탈퇴사용자",
]);

const BLOCKED_NICKNAME_KEYWORDS = [
  "시발",
  "씨발",
  "씨팔",
  "ㅅㅂ",
  "ㅆㅂ",
  "ㅂㅅ",
  "병신",
  "븅신",
  "개새",
  "개색",
  "개쉐",
  "개자식",
  "새끼",
  "존나",
  "졸라",
  "ㅈㄴ",
  "지랄",
  "ㅈㄹ",
  "염병",
  "닥쳐",
  "꺼져",
  "죽어",
  "미친",
  "개같",
  "fuck",
  "fucking",
  "shit",
  "bitch",
  "bastard",
  "asshole",

  "섹스",
  "sex",
  "sexy",
  "자위",
  "딸딸",
  "성감",
  "꼴림",
  "꼴린",
  "꼴려",
  "발정",
  "음란",
  "변태",
  "노출",
  "가슴",
  "찌찌",
  "보지",
  "자지",
  "꼬추",
  "질싸",
  "정액",
  "삽입",
  "강간",
  "성폭행",
  "성추행",
  "성매매",
  "창녀",
  "창남",
  "걸레",

  "한남",
  "한녀",
  "김치녀",
  "김치남",
  "맘충",
  "여혐",
  "남혐",

  "장애인",
  "장애새끼",
  "도박충",
  "정신병",
  "지체아",
  "자폐",

  "짱깨",
  "짱개",
  "쪽바리",
  "왜놈",
  "깜둥이",
  "조센징",
  "조센",

  "일베",
  "일베충",
  "베충",
  "메갈",
  "메갈년",
  "워마드",
  "좌빨",
  "우빨",
  "빨갱이",
  "문빠",
  "윤빠",

  "살인",
  "살인자",
  "죽인다",
  "죽여",
  "칼빵",
  "도박",
  "테러",
  "마약",
  "필로폰",
  "강도",
  "토토",
  "바카라",
  "불법",
];
exports.signInWithKakao = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    const accessToken = normalizeString(request.data && request.data.accessToken);

    if (!accessToken) {
      throw new HttpsError(
        "invalid-argument",
        "Kakao accessToken is required."
      );
    }

    const kakaoUser = await fetchKakaoUser(accessToken);
    const kakaoId = normalizeKakaoId(kakaoUser && kakaoUser.id);

    if (!kakaoId) {
      throw new HttpsError(
        "unauthenticated",
        "Failed to resolve Kakao user id."
      );
    }

    const firebaseUid = `kakao:${kakaoId}`;
    const kakaoAccount = kakaoUser.kakao_account || {};
    const profile = kakaoAccount.profile || {};

    const email = normalizeString(kakaoAccount.email);
    const displayName = normalizeString(profile.nickname);
    const photoUrl = normalizeString(profile.profile_image_url);

    const appUser = await ensureUserProfile({
      firebaseUid,
      provider: "kakao",
      email,
      displayName,
      photoUrl,
    });

    const customToken = await admin.auth().createCustomToken(firebaseUid, {
      provider: "kakao",
      kakaoId,
      internalUserId: appUser.userId,
    });

    logger.info("Kakao custom token issued", {
      firebaseUid,
      internalUserId: appUser.userId,
      hasEmail: Boolean(email),
      hasDisplayName: Boolean(displayName),
      hasPhotoUrl: Boolean(photoUrl),
      profileSetupCompleted: appUser.profileSetupCompleted,
    });

    return {
      customToken,
      provider: "kakao",
      firebaseUid,
      userId: appUser.userId,
      kakaoUserId: kakaoId,
      email: email || null,
      displayName: displayName || null,
      photoUrl: photoUrl || null,
      role: appUser.role,
      identityStatus: appUser.identityStatus,
      businessStatus: appUser.businessStatus,
      profileSetupCompleted: appUser.profileSetupCompleted,
      termsAgreed: appUser.termsAgreed,
      nickname: appUser.nickname || null,
      industry: appUser.industry || null,
      region: appUser.region || null,
    };
  }
);

exports.ensureAuthUserProfile = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Firebase authentication is required."
      );
    }

    const firebaseUid = request.auth.uid;
    const token = request.auth.token || {};
    const firebase = token.firebase || {};

    const requestedProvider = normalizeProvider(
      request.data && request.data.provider
    );

    const provider =
      requestedProvider || resolveProvider(firebase.sign_in_provider);

    const email =
      normalizeString(token.email) ||
      normalizeString(request.data && request.data.email);

    const displayName =
      normalizeString(token.name) ||
      normalizeString(request.data && request.data.displayName);

    const photoUrl =
      normalizeString(token.picture) ||
      normalizeString(request.data && request.data.photoUrl);

    const appUser = await ensureUserProfile({
      firebaseUid,
      provider,
      email,
      displayName,
      photoUrl,
    });

    logger.info("Auth user profile ensured", {
      firebaseUid,
      internalUserId: appUser.userId,
      provider,
      profileSetupCompleted: appUser.profileSetupCompleted,
    });

    return {
      userId: appUser.userId,
      firebaseUid,
      provider,
      email: email || null,
      displayName: displayName || null,
      photoUrl: photoUrl || null,
      role: appUser.role,
      identityStatus: appUser.identityStatus,
      businessStatus: appUser.businessStatus,
      profileSetupCompleted: appUser.profileSetupCompleted,
      termsAgreed: appUser.termsAgreed,
      nickname: appUser.nickname || null,
      industry: appUser.industry || null,
      region: appUser.region || null,
    };
  }
);

exports.completeUserProfileSetup = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Firebase authentication is required."
      );
    }

    const firebaseUid = request.auth.uid;
    const data = request.data || {};

    const termsAgreed = data.termsAgreed === true;
    const termsVersion = normalizeString(data.termsVersion) || "v1";
    const pushAgreed = data.pushAgreed === true;

    const nickname = normalizeNickname(data.nickname);
    const nicknameKey = createNicknameKey(nickname);
    const industry = normalizeProfileText(data.industry, "industry", 30);
    const region = normalizeProfileText(data.region, "region", 30);

    if (!termsAgreed) {
      throw new HttpsError(
        "invalid-argument",
        "Terms agreement is required."
      );
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    const linkRef = db.collection("auth_links").doc(firebaseUid);

    let resolvedUserId = "";

    await db.runTransaction(async (transaction) => {
      const linkSnapshot = await transaction.get(linkRef);

      if (!linkSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Auth link document does not exist."
        );
      }

      const linkData = linkSnapshot.data() || {};
      const userId = normalizeString(linkData.userId);

      if (!userId) {
        throw new HttpsError(
          "data-loss",
          "auth_links document exists but userId is empty."
        );
      }

      resolvedUserId = userId;

      const userRef = db.collection("users").doc(userId);
      const userSnapshot = await transaction.get(userRef);

      if (!userSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "User document does not exist."
        );
      }

      const nicknameRef = db.collection("nicknames").doc(nicknameKey);
      const nicknameSnapshot = await transaction.get(nicknameRef);

      const userData = userSnapshot.data() || {};
      const userFirebaseUid = normalizeString(userData.firebaseUid);

      if (userFirebaseUid !== firebaseUid) {
        throw new HttpsError(
          "permission-denied",
          "User document does not belong to current Firebase user."
        );
      }

      assertNicknameAvailable({
        nicknameSnapshot,
        userId,
      });

      reserveNickname({
        transaction,
        nicknameRef,
        userId,
        firebaseUid,
        nickname,
        nicknameKey,
        now,
      });

      transaction.set(
        userRef,
        {
          profileSetupCompleted: true,
          terms: {
            agreed: true,
            agreedAt: now,
            version: termsVersion,
          },
          notificationConsent: {
            pushAgreed,
            pushAgreedAt: pushAgreed ? now : null,
            pushVersion: termsVersion,
            updatedAt: now,
          },
          storeProfile: {
            nickname,
            nicknameKey,
            industry,
            region,
            createdAt:
              userData.storeProfile && userData.storeProfile.createdAt
                ? userData.storeProfile.createdAt
                : now,
            updatedAt: now,
          },
          status: "active",
          isDeleted: false,
          updatedAt: now,
        },
        {
          merge: true,
        }
      );
    });

    if (!resolvedUserId) {
      throw new HttpsError("internal", "Failed to resolve internal userId.");
    }

    const userSnapshot = await db.collection("users").doc(resolvedUserId).get();
    const userData = userSnapshot.data() || {};

    logger.info("User profile setup completed", {
      firebaseUid,
      internalUserId: resolvedUserId,
      nickname,
      nicknameKey,
      industry,
      region,
      pushAgreed,
    });

    return buildAppUserResponse(userData, {
      fallbackUserId: resolvedUserId,
      fallbackFirebaseUid: firebaseUid,
      fallbackProvider: "firebase",
    });
  }
);

exports.updateMyStoreProfile = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Firebase authentication is required."
      );
    }

    const firebaseUid = request.auth.uid;
    const data = request.data || {};

    const nickname = normalizeNickname(data.nickname);
    const nicknameKey = createNicknameKey(nickname);
    const industry = normalizeProfileText(data.industry, "industry", 30);
    const region = normalizeProfileText(data.region, "region", 30);

    const now = admin.firestore.FieldValue.serverTimestamp();
    const linkRef = db.collection("auth_links").doc(firebaseUid);

    let resolvedUserId = "";

    await db.runTransaction(async (transaction) => {
      const linkSnapshot = await transaction.get(linkRef);

      if (!linkSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "Auth link document does not exist."
        );
      }

      const linkData = linkSnapshot.data() || {};
      const userId = normalizeString(linkData.userId);

      if (!userId) {
        throw new HttpsError(
          "data-loss",
          "auth_links document exists but userId is empty."
        );
      }

      resolvedUserId = userId;

      const userRef = db.collection("users").doc(userId);
      const userSnapshot = await transaction.get(userRef);

      if (!userSnapshot.exists) {
        throw new HttpsError(
          "not-found",
          "User document does not exist."
        );
      }

      const userData = userSnapshot.data() || {};
      const userFirebaseUid = normalizeString(userData.firebaseUid);

      if (userFirebaseUid !== firebaseUid) {
        throw new HttpsError(
          "permission-denied",
          "User document does not belong to current Firebase user."
        );
      }

      if (userData.profileSetupCompleted !== true) {
        throw new HttpsError(
          "failed-precondition",
          "Profile setup must be completed first."
        );
      }

      if (
        normalizeString(userData.status) === "withdrawn" ||
        userData.isDeleted === true
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Account already withdrawn."
        );
      }

      const storeProfile = userData.storeProfile || {};
      const previousNickname = normalizeString(storeProfile.nickname);
      const previousNicknameKey =
        normalizeString(storeProfile.nicknameKey) ||
        createNicknameKeyForExistingValue(previousNickname);

      const nicknameChanged = previousNicknameKey !== nicknameKey;

      if (nicknameChanged) {
        const nicknameRef = db.collection("nicknames").doc(nicknameKey);
        const nicknameSnapshot = await transaction.get(nicknameRef);

        assertNicknameAvailable({
          nicknameSnapshot,
          userId,
        });

        reserveNickname({
          transaction,
          nicknameRef,
          userId,
          firebaseUid,
          nickname,
          nicknameKey,
          now,
        });

        if (previousNicknameKey) {
          const previousNicknameRef =
            db.collection("nicknames").doc(previousNicknameKey);
          transaction.delete(previousNicknameRef);
        }
      } else if (previousNickname !== nickname) {
        const nicknameRef = db.collection("nicknames").doc(nicknameKey);
        const nicknameSnapshot = await transaction.get(nicknameRef);

        assertNicknameAvailable({
          nicknameSnapshot,
          userId,
        });

        reserveNickname({
          transaction,
          nicknameRef,
          userId,
          firebaseUid,
          nickname,
          nicknameKey,
          now,
        });
      }

      transaction.set(
        userRef,
        {
          storeProfile: {
            nickname,
            nicknameKey,
            industry,
            region,
            createdAt:
              userData.storeProfile && userData.storeProfile.createdAt
                ? userData.storeProfile.createdAt
                : now,
            updatedAt: now,
          },
          updatedAt: now,
        },
        {
          merge: true,
        }
      );
    });

    if (!resolvedUserId) {
      throw new HttpsError("internal", "Failed to resolve internal userId.");
    }

    const userSnapshot = await db.collection("users").doc(resolvedUserId).get();
    const userData = userSnapshot.data() || {};

    logger.info("My store profile updated", {
      firebaseUid,
      internalUserId: resolvedUserId,
      nickname,
      nicknameKey,
      industry,
      region,
    });

    return buildAppUserResponse(userData, {
      fallbackUserId: resolvedUserId,
      fallbackFirebaseUid: firebaseUid,
      fallbackProvider: "firebase",
    });
  }
);

exports.deleteMyAccountOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 60,
    memory: "512MiB",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const now = admin.firestore.FieldValue.serverTimestamp();

    let authDeleteTargetUid = resolved.firebaseUid;
    let resolvedProvider = "firebase";
    let anonymizedPosts = 0;
    let anonymizedComments = 0;

    try {
      await db.runTransaction(async (transaction) => {
        const userSnapshot = await transaction.get(resolved.userRef);

        if (!userSnapshot.exists) {
          throw new HttpsError("not-found", "User document does not exist.");
        }

        const userData = userSnapshot.data() || {};
        validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);

        const currentStatus = normalizeString(userData.status);
        const alreadyDeleted = userData.isDeleted === true;

        if (currentStatus === "withdrawn" || alreadyDeleted) {
          throw new HttpsError(
            "failed-precondition",
            "Account already withdrawn."
          );
        }

        resolvedProvider = normalizeProvider(userData.provider) || "firebase";
        authDeleteTargetUid =
          normalizeString(userData.firebaseUid) || resolved.firebaseUid;

        const storeProfile = userData.storeProfile || {};
        const previousNickname = normalizeString(storeProfile.nickname);
        const previousNicknameKey =
          normalizeString(storeProfile.nicknameKey) ||
          createNicknameKeyForExistingValue(previousNickname);

        if (previousNicknameKey) {
          transaction.delete(
            db.collection("nicknames").doc(previousNicknameKey)
          );
        }

        transaction.set(
          resolved.userRef,
          {
            status: "withdrawn",
            isDeleted: true,
            withdrawnAt: now,
            deletedAt: now,
            email: null,
            displayName: null,
            photoUrl: null,
            role: "withdrawn",
            profileSetupCompleted: false,
            identity: {
              status: "withdrawn",
              verifiedAt: null,
              provider: null,
              verifiedNameHash: null,
              verifiedNameMasked: null,
              failureCount: 0,
              lockedUntil: null,
            },
            business: {
              status: "withdrawn",
              businessNumberHash: null,
              businessNumberMasked: null,
              representativeNameHash: null,
              representativeNameMasked: null,
              openedAt: null,
              verifiedAt: null,
              failureCount: 0,
              lockedUntil: null,
              ownershipSlot: null,
              lastFailureReason: null,
              lastCheckedAt: null,
            },
            storeProfile: {
              nickname: "탈퇴사용자",
              nicknameKey: null,
              industry: null,
              region: null,
              createdAt:
                userData.storeProfile && userData.storeProfile.createdAt
                  ? userData.storeProfile.createdAt
                  : null,
              updatedAt: now,
            },
            notificationConsent: {
              pushAgreed: false,
              pushAgreedAt: null,
              pushVersion: null,
              updatedAt: now,
            },
            updatedAt: now,
          },
          {
            merge: true,
          }
        );

        transaction.delete(
          db.collection("auth_links").doc(resolved.firebaseUid)
        );
      });

      const anonymized = await anonymizeWithdrawnUserCommunityContent({
        userId: resolved.userId,
        now,
      });

      anonymizedPosts = anonymized.posts;
      anonymizedComments = anonymized.comments;

      try {
        await admin.auth().deleteUser(authDeleteTargetUid);
      } catch (error) {
        const code = error && error.code ? String(error.code) : "";

        if (code !== "auth/user-not-found") {
          throw error;
        }
      }

      logger.info("Account withdrawn", {
        firebaseUid: resolved.firebaseUid,
        internalUserId: resolved.userId,
        provider: resolvedProvider,
        anonymizedPosts,
        anonymizedComments,
      });

      return {
        ok: true,
        userId: resolved.userId,
        firebaseUid: resolved.firebaseUid,
        status: "withdrawn",
        anonymizedPosts,
        anonymizedComments,
      };
    } catch (error) {
      if (error instanceof HttpsError) {
        throw error;
      }

      logger.error("Delete account failed", {
        firebaseUid: resolved.firebaseUid,
        internalUserId: resolved.userId,
        anonymizedPosts,
        anonymizedComments,
        error,
      });

      throw new HttpsError("internal", "Delete account failed.");
    }
  }
);


exports.incrementPostViewOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 10,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const postId = normalizeString(request.data && request.data.postId);

    if (!postId) {
      throw new HttpsError("invalid-argument", "postId is required.");
    }

    const userSnapshot = await resolved.userRef.get();

    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "User document does not exist.");
    }

    const userData = userSnapshot.data() || {};
    validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);

    if (userData.profileSetupCompleted !== true) {
      throw new HttpsError(
        "failed-precondition",
        "Profile setup must be completed first."
      );
    }

    if (
      normalizeString(userData.status) === "withdrawn" ||
      userData.isDeleted === true
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Account already withdrawn."
      );
    }

    const postRef = db.collection("posts").doc(postId);

    await db.runTransaction(async (transaction) => {
      const postSnapshot = await transaction.get(postRef);

      if (!postSnapshot.exists) {
        throw new HttpsError("not-found", "Post document does not exist.");
      }

      const postData = postSnapshot.data() || {};

      if (
        normalizeString(postData.status) !== "active" ||
        postData.deletedAt !== null ||
        postData.isHiddenByAdmin === true ||
        postData.isReportThresholdReached === true ||
        postData.adminRemovedAt !== null
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Post is not readable."
        );
      }

      transaction.update(postRef, {
        viewCount: admin.firestore.FieldValue.increment(1),
      });
    });

    return {
      ok: true,
      postId,
    };
  }
);
exports.togglePostLikeOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 10,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const postId = normalizeString(request.data && request.data.postId);

    if (!postId) {
      throw new HttpsError("invalid-argument", "postId is required.");
    }

    await assertCallableUserReady(resolved);

    const postRef = db.collection("posts").doc(postId);
    const likeId = `${postId}_${resolved.userId}`;
    const likeRef = db.collection("post_likes").doc(likeId);

    let liked = false;
    let likeCount = 0;

    await db.runTransaction(async (transaction) => {
      const postSnapshot = await transaction.get(postRef);

      if (!postSnapshot.exists) {
        throw new HttpsError("not-found", "Post document does not exist.");
      }

      const postData = postSnapshot.data() || {};

      if (!isReadablePostData(postData)) {
        throw new HttpsError(
          "failed-precondition",
          "Post is not available for like."
        );
      }

      const likeSnapshot = await transaction.get(likeRef);

      const previousLikedUserIds = Array.isArray(postData.likedUserIds)
        ? postData.likedUserIds
            .map((item) => normalizeString(item))
            .filter((item) => item)
        : [];

      const nextLikedUserIdsSet = new Set(previousLikedUserIds);
      const currentlyLiked =
        likeSnapshot.exists || nextLikedUserIdsSet.has(resolved.userId);

      if (currentlyLiked) {
        transaction.delete(likeRef);
        nextLikedUserIdsSet.delete(resolved.userId);
        liked = false;
      } else {
        transaction.set(likeRef, {
          id: likeId,
          postId,
          userId: resolved.userId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        nextLikedUserIdsSet.add(resolved.userId);
        liked = true;
      }

      const nextLikedUserIds = Array.from(nextLikedUserIdsSet);
      likeCount = nextLikedUserIds.length;

      transaction.update(postRef, {
        likedUserIds: nextLikedUserIds,
        likeCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {
      ok: true,
      postId,
      liked,
      likeCount,
    };
  }
);

exports.toggleCommentLikeOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 10,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const postId = normalizeString(request.data && request.data.postId);
    const commentId = normalizeString(request.data && request.data.commentId);

    if (!postId) {
      throw new HttpsError("invalid-argument", "postId is required.");
    }

    if (!commentId) {
      throw new HttpsError("invalid-argument", "commentId is required.");
    }

    await assertCallableUserReady(resolved);

    const commentRef = db.collection("comments").doc(commentId);
    const likeId = `${commentId}_${resolved.userId}`;
    const likeRef = db.collection("comment_likes").doc(likeId);

    let liked = false;
    let likeCount = 0;

    await db.runTransaction(async (transaction) => {
      const commentSnapshot = await transaction.get(commentRef);

      if (!commentSnapshot.exists) {
        throw new HttpsError("not-found", "Comment document does not exist.");
      }

      const commentData = commentSnapshot.data() || {};
      const commentPostId = normalizeString(commentData.postId);

      if (commentPostId !== postId) {
        throw new HttpsError("not-found", "Comment does not belong to post.");
      }

      if (!isReadableCommentData(commentData)) {
        throw new HttpsError(
          "failed-precondition",
          "Comment is not available for like."
        );
      }

      const likeSnapshot = await transaction.get(likeRef);

      const previousLikedUserIds = Array.isArray(commentData.likedUserIds)
        ? commentData.likedUserIds
            .map((item) => normalizeString(item))
            .filter((item) => item)
        : [];

      const nextLikedUserIdsSet = new Set(previousLikedUserIds);
      const currentlyLiked =
        likeSnapshot.exists || nextLikedUserIdsSet.has(resolved.userId);

      if (currentlyLiked) {
        transaction.delete(likeRef);
        nextLikedUserIdsSet.delete(resolved.userId);
        liked = false;
      } else {
        transaction.set(likeRef, {
          id: likeId,
          postId,
          commentId,
          userId: resolved.userId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        nextLikedUserIdsSet.add(resolved.userId);
        liked = true;
      }

      const nextLikedUserIds = Array.from(nextLikedUserIdsSet);
      likeCount = nextLikedUserIds.length;

      transaction.update(commentRef, {
        likedUserIds: nextLikedUserIds,
        likeCount,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return {
      ok: true,
      postId,
      commentId,
      liked,
      likeCount,
    };
  }
);
exports.addCommentOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 10,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const postId = normalizeString(request.data && request.data.postId);
    const text = normalizeCommentText(request.data && request.data.text);

    if (!postId) {
      throw new HttpsError("invalid-argument", "postId is required.");
    }

    if (!text) {
      throw new HttpsError("invalid-argument", "Comment text is required.");
    }

    await assertCallableUserReady(resolved);

    const userSnapshot = await resolved.userRef.get();

    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "User document does not exist.");
    }

    const userData = userSnapshot.data() || {};
    validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);

    const author = buildCommunityAuthorSnapshot({
      userId: resolved.userId,
      userData,
    });

    const postRef = db.collection("posts").doc(postId);
    const commentRef = db.collection("comments").doc();
    const nowIso = new Date().toISOString();

    let createdComment = null;

    await db.runTransaction(async (transaction) => {
      const postSnapshot = await transaction.get(postRef);

      if (!postSnapshot.exists) {
        throw new HttpsError("not-found", "Post document does not exist.");
      }

      const postData = postSnapshot.data() || {};

      if (!isReadablePostData(postData)) {
        throw new HttpsError(
          "failed-precondition",
          "Post is not available for comment."
        );
      }

      const comment = buildServerCommentData({
        commentId: commentRef.id,
        postId,
        parentId: null,
        author,
        text,
        nowIso,
      });

      transaction.set(commentRef, comment);

      transaction.update(postRef, {
        commentCount: admin.firestore.FieldValue.increment(1),
        updatedAt: nowIso,
      });

      createdComment = comment;
    });

    return {
      ok: true,
      postId,
      commentId: commentRef.id,
      comment: createdComment,
    };
  }
);

exports.addReplyOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 10,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const postId = normalizeString(request.data && request.data.postId);
    const parentCommentId = normalizeString(
      request.data && request.data.parentCommentId
    );
    const text = normalizeCommentText(request.data && request.data.text);

    if (!postId) {
      throw new HttpsError("invalid-argument", "postId is required.");
    }

    if (!parentCommentId) {
      throw new HttpsError(
        "invalid-argument",
        "parentCommentId is required."
      );
    }

    if (!text) {
      throw new HttpsError("invalid-argument", "Reply text is required.");
    }

    await assertCallableUserReady(resolved);

    const userSnapshot = await resolved.userRef.get();

    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "User document does not exist.");
    }

    const userData = userSnapshot.data() || {};
    validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);

    const author = buildCommunityAuthorSnapshot({
      userId: resolved.userId,
      userData,
    });

    const postRef = db.collection("posts").doc(postId);
    const parentCommentRef = db.collection("comments").doc(parentCommentId);
    const commentRef = db.collection("comments").doc();
    const nowIso = new Date().toISOString();

    let createdComment = null;

    await db.runTransaction(async (transaction) => {
      const postSnapshot = await transaction.get(postRef);

      if (!postSnapshot.exists) {
        throw new HttpsError("not-found", "Post document does not exist.");
      }

      const postData = postSnapshot.data() || {};

      if (!isReadablePostData(postData)) {
        throw new HttpsError(
          "failed-precondition",
          "Post is not available for reply."
        );
      }

      const parentSnapshot = await transaction.get(parentCommentRef);

      if (!parentSnapshot.exists) {
        throw new HttpsError("not-found", "Parent comment does not exist.");
      }

      const parentData = parentSnapshot.data() || {};
      const parentPostId = normalizeString(parentData.postId);

      if (parentPostId !== postId) {
        throw new HttpsError(
          "not-found",
          "Parent comment does not belong to post."
        );
      }

      if (!isReadableCommentData(parentData)) {
        throw new HttpsError(
          "failed-precondition",
          "Parent comment is not available for reply."
        );
      }

      const comment = buildServerCommentData({
        commentId: commentRef.id,
        postId,
        parentId: parentCommentId,
        author,
        text,
        nowIso,
      });

      transaction.set(commentRef, comment);

      transaction.update(postRef, {
        commentCount: admin.firestore.FieldValue.increment(1),
        updatedAt: nowIso,
      });

      createdComment = comment;
    });

    return {
      ok: true,
      postId,
      parentCommentId,
      commentId: commentRef.id,
      comment: createdComment,
    };
  }
);
exports.verifyBusinessOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 20,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
    secrets: [NTS_BUSINESS_SERVICE_KEY],
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const data = request.data || {};
    const businessNumber = normalizeBusinessNumber(data.businessNumber);
    const representativeName = normalizePersonName(data.representativeName);
    const openedAt = normalizeOpenedAt(data.openedAt);

    if (!businessNumber) {
      throw new HttpsError(
        "invalid-argument",
        "Business number must be 10 digits."
      );
    }

    if (!representativeName) {
      throw new HttpsError(
        "invalid-argument",
        "Representative name is required."
      );
    }

    if (!openedAt) {
      throw new HttpsError(
        "invalid-argument",
        "Opened date must be YYYYMMDD."
      );
    }

    if (!isValidBusinessNumberChecksum(businessNumber)) {
      throw new HttpsError(
        "invalid-argument",
        "Business number format is invalid."
      );
    }

    const userSnapshotBefore = await resolved.userRef.get();

    if (!userSnapshotBefore.exists) {
      throw new HttpsError("not-found", "User document does not exist.");
    }

    const userDataBefore = userSnapshotBefore.data() || {};
    validateUserBelongsToFirebaseUid(userDataBefore, resolved.firebaseUid);

    if (userDataBefore.profileSetupCompleted !== true) {
      throw new HttpsError(
        "failed-precondition",
        "Profile setup must be completed first."
      );
    }

    if (
      normalizeString(userDataBefore.status) === "withdrawn" ||
      userDataBefore.isDeleted === true
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Account already withdrawn."
      );
    }

    const verificationResult = await verifyBusinessWithNts({
      businessNumber,
      representativeName,
      openedAt,
    });

    if (!verificationResult.valid) {
      await db.runTransaction(async (transaction) => {
        const userSnapshot = await transaction.get(resolved.userRef);

        if (!userSnapshot.exists) {
          throw new HttpsError("not-found", "User document does not exist.");
        }

        const userData = userSnapshot.data() || {};
        validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);

        const currentBusiness = userData.business || {};
        const failureCount =
          typeof currentBusiness.failureCount === "number" &&
          Number.isFinite(currentBusiness.failureCount)
            ? currentBusiness.failureCount + 1
            : 1;

        transaction.set(
          resolved.userRef,
          {
            role: "user",
            business: {
              status: "failed",
              businessNumberHash: sha256Hex(businessNumber),
              businessNumberMasked: maskBusinessNumber(businessNumber),
              representativeNameHash: sha256Hex(representativeName),
              representativeNameMasked: maskPersonName(representativeName),
              openedAt,
              verifiedAt: null,
              failureCount,
              lockedUntil: null,
              ownershipSlot: null,
              lastFailureReason: verificationResult.reason || "not_matched",
              lastCheckedAt: now,
              ntsStatusCode: verificationResult.statusCode || null,
              ntsStatusMessage: verificationResult.statusMessage || null,
              ntsTaxType: verificationResult.taxType || null,
            },
            updatedAt: now,
          },
          {
            merge: true,
          }
        );
      });

      throw new HttpsError(
        "failed-precondition",
        verificationResult.message || "Business verification failed."
      );
    }

    await db.runTransaction(async (transaction) => {
      const userSnapshot = await transaction.get(resolved.userRef);

      if (!userSnapshot.exists) {
        throw new HttpsError("not-found", "User document does not exist.");
      }

      const userData = userSnapshot.data() || {};
      validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);

      if (userData.profileSetupCompleted !== true) {
        throw new HttpsError(
          "failed-precondition",
          "Profile setup must be completed first."
        );
      }

      if (
        normalizeString(userData.status) === "withdrawn" ||
        userData.isDeleted === true
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Account already withdrawn."
        );
      }

      const business = userData.business || {};
      const previousOwnershipSlot =
        typeof business.ownershipSlot === "number" &&
        Number.isFinite(business.ownershipSlot)
          ? business.ownershipSlot
          : 1;

      transaction.set(
        resolved.userRef,
        {
          role: "owner",
          business: {
            status: "verified",
            businessNumberHash: sha256Hex(businessNumber),
            businessNumberMasked: maskBusinessNumber(businessNumber),
            representativeNameHash: sha256Hex(representativeName),
            representativeNameMasked: maskPersonName(representativeName),
            openedAt,
            verifiedAt: now,
            failureCount: 0,
            lockedUntil: null,
            ownershipSlot: previousOwnershipSlot,
            ntsStatusCode: verificationResult.statusCode || null,
            ntsStatusMessage: verificationResult.statusMessage || null,
            ntsTaxType: verificationResult.taxType || null,
            lastFailureReason: null,
            lastCheckedAt: now,
          },
          updatedAt: now,
        },
        {
          merge: true,
        }
      );
    });

    const userSnapshot = await resolved.userRef.get();
    const userData = userSnapshot.data() || {};

    logger.info("Business verified by NTS API without identity precheck", {
      firebaseUid: resolved.firebaseUid,
      internalUserId: resolved.userId,
      businessNumberMasked: maskBusinessNumber(businessNumber),
      representativeNameMasked: maskPersonName(representativeName),
      ntsStatusCode: verificationResult.statusCode || null,
    });

    return buildAppUserResponse(userData, {
      fallbackUserId: resolved.userId,
      fallbackFirebaseUid: resolved.firebaseUid,
      fallbackProvider: "firebase",
    });
  }
);
async function anonymizeWithdrawnUserCommunityContent({
  userId,
  now,
}) {
  const safeUserId = normalizeString(userId);

  if (!safeUserId) {
    return {
      posts: 0,
      comments: 0,
    };
  }

  const posts = await anonymizeWithdrawnUserAuthorFields({
    collectionName: "posts",
    userId: safeUserId,
    now,
  });

  const comments = await anonymizeWithdrawnUserAuthorFields({
    collectionName: "comments",
    userId: safeUserId,
    now,
  });

  return {
    posts,
    comments,
  };
}

async function anonymizeWithdrawnUserAuthorFields({
  collectionName,
  userId,
  now,
}) {
  const safeCollectionName = normalizeString(collectionName);
  const safeUserId = normalizeString(userId);

  if (!safeCollectionName || !safeUserId) {
    return 0;
  }

  let total = 0;
  let lastDocument = null;
  const pageSize = 400;

  while (true) {
    let query = db
      .collection(safeCollectionName)
      .where("authorId", "==", safeUserId)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(pageSize);

    if (lastDocument) {
      query = query.startAfter(lastDocument);
    }

    const snapshot = await query.get();

    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();

    snapshot.docs.forEach((documentSnapshot) => {
      batch.set(
        documentSnapshot.ref,
        {
          authorLabel: "탈퇴사용자",
          isOwnerVerified: false,
          industryId: null,
          locationLabel: null,
          updatedAt: now,
        },
        {
          merge: true,
        }
      );
    });

    await batch.commit();

    total += snapshot.size;
    lastDocument = snapshot.docs[snapshot.docs.length - 1];

    if (snapshot.size < pageSize) {
      break;
    }
  }

  return total;
}

async function fetchKakaoUser(accessToken) {
  try {
    const response = await axios.get(KAKAO_USER_ME_URL, {
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
      },
      timeout: 10000,
    });

    return response.data;
  } catch (error) {
    const status = error && error.response ? error.response.status : null;
    const data = error && error.response ? error.response.data : null;

    logger.warn("Kakao user lookup failed", {
      status,
      data,
    });

    throw new HttpsError(
      "unauthenticated",
      "Kakao accessToken verification failed."
    );
  }
}

async function verifyBusinessWithNts({
  businessNumber,
  representativeName,
  openedAt,
}) {
  const serviceKey = normalizeString(NTS_BUSINESS_SERVICE_KEY.value());

  if (!serviceKey) {
    throw new HttpsError(
      "failed-precondition",
      "NTS service key is not configured."
    );
  }

  try {
    const response = await axios.post(
      `${NTS_BUSINESS_VALIDATE_URL}?serviceKey=${encodeURIComponent(
        serviceKey
      )}`,
      {
        businesses: [
          {
            b_no: businessNumber,
            start_dt: openedAt,
            p_nm: representativeName,
            p_nm2: "",
            b_nm: "",
            corp_no: "",
            b_sector: "",
            b_type: "",
          },
        ],
      },
      {
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
        },
        timeout: 12000,
      }
    );

    const body = response.data || {};
    const dataList = Array.isArray(body.data) ? body.data : [];
    const first = dataList.length > 0 ? dataList[0] || {} : {};

    const valid = normalizeString(first.valid);
    const validMsg = normalizeString(first.valid_msg);
    const status =
      first.status && typeof first.status === "object" ? first.status : {};

    const statusCode = normalizeString(status.b_stt_cd);
    const statusMessage = normalizeString(status.b_stt);
    const taxType = normalizeString(status.tax_type);

    if (valid === "01") {
      return {
        valid: true,
        statusCode,
        statusMessage,
        taxType,
      };
    }

    return {
      valid: false,
      reason: valid || "not_matched",
      message:
        validMsg || "Business information does not match.",
      statusCode,
      statusMessage,
      taxType,
    };
  } catch (error) {
    const status = error && error.response ? error.response.status : null;
    const data = error && error.response ? error.response.data : null;

    logger.warn("NTS business verification failed", {
      status,
      data,
    });

    throw new HttpsError("unavailable", "Business verification service is temporarily unavailable. Please try again later.");
  }
}

async function ensureUserProfile({
  firebaseUid,
  provider,
  email,
  displayName,
  photoUrl,
}) {
  const safeFirebaseUid = normalizeString(firebaseUid);
  const safeProvider = normalizeProvider(provider) || "firebase";
  const safeEmail = normalizeString(email) || null;
  const safeDisplayName = normalizeString(displayName) || null;
  const safePhotoUrl = normalizeString(photoUrl) || null;

  if (!safeFirebaseUid) {
    throw new HttpsError("invalid-argument", "firebaseUid is required.");
  }

  const linkRef = db.collection("auth_links").doc(safeFirebaseUid);
  const now = admin.firestore.FieldValue.serverTimestamp();

  let resolvedUserId = "";

  await db.runTransaction(async (transaction) => {
    const linkSnapshot = await transaction.get(linkRef);

    if (linkSnapshot.exists) {
      const linkData = linkSnapshot.data() || {};
      const existingUserId = normalizeString(linkData.userId);

      if (!existingUserId) {
        throw new HttpsError(
          "data-loss",
          "auth_links document exists but userId is empty."
        );
      }

      resolvedUserId = existingUserId;

      const userRef = db.collection("users").doc(existingUserId);
      const userSnapshot = await transaction.get(userRef);
      const userData = userSnapshot.exists ? userSnapshot.data() || {} : {};

      if (
        normalizeString(userData.status) === "withdrawn" ||
        userData.isDeleted === true
      ) {
        transaction.delete(linkRef);

        const newUserId = createInternalUserId();
        resolvedUserId = newUserId;

        const newUserRef = db.collection("users").doc(newUserId);

        transaction.set(linkRef, {
          firebaseUid: safeFirebaseUid,
          userId: newUserId,
          provider: safeProvider,
          createdAt: now,
          updatedAt: now,
          lastLoginAt: now,
        });

        transaction.set(
          newUserRef,
          removeUndefinedFields({
            userId: newUserId,
            firebaseUid: safeFirebaseUid,
            provider: safeProvider,
            email: safeEmail,
            displayName: safeDisplayName,
            photoUrl: safePhotoUrl,
            role: "user",
            identity: {
              status: "none",
              verifiedAt: null,
              provider: null,
              verifiedNameHash: null,
              verifiedNameMasked: null,
              failureCount: 0,
              lockedUntil: null,
            },
            business: {
              status: "none",
              businessNumberHash: null,
              businessNumberMasked: null,
              representativeNameHash: null,
              representativeNameMasked: null,
              openedAt: null,
              verifiedAt: null,
              failureCount: 0,
              lockedUntil: null,
              ownershipSlot: null,
              lastFailureReason: null,
              lastCheckedAt: null,
            },
            profileSetupCompleted: false,
            terms: {
              agreed: false,
              agreedAt: null,
              version: null,
            },
            notificationConsent: {
              pushAgreed: false,
              pushAgreedAt: null,
              pushVersion: null,
              updatedAt: null,
            },
            storeProfile: {
              nickname: null,
              nicknameKey: null,
              industry: null,
              region: null,
              createdAt: null,
              updatedAt: null,
            },
            createdAt: now,
            updatedAt: now,
            lastLoginAt: now,
            status: "active",
            isDeleted: false,
            sanctionStatus: "normal",
          })
        );

        return;
      }

      transaction.set(
        linkRef,
        {
          firebaseUid: safeFirebaseUid,
          userId: existingUserId,
          provider: safeProvider,
          updatedAt: now,
          lastLoginAt: now,
        },
        {
          merge: true,
        }
      );

      transaction.set(
        userRef,
        removeUndefinedFields({
          userId: existingUserId,
          firebaseUid: safeFirebaseUid,
          provider: safeProvider,
          email: safeEmail,
          displayName: safeDisplayName,
          photoUrl: safePhotoUrl,
          role: normalizeString(userData.role) || "user",
          identity: normalizeIdentity(userData.identity),
          business: normalizeBusiness(userData.business),
          profileSetupCompleted:
            typeof userData.profileSetupCompleted === "boolean"
              ? userData.profileSetupCompleted
              : false,
          terms: normalizeTerms(userData.terms),
          notificationConsent: normalizeNotificationConsent(
            userData.notificationConsent
          ),
          storeProfile: normalizeStoreProfile(userData.storeProfile),
          status: normalizeString(userData.status) || "active",
          isDeleted:
            typeof userData.isDeleted === "boolean" ? userData.isDeleted : false,
          sanctionStatus:
            normalizeString(userData.sanctionStatus) || "normal",
          updatedAt: now,
          lastLoginAt: now,
        }),
        {
          merge: true,
        }
      );

      return;
    }

    const newUserId = createInternalUserId();
    resolvedUserId = newUserId;

    const userRef = db.collection("users").doc(newUserId);

    transaction.set(linkRef, {
      firebaseUid: safeFirebaseUid,
      userId: newUserId,
      provider: safeProvider,
      createdAt: now,
      updatedAt: now,
      lastLoginAt: now,
    });

    transaction.set(
      userRef,
      removeUndefinedFields({
        userId: newUserId,
        firebaseUid: safeFirebaseUid,
        provider: safeProvider,
        email: safeEmail,
        displayName: safeDisplayName,
        photoUrl: safePhotoUrl,
        role: "user",
        identity: {
          status: "none",
          verifiedAt: null,
          provider: null,
          verifiedNameHash: null,
          verifiedNameMasked: null,
          failureCount: 0,
          lockedUntil: null,
        },
        business: {
          status: "none",
          businessNumberHash: null,
          businessNumberMasked: null,
          representativeNameHash: null,
          representativeNameMasked: null,
          openedAt: null,
          verifiedAt: null,
          failureCount: 0,
          lockedUntil: null,
          ownershipSlot: null,
          lastFailureReason: null,
          lastCheckedAt: null,
        },
        profileSetupCompleted: false,
        terms: {
          agreed: false,
          agreedAt: null,
          version: null,
        },
        notificationConsent: {
          pushAgreed: false,
          pushAgreedAt: null,
          pushVersion: null,
          updatedAt: null,
        },
        storeProfile: {
          nickname: null,
          nicknameKey: null,
          industry: null,
          region: null,
          createdAt: null,
          updatedAt: null,
        },
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
        status: "active",
        isDeleted: false,
        sanctionStatus: "normal",
      })
    );
  });

  if (!resolvedUserId) {
    throw new HttpsError("internal", "Failed to resolve internal userId.");
  }

  const userSnapshot = await db.collection("users").doc(resolvedUserId).get();
  const userData = userSnapshot.data() || {};
  const identity = userData.identity || {};
  const business = userData.business || {};
  const terms = userData.terms || {};
  const storeProfile = userData.storeProfile || {};

  return {
    userId: normalizeString(userData.userId) || resolvedUserId,
    firebaseUid: normalizeString(userData.firebaseUid) || safeFirebaseUid,
    provider: normalizeProvider(userData.provider) || safeProvider,
    role: normalizeString(userData.role) || "user",
    identityStatus: normalizeString(identity.status) || "none",
    businessStatus: normalizeString(business.status) || "none",
    profileSetupCompleted: userData.profileSetupCompleted === true,
    termsAgreed: terms.agreed === true,
    nickname: normalizeString(storeProfile.nickname),
    industry: normalizeString(storeProfile.industry),
    region: normalizeString(storeProfile.region),
  };
}

async function resolveCurrentUserForCallable(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Firebase authentication is required."
    );
  }

  const firebaseUid = request.auth.uid;
  const linkRef = db.collection("auth_links").doc(firebaseUid);
  const linkSnapshot = await linkRef.get();

  if (!linkSnapshot.exists) {
    throw new HttpsError("not-found", "Auth link document does not exist.");
  }

  const linkData = linkSnapshot.data() || {};
  const userId = normalizeString(linkData.userId);

  if (!userId) {
    throw new HttpsError(
      "data-loss",
      "auth_links document exists but userId is empty."
    );
  }

  return {
    firebaseUid,
    userId,
    userRef: db.collection("users").doc(userId),
  };
}

async function assertCallableUserReady(resolved) {
  const userSnapshot = await resolved.userRef.get();

  if (!userSnapshot.exists) {
    throw new HttpsError("not-found", "User document does not exist.");
  }

  const userData = userSnapshot.data() || {};
  validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);

  if (userData.profileSetupCompleted !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Profile setup must be completed first."
    );
  }

  if (
    normalizeString(userData.status) === "withdrawn" ||
    userData.isDeleted === true
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Account already withdrawn."
    );
  }
}

function isReadablePostData(postData) {
  return normalizeString(postData.status) === "active"
    && postData.deletedAt === null
    && postData.isHiddenByAdmin === false
    && postData.isReportThresholdReached === false
    && postData.adminRemovedAt === null;
}

function isReadableCommentData(commentData) {
  return normalizeString(commentData.status) === "active"
    && commentData.isDeleted === false
    && commentData.deletedAt === null
    && commentData.isHiddenByAdmin === false
    && commentData.isReportThresholdReached === false
    && commentData.adminRemovedAt === null;
}
function normalizeCommentText(value) {
  const text = normalizeString(value);

  if (!text) {
    return "";
  }

  if (text.length > 500) {
    throw new HttpsError(
      "invalid-argument",
      "Comment text must be 500 characters or less."
    );
  }

  return text;
}

function buildCommunityAuthorSnapshot({
  userId,
  userData,
}) {
  const storeProfile =
    userData && typeof userData.storeProfile === "object"
      ? userData.storeProfile
      : {};

  const business =
    userData && typeof userData.business === "object"
      ? userData.business
      : {};

  const authorLabel = normalizeString(storeProfile.nickname);
  const industryId = normalizeString(storeProfile.industry) || null;
  const locationLabel = normalizeString(storeProfile.region) || null;
  const isOwnerVerified = normalizeString(business.status) === "verified";

  if (!authorLabel) {
    throw new HttpsError(
      "failed-precondition",
      "Profile setup must be completed first."
    );
  }

  return {
    authorId: userId,
    authorLabel,
    isOwnerVerified,
    industryId,
    locationLabel,
  };
}

function buildServerCommentData({
  commentId,
  postId,
  parentId,
  author,
  text,
  nowIso,
}) {
  return {
    id: commentId,
    postId,
    authorId: author.authorId,
    authorLabel: author.authorLabel,
    isOwnerVerified: author.isOwnerVerified,
    industryId: author.industryId,
    locationLabel: author.locationLabel,
    text,
    parentId,
    likeCount: 0,
    likedUserIds: [],
    reportCount: 0,
    reportedUserIds: [],
    reportReasons: [],
    reportReasonCounts: {},
    isReportThresholdReached: false,
    isHiddenByAdmin: false,
    adminHiddenReason: null,
    adminHiddenAt: null,
    adminRemovedAt: null,
    adminRemovedReason: null,
    isDeleted: false,
    status: "active",
    createdAt: nowIso,
    updatedAt: nowIso,
    deletedAt: null,
  };
}
function validateUserBelongsToFirebaseUid(userData, firebaseUid) {
  const userFirebaseUid = normalizeString(userData.firebaseUid);

  if (userFirebaseUid !== firebaseUid) {
    throw new HttpsError(
      "permission-denied",
      "User document does not belong to current Firebase user."
    );
  }
}

function buildAppUserResponse(
  userData,
  { fallbackUserId, fallbackFirebaseUid, fallbackProvider }
) {
  const identity = userData.identity || {};
  const business = userData.business || {};
  const terms = userData.terms || {};
  const storeProfile = userData.storeProfile || {};

  return {
    userId: normalizeString(userData.userId) || fallbackUserId || "",
    firebaseUid:
      normalizeString(userData.firebaseUid) || fallbackFirebaseUid || "",
    provider:
      normalizeProvider(userData.provider) || fallbackProvider || "firebase",
    email: normalizeString(userData.email) || null,
    displayName: normalizeString(userData.displayName) || null,
    photoUrl: normalizeString(userData.photoUrl) || null,
    role: normalizeString(userData.role) || "user",
    identityStatus: normalizeString(identity.status) || "none",
    businessStatus: normalizeString(business.status) || "none",
    profileSetupCompleted: userData.profileSetupCompleted === true,
    termsAgreed: terms.agreed === true,
    nickname: normalizeString(storeProfile.nickname) || null,
    industry: normalizeString(storeProfile.industry) || null,
    region: normalizeString(storeProfile.region) || null,
  };
}

function normalizeIdentity(value) {
  const src = value && typeof value === "object" ? value : {};

  return {
    status: normalizeString(src.status) || "none",
    verifiedAt: src.verifiedAt || null,
    provider: normalizeString(src.provider) || null,
    verifiedNameHash: normalizeString(src.verifiedNameHash) || null,
    verifiedNameMasked: normalizeString(src.verifiedNameMasked) || null,
    failureCount:
      typeof src.failureCount === "number" && Number.isFinite(src.failureCount)
        ? src.failureCount
        : 0,
    lockedUntil: src.lockedUntil || null,
  };
}

function normalizeBusiness(value) {
  const src = value && typeof value === "object" ? value : {};

  return {
    status: normalizeString(src.status) || "none",
    businessNumberHash: normalizeString(src.businessNumberHash) || null,
    businessNumberMasked: normalizeString(src.businessNumberMasked) || null,
    representativeNameHash:
      normalizeString(src.representativeNameHash) || null,
    representativeNameMasked:
      normalizeString(src.representativeNameMasked) || null,
    openedAt: src.openedAt || null,
    verifiedAt: src.verifiedAt || null,
    failureCount:
      typeof src.failureCount === "number" && Number.isFinite(src.failureCount)
        ? src.failureCount
        : 0,
    lockedUntil: src.lockedUntil || null,
    ownershipSlot:
      typeof src.ownershipSlot === "number" && Number.isFinite(src.ownershipSlot)
        ? src.ownershipSlot
        : null,
    lastFailureReason: normalizeString(src.lastFailureReason) || null,
    lastCheckedAt: src.lastCheckedAt || null,
  };
}

function normalizeTerms(value) {
  const src = value && typeof value === "object" ? value : {};

  return {
    agreed: src.agreed === true,
    agreedAt: src.agreedAt || null,
    version: normalizeString(src.version) || null,
  };
}

function normalizeNotificationConsent(value) {
  const src = value && typeof value === "object" ? value : {};

  return {
    pushAgreed: src.pushAgreed === true,
    pushAgreedAt: src.pushAgreedAt || null,
    pushVersion: normalizeString(src.pushVersion) || null,
    updatedAt: src.updatedAt || null,
  };
}

function normalizeStoreProfile(value) {
  const src = value && typeof value === "object" ? value : {};
  const nickname = normalizeString(src.nickname) || null;
  const nicknameKey =
    normalizeString(src.nicknameKey) ||
    createNicknameKeyForExistingValue(nickname);

  return {
    nickname,
    nicknameKey: nicknameKey || null,
    industry: normalizeString(src.industry) || null,
    region: normalizeString(src.region) || null,
    createdAt: src.createdAt || null,
    updatedAt: src.updatedAt || null,
  };
}

function normalizeNickname(value) {
  const nickname = normalizeString(value).replace(/\s+/g, "");

  if (!nickname) {
    throw new HttpsError("invalid-argument", "Nickname is required.");
  }

  if (nickname.length < NICKNAME_MIN_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Nickname must be at least ${NICKNAME_MIN_LENGTH} characters.`
    );
  }

  if (nickname.length > NICKNAME_MAX_LENGTH) {
    throw new HttpsError(
      "invalid-argument",
      `Nickname must be ${NICKNAME_MAX_LENGTH} characters or less.`
    );
  }

  if (!/^[\uAC00-\uD7A3a-zA-Z0-9_]+$/.test(nickname)) {
    throw new HttpsError(
      "invalid-argument",
      "Nickname format is invalid."
    );
  }

  const nicknameKey = createNicknameKey(nickname);

  if (RESERVED_NICKNAME_KEYS.has(nicknameKey)) {
    throw new HttpsError(
      "invalid-argument",
      "Nickname is reserved."
    );
  }

  for (const blocked of BLOCKED_NICKNAME_KEYWORDS) {
    if (nicknameKey.includes(blocked)) {
      throw new HttpsError(
        "invalid-argument",
        "Nickname contains blocked words."
      );
    }
  }

  return nickname;
}

function createNicknameKey(nickname) {
  const key = normalizeString(nickname)
    .replace(/\s+/g, "")
    .toLowerCase();

  if (!key) {
    throw new HttpsError("invalid-argument", "Nickname is required.");
  }

  return key;
}

function createNicknameKeyForExistingValue(value) {
  const key = normalizeString(value)
    .replace(/\s+/g, "")
    .toLowerCase();

  if (!key) {
    return "";
  }
  if (key === "탈퇴사용자") {
    return "";
  }

  return key;
}

function assertNicknameAvailable({
  nicknameSnapshot,
  userId,
}) {
  if (!nicknameSnapshot.exists) {
    return;
  }

  const data = nicknameSnapshot.data() || {};
  const ownerUserId = normalizeString(data.userId);

  if (ownerUserId === userId) {
    return;
  }

  throw new HttpsError(
    "already-exists",
    "Nickname already exists."
  );
}

function reserveNickname({
  transaction,
  nicknameRef,
  userId,
  firebaseUid,
  nickname,
  nicknameKey,
  now,
}) {
  transaction.set(
    nicknameRef,
    {
      userId,
      firebaseUid,
      nickname,
      nicknameKey,
      updatedAt: now,
      createdAt: now,
    },
    {
      merge: true,
    }
  );
}

function normalizeProfileText(value, fieldName, maxLength) {
  const text = normalizeString(value);

  if (!text) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} is required.`
    );
  }

  if (text.length > maxLength) {
    throw new HttpsError(
      "invalid-argument",
      `${fieldName} must be ${maxLength} characters or less.`
    );
  }

  return text;
}

function normalizeKakaoId(value) {
  if (value === null || value === undefined) {
    return "";
  }

  return String(value).trim();
}

function normalizeBusinessNumber(value) {
  if (value === null || value === undefined) {
    return "";
  }

  const digits = String(value).replace(/\D/g, "").trim();

  if (!/^\d{10}$/.test(digits)) {
    return "";
  }

  return digits;
}

function normalizeOpenedAt(value) {
  if (value === null || value === undefined) {
    return "";
  }

  const digits = String(value).replace(/\D/g, "").trim();

  if (!/^\d{8}$/.test(digits)) {
    return "";
  }

  const year = Number(digits.slice(0, 4));
  const month = Number(digits.slice(4, 6));
  const day = Number(digits.slice(6, 8));

  if (
    !Number.isInteger(year) ||
    !Number.isInteger(month) ||
    !Number.isInteger(day)
  ) {
    return "";
  }

  if (year < 1900 || year > 2100) {
    return "";
  }

  if (month < 1 || month > 12) {
    return "";
  }

  const lastDayOfMonth = new Date(year, month, 0).getDate();

  if (day < 1 || day > lastDayOfMonth) {
    return "";
  }

  const now = new Date();
  const todayNumber =
    now.getFullYear() * 10000 + (now.getMonth() + 1) * 100 + now.getDate();

  const inputNumber = year * 10000 + month * 100 + day;

  if (inputNumber > todayNumber) {
    return "";
  }

  return digits;
}

function normalizePersonName(value) {
  const text = normalizeString(value).replace(/\s+/g, "");

  if (!text || text.length < 2 || text.length > 40) {
    return "";
  }

  return text;
}

function normalizeString(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim();
}

function normalizeProvider(value) {
  const text = normalizeString(value);

  if (!text) {
    return "";
  }

  if (text === "google.com") {
    return "google";
  }

  if (text === "apple.com") {
    return "apple";
  }

  if (text === "password") {
    return "password";
  }

  if (text === "custom") {
    return "custom";
  }

  if (text === "kakao") {
    return "kakao";
  }

  if (text === "google" || text === "apple" || text === "firebase") {
    return text;
  }

  return text;
}

function resolveProvider(signInProvider) {
  const provider = normalizeProvider(signInProvider);

  if (provider) {
    return provider;
  }

  return "firebase";
}

function createInternalUserId() {
  const millis = Date.now();
  const random = crypto.randomBytes(6).toString("hex");
  return `usr_${millis}_${random}`;
}

function isValidBusinessNumberChecksum(value) {
  const digits = normalizeBusinessNumber(value);

  if (!digits) {
    return false;
  }

  const numbers = digits.split("").map((item) => Number(item));
  const weights = [1, 3, 7, 1, 3, 7, 1, 3];

  let sum = 0;

  for (let i = 0; i < weights.length; i += 1) {
    sum += numbers[i] * weights[i];
  }

  const ninth = numbers[8] * 5;
  sum += Math.floor(ninth / 10);
  sum += ninth % 10;

  const check = (10 - (sum % 10)) % 10;

  return check === numbers[9];
}

function maskBusinessNumber(value) {
  const digits = normalizeBusinessNumber(value);

  if (!digits) {
    return null;
  }

  return `${digits.slice(0, 3)}-${digits.slice(3, 5)}-${digits.slice(5)}`;
}

function maskPersonName(value) {
  const name = normalizePersonName(value);

  if (!name) {
    return null;
  }

  if (name.length === 2) {
    return `${name.slice(0, 1)}*`;
  }

  return `${name.slice(0, 1)}${"*".repeat(name.length - 1)}`;
}

function sha256Hex(value) {
  return crypto
    .createHash("sha256")
    .update(String(value || ""), "utf8")
    .digest("hex");
}

function removeUndefinedFields(input) {
  const output = {};

  Object.keys(input).forEach((key) => {
    const value = input[key];

    if (value !== undefined) {
      output[key] = value;
    }
  });

  return output;
}
exports.acknowledgeLatestWarningOnServer =
  community.acknowledgeLatestWarningOnServer;









