const crypto = require("crypto");
const admin = require("firebase-admin");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");

const db = admin.firestore();

const NOTIFICATION_REGION = "asia-northeast3";
const NOTIFICATION_TIME_ZONE = "Asia/Seoul";

const PUSH_TOKEN_MAX_LENGTH = 4096;
const PUSH_TOKEN_DOC_COLLECTION = "pushTokens";
const PUSH_DELIVERY_DOC_COLLECTION = "pushDeliveries";
const USER_NOTIFICATION_DOC_COLLECTION = "user_notifications";

const HARUGYEOL_VALID_SLOTS = new Set(["midday", "evening"]);

const COMMUNITY_COMMENT_TRIGGER_MAX_INSTANCES = 10;
const HARUGYEOL_REMINDER_USER_PAGE_SIZE = 300;
const HARUGYEOL_REMINDER_LOCK_CHUNK_SIZE = 300;

exports.registerPushToken = onCall(
  {
    region: NOTIFICATION_REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const data = request.data || {};

    const token = normalizeString(data.token);
    const platform = normalizePlatform(data.platform);

    if (!token) {
      throw new HttpsError("invalid-argument", "token required.");
    }

    if (token.length > PUSH_TOKEN_MAX_LENGTH) {
      throw new HttpsError("invalid-argument", "token is too long.");
    }

    if (!platform) {
      throw new HttpsError("invalid-argument", "platform required.");
    }

    const userSnapshot = await resolved.userRef.get();

    if (!userSnapshot.exists) {
      throw new HttpsError("not-found", "User document does not exist.");
    }

    const userData = userSnapshot.data() || {};
    validateUserBelongsToFirebaseUid(userData, resolved.firebaseUid);

    if (!isPushRegisterableUser(userData)) {
      throw new HttpsError(
        "failed-precondition",
        "Inactive account cannot register push token."
      );
    }

    const tokenId = hashToken(token);
    const tokenRef = db.collection(PUSH_TOKEN_DOC_COLLECTION).doc(tokenId);
    const now = admin.firestore.FieldValue.serverTimestamp();

    await db.runTransaction(async (transaction) => {
      const tokenSnapshot = await transaction.get(tokenRef);
      const previous = tokenSnapshot.exists ? tokenSnapshot.data() || {} : {};

      transaction.set(
        tokenRef,
        {
          id: tokenId,
          token,
          tokenHash: tokenId,
          userId: resolved.userId,
          firebaseUid: resolved.firebaseUid,
          platform,
          enabled: true,
          createdAt: previous.createdAt || now,
          updatedAt: now,
          lastSeenAt: now,
        },
        {
          merge: true,
        }
      );
    });

    logger.info("Push token registered", {
      userId: resolved.userId,
      firebaseUid: resolved.firebaseUid,
      platform,
      tokenHash: tokenId,
      authSource: resolved.authSource,
    });

    return {
      ok: true,
      tokenHash: tokenId,
    };
  }
);

exports.deletePushToken = onCall(
  {
    region: NOTIFICATION_REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const data = request.data || {};

    const token = normalizeString(data.token);
    const platform = normalizePlatform(data.platform);

    if (!token) {
      return {
        ok: true,
        deleted: false,
      };
    }

    const tokenId = hashToken(token);
    const tokenRef = db.collection(PUSH_TOKEN_DOC_COLLECTION).doc(tokenId);
    const tokenSnapshot = await tokenRef.get();

    if (!tokenSnapshot.exists) {
      return {
        ok: true,
        deleted: false,
      };
    }

    const tokenData = tokenSnapshot.data() || {};
    const ownerUserId = normalizeString(tokenData.userId);

    if (ownerUserId !== resolved.userId) {
      logger.warn("Push token delete skipped by owner mismatch", {
        requestedBy: resolved.userId,
        tokenOwner: ownerUserId,
        tokenHash: tokenId,
        platform,
        authSource: resolved.authSource,
      });

      return {
        ok: true,
        deleted: false,
      };
    }

    await tokenRef.delete();

    logger.info("Push token deleted", {
      userId: resolved.userId,
      firebaseUid: resolved.firebaseUid,
      platform,
      tokenHash: tokenId,
      authSource: resolved.authSource,
    });

    return {
      ok: true,
      deleted: true,
    };
  }
);

