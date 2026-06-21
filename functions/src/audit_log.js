const admin = require("firebase-admin");

const db = admin.firestore();

const AUDIT_LOG_COLLECTION = "audit_logs";
const METADATA_MAX_DEPTH = 3;
const METADATA_MAX_ARRAY_LENGTH = 30;
const METADATA_MAX_STRING_LENGTH = 500;

function buildAuditActor(caller) {
  const user =
    caller && caller.user && typeof caller.user === "object" ? caller.user : {};

  const storeProfile =
    user.storeProfile && typeof user.storeProfile === "object"
      ? user.storeProfile
      : {};

  return {
    userId: normalizeString(caller && caller.userId),
    firebaseUid: normalizeString(caller && caller.firebaseUid),
    role: normalizeString(user.role) || "user",
    nickname: normalizeString(storeProfile.nickname) || null,
    industry: normalizeString(storeProfile.industry) || null,
    region: normalizeString(storeProfile.region) || null,
  };
}

function createAuditLogInTransaction(tx, input) {
  if (!tx || typeof tx.set !== "function") {
    throw new Error("Firestore transaction is required.");
  }

  const logRef = db.collection(AUDIT_LOG_COLLECTION).doc();
  const actor =
    input && input.actor && typeof input.actor === "object" ? input.actor : {};

  tx.set(
    logRef,
    removeUndefinedFields({
      id: logRef.id,
      eventType: normalizeString(input && input.eventType),
      actorUserId: normalizeString(actor.userId),
      actorFirebaseUid: normalizeString(actor.firebaseUid),
      actorRole: normalizeString(actor.role) || "user",
      actorSnapshot: sanitizeMetadata({
        userId: normalizeString(actor.userId),
        firebaseUid: normalizeString(actor.firebaseUid),
        role: normalizeString(actor.role) || "user",
        nickname: normalizeString(actor.nickname) || null,
        industry: normalizeString(actor.industry) || null,
        region: normalizeString(actor.region) || null,
      }),
      targetType: normalizeString(input && input.targetType),
      targetId: normalizeString(input && input.targetId),
      postId: normalizeString(input && input.postId) || null,
      commentId: normalizeString(input && input.commentId) || null,
      targetAuthorId: normalizeString(input && input.targetAuthorId) || null,
      targetSnapshot: sanitizeMetadata(input && input.targetSnapshot),
      actionType: normalizeString(input && input.actionType) || null,
      previousStatus: normalizeString(input && input.previousStatus) || null,
      nextStatus: normalizeString(input && input.nextStatus) || null,
      reason: normalizeString(input && input.reason) || null,
      reportCount: normalizeNullableCount(input && input.reportCount),
      source: normalizeString(input && input.source) || "server",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAtIso: normalizeString(input && input.createdAtIso) || null,
      metadata: sanitizeMetadata(input && input.metadata),
    })
  );

  return logRef.id;
}

function sanitizeMetadata(value, depth = 0) {
  if (depth >= METADATA_MAX_DEPTH) {
    return null;
  }

  if (value === undefined || value === null) {
    return null;
  }

  if (typeof value === "string") {
    return truncateString(value, METADATA_MAX_STRING_LENGTH);
  }

  if (typeof value === "number") {
    return Number.isFinite(value) ? value : null;
  }

  if (typeof value === "boolean") {
    return value;
  }

  if (Array.isArray(value)) {
    return value
      .slice(0, METADATA_MAX_ARRAY_LENGTH)
      .map((item) => sanitizeMetadata(item, depth + 1))
      .filter((item) => item !== undefined);
  }

  if (typeof value === "object") {
    const result = {};

    Object.entries(value).forEach(([rawKey, rawValue]) => {
      const key = normalizeString(rawKey);

      if (!key) {
        return;
      }

      const sanitizedValue = sanitizeMetadata(rawValue, depth + 1);

      if (sanitizedValue === undefined) {
        return;
      }

      result[key] = sanitizedValue;
    });

    return result;
  }

  return null;
}

function removeUndefinedFields(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  const result = {};

  Object.entries(value).forEach(([key, item]) => {
    if (item !== undefined) {
      result[key] = item;
    }
  });

  return result;
}

function normalizeNullableCount(value) {
  if (value === undefined || value === null || value === "") {
    return null;
  }

  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.max(0, Math.floor(value));
  }

  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return null;
  }

  return Math.max(0, Math.floor(parsed));
}

function truncateString(value, maxLength) {
  const text = normalizeString(value);

  if (text.length <= maxLength) {
    return text;
  }

  return text.slice(0, maxLength);
}

function normalizeString(value) {
  if (value === undefined || value === null) {
    return "";
  }

  return String(value).trim();
}

module.exports = {
  buildAuditActor,
  createAuditLogInTransaction,
};