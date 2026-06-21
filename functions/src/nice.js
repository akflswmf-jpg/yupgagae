const crypto = require("crypto");
const admin = require("firebase-admin");
const { HttpsError, onCall, onRequest } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");
const { defineSecret } = require("firebase-functions/params");

const db = admin.firestore();

const NICE_IDENTITY_AUTH_URL = defineSecret("NICE_IDENTITY_AUTH_URL");
const NICE_IDENTITY_DEV_MODE = defineSecret("NICE_IDENTITY_DEV_MODE");
const NICE_CALLBACK_SHARED_SECRET = defineSecret("NICE_CALLBACK_SHARED_SECRET");

/**
 * NICE 본인인증 시작 요청.
 *
 * 현재 역할:
 * - 로그인 사용자 확인
 * - 가입 설정 완료 여부 확인
 * - 이미 인증 완료된 계정 방어
 * - identityVerificationRequests 요청 문서 생성
 * - 외부 인증 URL 반환
 *
 * 실제 NICE 계약 후:
 * - NICE 요청 전문 생성
 * - requestId/state 매핑
 * - NICE 인증 URL에 암호화 요청값 포함
 */
exports.requestNiceIdentityVerificationOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
    secrets: [NICE_IDENTITY_AUTH_URL],
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const userSnapshot = await resolved.userRef.get();

    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "User document does not exist.");
    }

    const userData = userSnapshot.data() || {};
    validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);

    validateAccountCanRequestIdentityVerification(userData);

    const identity = userData.identity || {};
    const identityStatus = normalizeString(identity.status) || "none";

    if (identityStatus === "verified") {
      throw new HttpsError(
        "already-exists",
        "Identity verification is already completed."
      );
    }

    const baseAuthUrl = normalizeString(NICE_IDENTITY_AUTH_URL.value());

    if (!baseAuthUrl) {
      throw new HttpsError(
        "failed-precondition",
        "NICE identity verification is not configured."
      );
    }

    const requestId = createNiceRequestId();
    const nonce = createNonce();
    const requestHash = sha256Hex(`${resolved.userId}:${requestId}:${nonce}`);

    const requestRef = resolved.userRef
      .collection("identityVerificationRequests")
      .doc(requestId);

    await requestRef.set({
      requestId,
      nonce,
      requestHash,
      provider: "nice",
      status: "requested",
      firebaseUid: resolved.firebaseUid,
      userId: resolved.userId,
      createdAt: now,
      updatedAt: now,
      completedAt: null,
      returnedAt: null,
      failedAt: null,
      failureReason: null,
      callbackRaw: null,
    });

    const authUrl = appendQueryParams(baseAuthUrl, {
      requestId,
      userId: resolved.userId,
      state: requestHash,
    });

    logger.info("NICE identity verification requested", {
      firebaseUid: resolved.firebaseUid,
      internalUserId: resolved.userId,
      requestId,
    });

    return {
      requestId,
      provider: "nice",
      authUrl,
    };
  }
);

/**
 * 실제 NICE callback 수신 엔드포인트.
 *
 * 중요:
 * 이 함수는 callback을 "수신/기록"만 한다.
 * 현재 단계에서는 NICE 공식 응답 복호화/검증 정보가 없기 때문에
 * 절대 verified 상태를 찍지 않는다.
 *
 * 실제 NICE 계약 후 이 함수 안에 들어갈 것:
 * - NICE 응답 전문 복호화
 * - 요청번호/state 일치 검증
 * - 성공 resultCode 검증
 * - CI/DI/name/birth/mobile 등 필수값 검증
 * - 재사용 callback 방어
 * - users/{userId}.identity.status = verified 반영
 */