exports.onCommunityCommentCreated = onDocumentCreated(
  {
    region: NOTIFICATION_REGION,
    document: "comments/{commentId}",
    timeoutSeconds: 60,
    memory: "512MiB",
    maxInstances: COMMUNITY_COMMENT_TRIGGER_MAX_INSTANCES,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) {
      return null;
    }

    const commentId = normalizeString(event.params.commentId || snapshot.id);
    const comment = snapshot.data() || {};

    await handleCommunityCommentCreated({
      commentId,
      comment,
    });

    return null;
  }
);

exports.sendHarugyeolMiddayReminder = onSchedule(
  {
    region: NOTIFICATION_REGION,
    schedule: "0 16 * * *",
    timeZone: NOTIFICATION_TIME_ZONE,
    timeoutSeconds: 300,
    memory: "512MiB",
    maxInstances: 1,
  },
  async () => {
    return sendHarugyeolReminder({
      slot: "midday",
      title: "다른 사장님들은 어땠을까요?",
      body: "오늘 낮 장사 분위기를 확인해보세요.",
    });
  }
);

exports.sendHarugyeolEveningReminder = onSchedule(
  {
    region: NOTIFICATION_REGION,
    schedule: "0 23 * * *",
    timeZone: NOTIFICATION_TIME_ZONE,
    timeoutSeconds: 300,
    memory: "512MiB",
    maxInstances: 1,
  },
  async () => {
    return sendHarugyeolReminder({
      slot: "evening",
      title: "오늘 저녁, 다른 가게는 어땠을까요?",
      body: "사장님들의 체감 흐름을 확인해보세요.",
    });
  }
);

async function handleCommunityCommentCreated({ commentId, comment }) {
  const postId = normalizeString(comment.postId);
  const authorId = normalizeString(comment.authorId);
  const authorLabel = normalizeString(comment.authorLabel) || "익명";
  const parentId = normalizeString(comment.parentId);

  if (!commentId || !postId || !authorId) {
    logger.warn("Comment push skipped: missing base fields", {
      commentId,
      postId,
      authorId,
    });
    return;
  }

  if (isClosedComment(comment)) {
    logger.info("Comment push skipped: inactive comment", {
      commentId,
      postId,
      authorId,
    });
    return;
  }

  const postSnapshot = await db.collection("posts").doc(postId).get();

  if (!postSnapshot.exists) {
    logger.warn("Comment push skipped: post not found", {
      commentId,
      postId,
    });
    return;
  }

  const post = postSnapshot.data() || {};

  if (isClosedPost(post)) {
    logger.info("Comment push skipped: inactive post", {
      commentId,
      postId,
    });
    return;
  }

  const notificationTarget = parentId
    ? await resolveReplyNotificationTarget({
        postId,
        rootCommentId: parentId,
        replyAuthorId: authorId,
      })
    : {
        type: "post_comment",
        targetUserId: normalizeString(post.authorId),
        targetCommentId: commentId,
        rootCommentId: "",
        title: "새 댓글이 달렸어요",
        body: `${authorLabel}님이 회원님의 글에 댓글을 남겼습니다.`,
      };

  if (!notificationTarget || !notificationTarget.targetUserId) {
    logger.info("Comment push skipped: no target user", {
      commentId,
      postId,
      parentId,
    });
    return;
  }

  if (notificationTarget.targetUserId === authorId) {
    logger.info("Comment push skipped: self notification", {
      commentId,
      postId,
      authorId,
      targetUserId: notificationTarget.targetUserId,
    });
    return;
  }

  const targetUserSnapshot = await db
    .collection("users")
    .doc(notificationTarget.targetUserId)
    .get();

  if (!targetUserSnapshot.exists) {
    logger.warn("Comment push skipped: target user not found", {
      commentId,
      postId,
      targetUserId: notificationTarget.targetUserId,
    });
    return;
  }

  const targetUser = targetUserSnapshot.data() || {};

  if (!isCommunityPushTargetUser(targetUser)) {
    logger.info("Comment push skipped: target user inactive", {
      commentId,
      postId,
      targetUserId: notificationTarget.targetUserId,
    });
    return;
  }

  if (!isCommunityPushEnabled(targetUser, notificationTarget.type)) {
    logger.info("Comment push skipped: target user notification disabled", {
      commentId,
      postId,
      targetUserId: notificationTarget.targetUserId,
      type: notificationTarget.type,
    });
    return;
  }

  const blocked = await isUserBlockedByRecipient({
    recipientUserId: notificationTarget.targetUserId,
    actorUserId: authorId,
  });

  if (blocked) {
    logger.info("Comment push skipped: actor blocked by recipient", {
      commentId,
      postId,
      recipientUserId: notificationTarget.targetUserId,
      actorUserId: authorId,
    });
    return;
  }

  const deliveryId = buildCommunityCommentDeliveryId({
    type: notificationTarget.type,
    targetUserId: notificationTarget.targetUserId,
    commentId,
  });

  const locked = await lockPushDelivery({
    deliveryId,
    type: notificationTarget.type,
    targetUserId: notificationTarget.targetUserId,
    metadata: {
      postId,
      commentId,
      parentId,
      actorUserId: authorId,
    },
  });

  if (!locked) {
    logger.info("Comment push skipped: duplicated delivery", {
      deliveryId,
      commentId,
      postId,
    });
    return;
  }

  await createUserNotification({
    id: deliveryId,
    type: notificationTarget.type,
    targetUserId: notificationTarget.targetUserId,
    actorUserId: authorId,
    message: notificationTarget.body,
    postId,
    commentId,
    rootCommentId: notificationTarget.rootCommentId || parentId || "",
  });

  const tokens = await fetchPushTokensForUsers([notificationTarget.targetUserId]);

  if (tokens.length === 0) {
    logger.info("Comment push skipped: no tokens", {
      commentId,
      postId,
      targetUserId: notificationTarget.targetUserId,
    });
    return;
  }

  const sendResult = await sendPushToTokens({
    tokens,
    title: notificationTarget.title,
    body: notificationTarget.body,
    data: {
      type: notificationTarget.type,
      target: parentId ? "comment" : "post",
      postId,
      commentId,
      rootCommentId: notificationTarget.rootCommentId || parentId || "",
    },
  });

  logger.info("Comment push sent", {
    commentId,
    postId,
    type: notificationTarget.type,
    targetUserId: notificationTarget.targetUserId,
    tokenCount: tokens.length,
    sentCount: sendResult.sentCount,
    failedCount: sendResult.failedCount,
    cleanedTokenCount: sendResult.cleanedTokenCount,
  });
}

