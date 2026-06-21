const axios = require("axios");
const crypto = require("crypto");
const admin = require("firebase-admin");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");

admin.initializeApp();

const db = admin.firestore();

const NTS_BUSINESS_SERVICE_KEY = defineSecret("NTS_BUSINESS_SERVICE_KEY");

const KAKAO_USER_ME_URL = "https://kapi.kakao.com/v2/user/me";
const NTS_BUSINESS_VALIDATE_URL =
  "https://api.odcloud.kr/api/nts-businessman/v1/validate";

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

    const nickname = normalizeNickname(data.nickname);
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

      const userData = userSnapshot.data() || {};
      const userFirebaseUid = normalizeString(userData.firebaseUid);

      if (userFirebaseUid !== firebaseUid) {
        throw new HttpsError(
          "permission-denied",
          "User document does not belong to current Firebase user."
        );
      }

      transaction.set(
        userRef,
        {
          profileSetupCompleted: true,
          terms: {
            agreed: true,
            agreedAt: now,
            version: termsVersion,
          },
          storeProfile: {
            nickname,
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

    logger.info("User profile setup completed", {
      firebaseUid,
      internalUserId: resolvedUserId,
      nickname,
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

      transaction.set(
        userRef,
        {
          storeProfile: {
            nickname,
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

exports.mockVerifyIdentityOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const data = request.data || {};
    const verifiedName = normalizePersonName(data.name);

    if (!verifiedName) {
      throw new HttpsError(
        "invalid-argument",
        "Identity verified name is required."
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

      transaction.set(
        resolved.userRef,
        {
          identity: {
            status: "verified",
            verifiedAt: now,
            provider: "dev_mock",
            verifiedNameHash: sha256Hex(verifiedName),
            verifiedNameMasked: maskPersonName(verifiedName),
            failureCount: 0,
            lockedUntil: null,
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

    logger.info("Identity verified by server dev mock", {
      firebaseUid: resolved.firebaseUid,
      internalUserId: resolved.userId,
      verifiedNameMasked: maskPersonName(verifiedName),
    });

    return buildAppUserResponse(userData, {
      fallbackUserId: resolved.userId,
      fallbackFirebaseUid: resolved.firebaseUid,
      fallbackProvider: "firebase",
    });
  }
);

exports.mockVerifyBusinessOnServer = onCall(
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

    const identity = userDataBefore.identity || {};
    const identityStatus = normalizeString(identity.status) || "none";
    const verifiedNameHash = normalizeString(identity.verifiedNameHash);

    if (identityStatus !== "verified") {
      throw new HttpsError(
        "failed-precondition",
        "Identity verification must be completed first."
      );
    }

    if (!verifiedNameHash) {
      throw new HttpsError(
        "failed-precondition",
        "Identity verified name is required."
      );
    }

    if (verifiedNameHash !== sha256Hex(representativeName)) {
      throw new HttpsError(
        "failed-precondition",
        "Identity name and business representative name do not match."
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

      const userIdentity = userData.identity || {};
      const userIdentityStatus = normalizeString(userIdentity.status) || "none";
      const userVerifiedNameHash = normalizeString(
        userIdentity.verifiedNameHash
      );

      if (userIdentityStatus !== "verified") {
        throw new HttpsError(
          "failed-precondition",
          "Identity verification must be completed first."
        );
      }

      if (!userVerifiedNameHash) {
        throw new HttpsError(
          "failed-precondition",
          "Identity verified name is required."
        );
      }

      if (userVerifiedNameHash !== sha256Hex(representativeName)) {
        throw new HttpsError(
          "failed-precondition",
          "Identity name and business representative name do not match."
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

    logger.info("Business verified by NTS API", {
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

exports.mockUnverifyIdentityOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const now = admin.firestore.FieldValue.serverTimestamp();

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

      transaction.set(
        resolved.userRef,
        {
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
          updatedAt: now,
        },
        {
          merge: true,
        }
      );
    });

    const userSnapshot = await resolved.userRef.get();
    const userData = userSnapshot.data() || {};

    logger.info("Identity unverified by server dev mock", {
      firebaseUid: resolved.firebaseUid,
      internalUserId: resolved.userId,
    });

    return buildAppUserResponse(userData, {
      fallbackUserId: resolved.userId,
      fallbackFirebaseUid: resolved.firebaseUid,
      fallbackProvider: "firebase",
    });
  }
);

exports.mockUnverifyBusinessOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const now = admin.firestore.FieldValue.serverTimestamp();

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

      transaction.set(
        resolved.userRef,
        {
          role: "user",
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
          updatedAt: now,
        },
        {
          merge: true,
        }
      );
    });

    const userSnapshot = await resolved.userRef.get();
    const userData = userSnapshot.data() || {};

    logger.info("Business unverified by server dev mock", {
      firebaseUid: resolved.firebaseUid,
      internalUserId: resolved.userId,
    });

    return buildAppUserResponse(userData, {
      fallbackUserId: resolved.userId,
      fallbackFirebaseUid: resolved.firebaseUid,
      fallbackProvider: "firebase",
    });
  }
);

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
        validMsg || "입력한 사업자 정보가 국세청 정보와 일치하지 않습니다.",
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

    throw new HttpsError(
      "unavailable",
      "사업자 인증 서버가 일시적으로 불안정합니다. 잠시 후 다시 시도해주세요."
    );
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
          storeProfile: normalizeStoreProfile(userData.storeProfile),
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
        storeProfile: {
          nickname: null,
          industry: null,
          region: null,
          createdAt: null,
          updatedAt: null,
        },
        createdAt: now,
        updatedAt: now,
        lastLoginAt: now,
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

function normalizeStoreProfile(value) {
  const src = value && typeof value === "object" ? value : {};

  return {
    nickname: normalizeString(src.nickname) || null,
    industry: normalizeString(src.industry) || null,
    region: normalizeString(src.region) || null,
    createdAt: src.createdAt || null,
    updatedAt: src.updatedAt || null,
  };
}

function normalizeNickname(value) {
  const nickname = normalizeString(value);

  if (!nickname) {
    throw new HttpsError("invalid-argument", "Nickname is required.");
  }

  if (nickname.length < 2) {
    throw new HttpsError(
      "invalid-argument",
      "Nickname must be at least 2 characters."
    );
  }

  if (nickname.length > 12) {
    throw new HttpsError(
      "invalid-argument",
      "Nickname must be 12 characters or less."
    );
  }

  return nickname;
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