exports.handleNiceIdentityCallback = onRequest(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    secrets: [NICE_CALLBACK_SHARED_SECRET],
  },
  async (request, response) => {
    if (request.method !== "GET" && request.method !== "POST") {
      response.status(405).send("Method Not Allowed");
      return;
    }

    try {
      const payload = readCallbackPayload(request);
      const requestId = normalizeString(payload.requestId || payload.reqSeq);
      const userId = normalizeString(payload.userId);
      const state = normalizeString(payload.state);
      const callbackSecret = normalizeString(
        payload.callbackSecret || request.get("x-yupgagae-callback-secret")
      );
      const expectedSecret = normalizeString(NICE_CALLBACK_SHARED_SECRET.value());

      if (!expectedSecret) {
        logger.error("NICE callback shared secret is not configured.");
        response.status(500).send("NICE callback is not configured.");
        return;
      }

      if (!callbackSecret || callbackSecret !== expectedSecret) {
        logger.warn("NICE callback rejected by shared secret mismatch", {
          requestId,
          userId,
        });
        response.status(403).send("Forbidden");
        return;
      }

      if (!requestId || !userId) {
        logger.warn("NICE callback rejected by missing requestId or userId", {
          requestId,
          userId,
        });
        response.status(400).send("Bad Request");
        return;
      }

      const userRef = db.collection("users").doc(userId);
      const requestRef = userRef
        .collection("identityVerificationRequests")
        .doc(requestId);

      await db.runTransaction(async (transaction) => {
        const userSnapshot = await transaction.get(userRef);
        const requestSnapshot = await transaction.get(requestRef);

        if (!userSnapshot.exists) {
          throw new Error("User document does not exist.");
        }

        if (!requestSnapshot.exists) {
          throw new Error("Identity request document does not exist.");
        }

        const userData = userSnapshot.data() || {};
        const requestData = requestSnapshot.data() || {};
        const expectedState = normalizeString(requestData.requestHash);

        if (state && expectedState && state !== expectedState) {
          throw new Error("NICE callback state mismatch.");
        }

        transaction.set(
          requestRef,
          {
            status: "returned_unverified",
            returnedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            callbackRaw: sanitizeCallbackPayload(payload),
            failureReason:
              "NICE callback received, but official response verification is not implemented yet.",
          },
          {
            merge: true,
          }
        );

        transaction.set(
          userRef,
          {
            identity: {
              ...(userData.identity || {}),
              status: normalizeString((userData.identity || {}).status) || "none",
              lastCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
              lastCallbackAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          },
          {
            merge: true,
          }
        );
      });

      logger.info("NICE identity callback received but not verified", {
        requestId,
        userId,
      });

      response.status(200).send(
        "NICE callback received. Verification is pending server-side implementation."
      );
    } catch (error) {
      logger.error("NICE identity callback failed", {
        message: error && error.message ? error.message : String(error),
      });

      response.status(400).send("NICE callback failed.");
    }
  }
);

/**
 * 개발/검수용 임시 완료 함수.
 *
 * 기본값은 차단이다.
 * Firebase Secret NICE_IDENTITY_DEV_MODE 값을 "true"로 설정한 경우에만 동작한다.
 *
 * 출시 전:
 * - 이 함수 export 제거
 * - 클라이언트 개발용 버튼 제거
 * - Secret도 제거
 */