async function resolveReplyNotificationTarget({
  postId,
  rootCommentId,
  replyAuthorId,
}) {
  const rootSnapshot = await db.collection("comments").doc(rootCommentId).get();

  if (!rootSnapshot.exists) {
    logger.warn("Reply push skipped: root comment not found", {
      postId,
      rootCommentId,
    });
    return null;
  }

  const rootComment = rootSnapshot.data() || {};

  if (normalizeString(rootComment.postId) !== postId) {
    logger.warn("Reply push skipped: root comment post mismatch", {
      postId,
      rootCommentId,
      rootPostId: normalizeString(rootComment.postId),
    });
    return null;
  }

  if (isClosedComment(rootComment)) {
    logger.info("Reply push skipped: inactive root comment", {
      postId,
      rootCommentId,
    });
    return null;
  }

  const targetUserId = normalizeString(rootComment.authorId);

  if (!targetUserId || targetUserId === replyAuthorId) {
    return null;
  }

  const rootAuthorLabel = normalizeString(rootComment.authorLabel) || "회원";

  return {
    type: "comment_reply",
    targetUserId,
    targetCommentId: rootCommentId,
    rootCommentId,
    title: "새 답글이 달렸어요",
    body: `${rootAuthorLabel}님의 댓글에 답글이 달렸습니다.`,
  };
}

async function createUserNotification({
  id,
  type,
  targetUserId,
  actorUserId,
  message,
  postId,
  commentId,
  rootCommentId,
}) {
  const notificationRef = db
    .collection(USER_NOTIFICATION_DOC_COLLECTION)
    .doc(id);

  await notificationRef.set(
    {
      id,
      type,
      targetUserId,
      actorUserId,
      message,
      targetPostId: postId,
      targetCommentId: commentId,
      rootCommentId: rootCommentId || null,
      isRead: false,
      status: "active",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    {
      merge: false,
    }
  );
}

async function isUserBlockedByRecipient({ recipientUserId, actorUserId }) {
  const owner = normalizeString(recipientUserId);
  const target = normalizeString(actorUserId);

  if (!owner || !target) {
    return false;
  }

  const blockId = `${owner}_${target}`;
  const blockSnapshot = await db.collection("user_blocks").doc(blockId).get();

  if (!blockSnapshot.exists) {
    return false;
  }

  const block = blockSnapshot.data() || {};

  return normalizeString(block.status) === "active";
}

async function lockPushDelivery({ deliveryId, type, targetUserId, metadata }) {
  const safeDeliveryId = normalizeString(deliveryId);

  if (!safeDeliveryId) {
    return false;
  }

  const deliveryRef = db
    .collection(PUSH_DELIVERY_DOC_COLLECTION)
    .doc(safeDeliveryId);

  return db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(deliveryRef);

    if (snapshot.exists) {
      return false;
    }

    transaction.set(deliveryRef, {
      id: safeDeliveryId,
      type,
      targetUserId,
      status: "locked",
      metadata: metadata || {},
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return true;
  });
}

function buildCommunityCommentDeliveryId({ type, targetUserId, commentId }) {
  return `${normalizeString(type)}_${normalizeString(targetUserId)}_${normalizeString(
    commentId
  )}`;
}

async function sendHarugyeolReminder({ slot, title, body }) {
  if (!HARUGYEOL_VALID_SLOTS.has(slot)) {
    throw new Error(`Invalid harugyeol slot: ${slot}`);
  }

  const dateKey = getKstDateKey(new Date());
  const candidateUsers = await fetchHarugyeolReminderCandidateUsers();

  if (candidateUsers.length === 0) {
    logger.info("Harugyeol reminder skipped: no candidate users", {
      dateKey,
      slot,
    });

    return {
      ok: true,
      dateKey,
      slot,
      candidateCount: 0,
      eligibleCount: 0,
      sentCount: 0,
    };
  }

  const eligibleUsers = await filterUsersWithoutHarugyeolEntry({
    dateKey,
    slot,
    users: candidateUsers,
  });

  if (eligibleUsers.length === 0) {
    logger.info("Harugyeol reminder skipped: all users already submitted", {
      dateKey,
      slot,
      candidateCount: candidateUsers.length,
    });

    return {
      ok: true,
      dateKey,
      slot,
      candidateCount: candidateUsers.length,
      eligibleCount: 0,
      sentCount: 0,
    };
  }

  const lockResults = await lockHarugyeolReminderDeliveries({
    dateKey,
    slot,
    users: eligibleUsers,
  });

  const lockedUsers = lockResults.lockedUsers;

  if (lockedUsers.length === 0) {
    logger.info("Harugyeol reminder skipped: delivery already locked", {
      dateKey,
      slot,
      eligibleCount: eligibleUsers.length,
    });

    return {
      ok: true,
      dateKey,
      slot,
      candidateCount: candidateUsers.length,
      eligibleCount: eligibleUsers.length,
      sentCount: 0,
    };
  }

  const tokens = await fetchPushTokensForUsers(
    lockedUsers.map((item) => item.userId)
  );

  if (tokens.length === 0) {
    logger.info("Harugyeol reminder skipped: no push tokens", {
      dateKey,
      slot,
      lockedCount: lockedUsers.length,
    });

    return {
      ok: true,
      dateKey,
      slot,
      candidateCount: candidateUsers.length,
      eligibleCount: eligibleUsers.length,
      lockedCount: lockedUsers.length,
      sentCount: 0,
    };
  }

  const sendResult = await sendPushToTokens({
    tokens,
    title,
    body,
    data: {
      type: "harugyeol",
      target: "harugyeol",
      dateKey,
      slot,
    },
  });

  logger.info("Harugyeol reminder sent", {
    dateKey,
    slot,
    candidateCount: candidateUsers.length,
    eligibleCount: eligibleUsers.length,
    lockedCount: lockedUsers.length,
    tokenCount: tokens.length,
    sentCount: sendResult.sentCount,
    failedCount: sendResult.failedCount,
    cleanedTokenCount: sendResult.cleanedTokenCount,
  });

  return {
    ok: true,
    dateKey,
    slot,
    candidateCount: candidateUsers.length,
    eligibleCount: eligibleUsers.length,
    lockedCount: lockedUsers.length,
    tokenCount: tokens.length,
    sentCount: sendResult.sentCount,
    failedCount: sendResult.failedCount,
    cleanedTokenCount: sendResult.cleanedTokenCount,
  };
}

async function fetchHarugyeolReminderCandidateUsers() {
  const candidateUsers = [];
  let lastDocument = null;

  while (true) {
    let query = db
      .collection("users")
      .where("status", "==", "active")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(HARUGYEOL_REMINDER_USER_PAGE_SIZE);

    if (lastDocument) {
      query = query.startAfter(lastDocument);
    }

    const usersSnapshot = await query.get();

    if (usersSnapshot.empty) {
      break;
    }

    usersSnapshot.forEach((doc) => {
      const data = doc.data() || {};
      const userId = normalizeString(data.userId) || doc.id;

      if (!userId) return;
      if (!isHarugyeolReminderTargetUser(data)) return;
      if (!isHarugyeolPushEnabled(data)) return;

      candidateUsers.push({
        userId,
        userRef: doc.ref,
        userData: data,
      });
    });

    lastDocument = usersSnapshot.docs[usersSnapshot.docs.length - 1];

    if (usersSnapshot.size < HARUGYEOL_REMINDER_USER_PAGE_SIZE) {
      break;
    }
  }

  return candidateUsers;
}

async function filterUsersWithoutHarugyeolEntry({ dateKey, slot, users }) {
  const result = [];
  const chunks = chunkArray(users, 300);

  for (const chunk of chunks) {
    const refs = chunk.map((user) => {
      const entryId = `${user.userId}_${slot}`;

      return db
        .collection("harugyeolDays")
        .doc(dateKey)
        .collection("entries")
        .doc(entryId);
    });

    const snapshots = await db.getAll(...refs);

    snapshots.forEach((snapshot, index) => {
      if (!snapshot.exists) {
        result.push(chunk[index]);
      }
    });
  }

  return result;
}

async function lockHarugyeolReminderDeliveries({ dateKey, slot, users }) {
  const lockedUsers = [];
  const skippedUsers = [];
  const chunks = chunkArray(users, HARUGYEOL_REMINDER_LOCK_CHUNK_SIZE);

  for (const chunk of chunks) {
    const results = await Promise.allSettled(
      chunk.map(async (user) => {
        const deliveryId = `harugyeol_${dateKey}_${slot}_${user.userId}`;
        const deliveryRef = db
          .collection(PUSH_DELIVERY_DOC_COLLECTION)
          .doc(deliveryId);

        await deliveryRef.create({
          id: deliveryId,
          type: "harugyeol_reminder",
          userId: user.userId,
          dateKey,
          slot,
          status: "locked",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return user;
      })
    );

    results.forEach((result, index) => {
      if (result.status === "fulfilled") {
        lockedUsers.push(result.value);
        return;
      }

      const error = result.reason || {};
      const code = normalizeString(error.code);

      if (code === "6" || code === "already-exists") {
        skippedUsers.push(chunk[index]);
        return;
      }

      logger.warn("Harugyeol reminder lock failed", {
        userId: chunk[index] && chunk[index].userId,
        dateKey,
        slot,
        code: code || "unknown",
      });

      skippedUsers.push(chunk[index]);
    });
  }

  return {
    lockedUsers,
    skippedUsers,
  };
}

async function fetchPushTokensForUsers(userIds) {
  const uniqueUserIds = Array.from(
    new Set(
      userIds
        .map((item) => normalizeString(item))
        .filter((item) => item.length > 0)
    )
  );

  if (uniqueUserIds.length === 0) {
    return [];
  }

  const result = [];
  const userIdChunks = chunkArray(uniqueUserIds, 30);

  for (const userIdChunk of userIdChunks) {
    const snapshot = await db
      .collection(PUSH_TOKEN_DOC_COLLECTION)
      .where("userId", "in", userIdChunk)
      .get();

    snapshot.forEach((doc) => {
      const data = doc.data() || {};

      if (data.enabled === false) return;

      const token = normalizeString(data.token);
      const userId = normalizeString(data.userId);

      if (!token) return;
      if (!userId) return;

      result.push({
        docId: doc.id,
        token,
        userId,
        platform: normalizePlatform(data.platform),
      });
    });
  }

  return result;
}

async function sendPushToTokens({ tokens, title, body, data }) {
  let sentCount = 0;
  let failedCount = 0;
  let cleanedTokenCount = 0;

  const chunks = chunkArray(tokens, 500);

  for (const chunk of chunks) {
    const response = await admin.messaging().sendEachForMulticast({
      tokens: chunk.map((item) => item.token),
      notification: {
        title,
        body,
      },
      data: stringifyData(data),
      android: {
        priority: "high",
        notification: {
          channelId: "yupgagae_high",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });

    sentCount += response.successCount;
    failedCount += response.failureCount;

    const deletePromises = [];

    response.responses.forEach((item, index) => {
      if (item.success) return;

      const errorCode = item.error && item.error.code;
      const tokenItem = chunk[index];

      if (isInvalidPushTokenError(errorCode)) {
        cleanedTokenCount += 1;
        deletePromises.push(
          db.collection(PUSH_TOKEN_DOC_COLLECTION).doc(tokenItem.docId).delete()
        );
      } else {
        logger.warn("Push send failed", {
          code: errorCode || "unknown",
          tokenHash: tokenItem.docId,
          userId: tokenItem.userId,
          platform: tokenItem.platform,
        });
      }
    });

    if (deletePromises.length > 0) {
      await Promise.allSettled(deletePromises);
    }
  }

  return {
    sentCount,
    failedCount,
    cleanedTokenCount,
  };
}

function isInvalidPushTokenError(code) {
  return (
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token" ||
    code === "messaging/mismatched-credential" ||
    code === "messaging/invalid-argument"
  );
}

async function resolveCurrentUserForCallable(request) {
  const data = request.data || {};

  logger.info("Push callable auth debug", {
    hasCallableAuth: Boolean(request.auth && request.auth.uid),
    hasFirebaseIdToken: Boolean(normalizeString(data.firebaseIdToken)),
    dataKeys: Object.keys(data || {}),
  });

  let firebaseUid = "";
  let authSource = "callable";

  if (request.auth && request.auth.uid) {
    firebaseUid = normalizeString(request.auth.uid);
  }

  if (!firebaseUid) {
    const firebaseIdToken = normalizeString(data.firebaseIdToken);

    if (!firebaseIdToken) {
      throw new HttpsError(
        "unauthenticated",
        "Firebase authentication is required."
      );
    }

    try {
      const decoded = await admin.auth().verifyIdToken(firebaseIdToken);
      firebaseUid = normalizeString(decoded.uid);
      authSource = "id_token_fallback";
    } catch (error) {
      logger.warn("Firebase ID token fallback verification failed", {
        code: error && error.code ? error.code : "unknown",
      });

      throw new HttpsError(
        "unauthenticated",
        "Firebase authentication is invalid."
      );
    }
  }

  if (!firebaseUid) {
    throw new HttpsError(
      "unauthenticated",
      "Firebase authentication is required."
    );
  }

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
    authSource,
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

function isPushRegisterableUser(userData) {
  if (normalizeString(userData.status) !== "active") return false;
  if (userData.isDeleted === true) return false;

  return true;
}

function isCommunityPushTargetUser(userData) {
  if (normalizeString(userData.status) !== "active") return false;
  if (userData.isDeleted === true) return false;

  const role = normalizeString(userData.role);
  if (role === "banned") return false;

  const sanctionStatus = normalizeString(userData.sanctionStatus);

  if (sanctionStatus === "suspended") {
    const sanctionUntil = userData.sanctionUntil;

    if (!sanctionUntil) {
      return false;
    }

    const untilDate =
      typeof sanctionUntil.toDate === "function"
        ? sanctionUntil.toDate()
        : new Date(sanctionUntil);

    if (Number.isNaN(untilDate.getTime())) {
      return false;
    }

    if (untilDate > new Date()) {
      return false;
    }
  }

  return true;
}

function isCommunityPushEnabled(userData, type) {
  const settings = userData.notificationSettings || userData.pushSettings || {};

  if (settings.pushEnabled === false) return false;
  if (settings.communityEnabled === false) return false;

  if (type === "post_comment" && settings.commentEnabled === false) {
    return false;
  }

  if (type === "comment_reply" && settings.replyEnabled === false) {
    return false;
  }

  return true;
}

function isHarugyeolReminderTargetUser(userData) {
  if (normalizeString(userData.status) !== "active") return false;
  if (userData.isDeleted === true) return false;
  if (userData.profileSetupCompleted !== true) return false;

  const role = normalizeString(userData.role);
  if (role === "banned") return false;

  const sanctionStatus = normalizeString(userData.sanctionStatus);

  if (sanctionStatus === "suspended") {
    const sanctionUntil = userData.sanctionUntil;

    if (!sanctionUntil) {
      return false;
    }

    const untilDate =
      typeof sanctionUntil.toDate === "function"
        ? sanctionUntil.toDate()
        : new Date(sanctionUntil);

    if (Number.isNaN(untilDate.getTime())) {
      return false;
    }

    if (untilDate > new Date()) {
      return false;
    }
  }

  return true;
}

function isHarugyeolPushEnabled(userData) {
  const consent =
    userData.notificationConsent && typeof userData.notificationConsent === "object"
      ? userData.notificationConsent
      : {};

  if (consent.pushAgreed === false) return false;

  const settings = userData.notificationSettings || userData.pushSettings || {};

  if (settings.pushEnabled === false) return false;
  if (settings.harugyeolEnabled === false) return false;
  if (settings.harugyeolReminderEnabled === false) return false;

  return true;
}

function isClosedComment(comment) {
  const status = normalizeString(comment.status || "active");

  return (
    comment.isDeleted === true ||
    status === "deletedByAuthor" ||
    status === "hiddenByReport" ||
    status === "hiddenByAdmin" ||
    status === "removedByAdmin" ||
    comment.isReportThresholdReached === true ||
    comment.isHiddenByAdmin === true ||
    comment.isRemovedByAdmin === true ||
    comment.deletedAt != null ||
    comment.adminRemovedAt != null
  );
}

function isClosedPost(post) {
  const status = normalizeString(post.status || "active");

  return (
    status === "deletedByAuthor" ||
    status === "hiddenByReport" ||
    status === "hiddenByAdmin" ||
    status === "removedByAdmin" ||
    post.isReportThresholdReached === true ||
    post.isHiddenByAdmin === true ||
    post.deletedAt != null ||
    post.adminRemovedAt != null
  );
}

function getKstDateKey(date) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: NOTIFICATION_TIME_ZONE,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).formatToParts(date);

  const year = parts.find((item) => item.type === "year")?.value || "";
  const month = parts.find((item) => item.type === "month")?.value || "";
  const day = parts.find((item) => item.type === "day")?.value || "";

  if (!year || !month || !day) {
    throw new Error("Failed to resolve KST date key.");
  }

  return `${year}-${month}-${day}`;
}

function normalizePlatform(value) {
  const text = normalizeString(value).toLowerCase();

  if (!text) return "";

  if (text === "android") return "android";
  if (text === "ios") return "ios";
  if (text === "macos") return "macos";
  if (text === "windows") return "windows";
  if (text === "linux") return "linux";
  if (text === "fuchsia") return "fuchsia";

  return "unknown";
}

function normalizeString(value) {
  if (value === undefined || value === null) {
    return "";
  }

  return String(value).trim();
}

function stringifyData(data) {
  const result = {};

  Object.entries(data || {}).forEach(([key, value]) => {
    const normalizedKey = normalizeString(key);
    if (!normalizedKey) return;

    const normalizedValue = normalizeString(value);
    if (!normalizedValue) return;

    result[normalizedKey] = normalizedValue;
  });

  return result;
}

function hashToken(token) {
  return crypto.createHash("sha256").update(token, "utf8").digest("hex");
}

function chunkArray(items, size) {
  const result = [];

  for (let i = 0; i < items.length; i += size) {
    result.push(items.slice(i, i + size));
  }

  return result;
}

exports.sendTestPushToMe = onCall(
  {
    region: NOTIFICATION_REGION,
    timeoutSeconds: 30,
    memory: "256MiB",
    maxInstances: 10,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);

    const tokens = await fetchPushTokensForUsers([resolved.userId]);

    if (tokens.length === 0) {
      return {
        ok: false,
        reason: "no_push_token",
        message: "등록된 FCM 토큰이 없습니다. 앱을 실행한 뒤 다시 시도하세요.",
      };
    }

    const sendResult = await sendPushToTokens({
      tokens,
      title: "옆가게 테스트 알림",
      body: "푸시 알림 연결이 정상입니다.",
      data: {
        type: "harugyeol",
        target: "harugyeol",
        source: "test",
      },
    });

    logger.info("Test push sent", {
      userId: resolved.userId,
      tokenCount: tokens.length,
      sentCount: sendResult.sentCount,
      failedCount: sendResult.failedCount,
      cleanedTokenCount: sendResult.cleanedTokenCount,
      authSource: resolved.authSource,
    });

    return {
      ok: true,
      tokenCount: tokens.length,
      sentCount: sendResult.sentCount,
      failedCount: sendResult.failedCount,
      cleanedTokenCount: sendResult.cleanedTokenCount,
    };
  }
);