exports.completeNiceIdentityVerificationDevOnServer = onCall(
  {
    region: "asia-northeast3",
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
    secrets: [NICE_IDENTITY_DEV_MODE],
  },
  async (request) => {
    const devMode = normalizeString(NICE_IDENTITY_DEV_MODE.value());

    if (devMode !== "true") {
      throw new HttpsError(
        "failed-precondition",
        "NICE identity dev verification is disabled."
      );
    }

    const resolved = await resolveCurrentUserForCallable(request);
    const now = admin.firestore.FieldValue.serverTimestamp();

    const data = request.data || {};
    const name = normalizePersonName(data.name);

    if (!name) {
      throw new HttpsError(
        "invalid-argument",
        "Identity verified name is required."
      );
    }

    if (name.length < 2) {
      throw new HttpsError(
        "invalid-argument",
        "Identity verified name is too short."
      );
    }

    await db.runTransaction(async (transaction) => {
      const userSnapshot = await transaction.get(resolved.userRef);

      if (!userSnapshot.exists) {
        throw new HttpsError("not-found", "User document does not exist.");
      }

      const userData = userSnapshot.data() || {};
      validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);
      validateAccountCanRequestIdentityVerification(userData);

      const identity = userData.identity || {};
      const identityStatus = normalizeString(identity.status) || "none";

      if (identityStatus === "verified") {
        return;
      }

      transaction.set(
        resolved.userRef,
        {
          identity: {
            status: "verified",
            provider: "nice_dev",
            verifiedAt: now,
            verifiedNameHash: sha256Hex(name),
            verifiedNameMasked: maskPersonName(name),
            failureCount: 0,
            lockedUntil: null,
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

    logger.info("NICE identity verification completed by dev function", {
      firebaseUid: resolved.firebaseUid,
      internalUserId: resolved.userId,
      verifiedNameMasked: maskPersonName(name),
    });

    return buildAppUserResponse(userData, {
      fallbackUserId: resolved.userId,
      fallbackFirebaseUid: resolved.firebaseUid,
      fallbackProvider: "firebase",
    });
  }
);

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

function validateAccountCanRequestIdentityVerification(userData) {
  if (userData.profileSetupCompleted !== true) {
    throw new HttpsError(
      "failed-precondition",
      "Profile setup must be completed first."
    );
  }

  if (
    normalizeString(userData.status) === "withdrawn" ||
    normalizeString(userData.accountStatus) === "withdrawn" ||
    userData.isDeleted === true
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Account already withdrawn."
    );
  }

  const sanctionStatus = normalizeString(userData.sanctionStatus);

  if (sanctionStatus === "permanent_banned") {
    throw new HttpsError(
      "permission-denied",
      "Permanently banned account cannot verify identity."
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
    accountStatus:
      normalizeString(userData.accountStatus) ||
      normalizeString(userData.status) ||
      "active",
    sanctionStatus: normalizeString(userData.sanctionStatus) || "normal",
    sanctionReason: normalizeString(userData.sanctionReason) || null,
    identityStatus: normalizeString(identity.status) || "none",
    businessStatus: normalizeString(business.status) || "none",
    profileSetupCompleted: userData.profileSetupCompleted === true,
    termsAgreed: terms.agreed === true,
    nickname: normalizeString(storeProfile.nickname) || null,
    industry: normalizeString(storeProfile.industry) || null,
    region: normalizeString(storeProfile.region) || null,
  };
}

function readCallbackPayload(request) {
  const query = request.query || {};
  const body =
    request.body && typeof request.body === "object" ? request.body : {};

  return {
    ...query,
    ...body,
  };
}

function sanitizeCallbackPayload(payload) {
  const result = {};
  const allowedKeys = [
    "requestId",
    "reqSeq",
    "userId",
    "state",
    "resultCode",
    "resultMsg",
    "encData",
    "tokenVersionId",
    "siteCode",
  ];

  allowedKeys.forEach((key) => {
    const value = normalizeString(payload[key]);
    if (value) {
      result[key] = value.slice(0, 1000);
    }
  });

  return result;
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

function normalizePersonName(value) {
  const text = normalizeString(value).replace(/\s+/g, "");

  if (!text) {
    return "";
  }

  return text;
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

function createNiceRequestId() {
  const millis = Date.now();
  const random = crypto.randomBytes(12).toString("hex");
  return `nice_${millis}_${random}`;
}

function createNonce() {
  return crypto.randomBytes(16).toString("hex");
}

function appendQueryParams(url, params) {
  const base = normalizeString(url);

  if (!base) {
    return "";
  }

  const parsed = new URL(base);

  Object.entries(params).forEach(([key, value]) => {
    const normalized = normalizeString(String(value || ""));

    if (normalized) {
      parsed.searchParams.set(key, normalized);
    }
  });

  return parsed.toString();
}