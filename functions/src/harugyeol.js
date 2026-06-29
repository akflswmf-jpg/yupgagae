const admin = require("firebase-admin");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");

const db = admin.firestore();

const HARUGYEOL_REGION = "asia-northeast3";

const HARUGYEOL_VALID_MOODS = {
  slow: 10,
  normal: 45,
  good: 75,
  great: 100,
};

const HARUGYEOL_VALID_REASONS = new Set([
  "economy",
  "weekdayHoliday",
  "delivery",
  "localMood",
  "event",
  "groupGuest",
  "rudeGuest",
  "unexpectedGood",
  "weather",
  "etc",

  // Backward compatibility for old local/server keys.
  "weekday",
  "deliveryDown",
]);

const HARUGYEOL_REASON_KEY_ALIASES = {
  weekday: "weekdayHoliday",
  deliveryDown: "delivery",
};

const HARUGYEOL_VALID_SLOTS = new Set(["midday", "evening"]);

exports.submitHarugyeolEntry = onCall(
  {
    region: HARUGYEOL_REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const data = request.data || {};

    const dateKey = normalizeString(data.dateKey);
    const slot = normalizeString(data.slot);
    const mood = normalizeString(data.mood);
    const oneLineText = normalizeString(data.oneLineText);
    const reasons = parseHarugyeolReasons(data.reasons);

    if (!dateKey) {
      throw new HttpsError("invalid-argument", "dateKey required.");
    }

    if (!HARUGYEOL_VALID_SLOTS.has(slot)) {
      throw new HttpsError("invalid-argument", "Invalid harugyeol slot.");
    }

    if (!Object.prototype.hasOwnProperty.call(HARUGYEOL_VALID_MOODS, mood)) {
      throw new HttpsError("invalid-argument", "Invalid harugyeol mood.");
    }

    if (oneLineText.length > 40) {
      throw new HttpsError(
        "invalid-argument",
        "Harugyeol oneLineText must be 40 characters or less."
      );
    }

    const kst = getHarugyeolKstNowParts();

    if (dateKey !== kst.dateKey) {
      throw new HttpsError(
        "invalid-argument",
        "Only today's harugyeol can be submitted."
      );
    }

    if (!canSubmitHarugyeolSlot(slot, kst.minutes)) {
      throw new HttpsError(
        "failed-precondition",
        "Harugyeol entry is not available for this slot at this time."
      );
    }

    const score = HARUGYEOL_VALID_MOODS[mood];
    const now = admin.firestore.FieldValue.serverTimestamp();
    const nowIso = new Date().toISOString();

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
        normalizeString(userData.status) !== "active" ||
        userData.isDeleted === true
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Inactive account cannot submit harugyeol."
        );
      }

      const storeProfile = userData.storeProfile || {};
      const authorLabel = normalizeString(storeProfile.nickname) || "익명";
      const industryId = normalizeString(storeProfile.industry) || null;
      const locationLabel = normalizeString(storeProfile.region) || null;
      const business = userData.business || {};
      const isOwnerVerified = normalizeString(business.status) === "verified";

      const entryId = `${resolved.userId}_${slot}`;

      const dayRef = db.collection("harugyeolDays").doc(dateKey);
      const entryRef = dayRef.collection("entries").doc(entryId);
      const commentRef = oneLineText
        ? dayRef.collection("comments").doc(entryId)
        : null;

      const entrySnapshot = await transaction.get(entryRef);

      if (entrySnapshot.exists) {
        throw new HttpsError(
          "already-exists",
          "Current slot harugyeol entry already exists."
        );
      }

      const daySnapshot = await transaction.get(dayRef);
      const currentDay = daySnapshot.exists ? daySnapshot.data() || {} : {};

      const totalCount = toFiniteNumber(currentDay.totalCount) + 1;
      const scoreSum = toFiniteNumber(currentDay.scoreSum) + score;
      const averageScore = totalCount > 0 ? scoreSum / totalCount : 0;

      const slotStats = normalizeHarugyeolSlotStats(currentDay.slotStats);
      const currentSlotStat = slotStats[slot] || createEmptyHarugyeolSlotStat();

      const nextSlotCount = toFiniteNumber(currentSlotStat.count) + 1;
      const nextSlotScoreSum = toFiniteNumber(currentSlotStat.scoreSum) + score;

      const nextSlotMoodCounts = normalizeHarugyeolMoodCounts(
        currentSlotStat.moodCounts
      );
      nextSlotMoodCounts[mood] = toFiniteNumber(nextSlotMoodCounts[mood]) + 1;

      const nextSlotReasonCounts = normalizeHarugyeolReasonCounts(
        currentSlotStat.reasonCounts
      );

      reasons.forEach((reason) => {
        nextSlotReasonCounts[reason] =
          toFiniteNumber(nextSlotReasonCounts[reason]) + 1;
      });

      slotStats[slot] = {
        count: nextSlotCount,
        scoreSum: nextSlotScoreSum,
        averageScore:
          nextSlotCount > 0 ? nextSlotScoreSum / nextSlotCount : 0,
        moodCounts: nextSlotMoodCounts,
        reasonCounts: nextSlotReasonCounts,
      };

      const hourlyStats = normalizeHarugyeolHourlyStats(currentDay.hourlyStats);
      const graphHour = resolveHarugyeolGraphHour({
        slot,
        hour: kst.hour,
        minutes: kst.minutes,
      });

      if (graphHour !== null) {
        const hourKey = String(graphHour).padStart(2, "0");
        const hourlyStatKey = `${slot}_${hourKey}`;
        const currentHourlyStat =
          hourlyStats[hourlyStatKey] ||
          createEmptyHarugyeolHourlyStat({
            slot,
            hour: graphHour,
          });

        const nextHourlyCount = toFiniteNumber(currentHourlyStat.count) + 1;
        const nextHourlyScoreSum =
          toFiniteNumber(currentHourlyStat.scoreSum) + score;

        hourlyStats[hourlyStatKey] = {
          hour: graphHour,
          slot,
          count: nextHourlyCount,
          scoreSum: nextHourlyScoreSum,
          averageScore:
            nextHourlyCount > 0 ? nextHourlyScoreSum / nextHourlyCount : 0,
        };
      }

      const moodCounts = normalizeHarugyeolMoodCounts(currentDay.moodCounts);
      moodCounts[mood] = toFiniteNumber(moodCounts[mood]) + 1;

      const reasonCounts = normalizeHarugyeolReasonCounts(
        currentDay.reasonCounts
      );

      reasons.forEach((reason) => {
        reasonCounts[reason] = toFiniteNumber(reasonCounts[reason]) + 1;
      });

      transaction.set(
        dayRef,
        {
          dateKey,
          totalCount,
          scoreSum,
          averageScore,
          slotStats,
          hourlyStats,
          moodCounts,
          reasonCounts,
          createdAt: currentDay.createdAt || now,
          updatedAt: now,
        },
        {
          merge: true,
        }
      );

      transaction.set(entryRef, {
        id: entryId,
        dateKey,
        userId: resolved.userId,
        authorLabel,
        industryId,
        locationLabel,
        isOwnerVerified,
        slot,
        mood,
        score,
        reasons,
        oneLineText,
        createdAt: nowIso,
        updatedAt: nowIso,
      });

      if (commentRef) {
        transaction.set(commentRef, {
          id: entryId,
          dateKey,
          entryId,
          userId: resolved.userId,
          authorLabel,
          industryId,
          locationLabel,
          isOwnerVerified,
          slot,
          mood,
          text: oneLineText,
          likeCount: 0,
          likedUserIds: [],
          status: "active",
          createdAt: nowIso,
          updatedAt: nowIso,
        });
      }
    });

    logger.info("Harugyeol entry submitted", {
      internalUserId: resolved.userId,
      firebaseUid: resolved.firebaseUid,
      dateKey,
      slot,
      mood,
      reasonCount: reasons.length,
      hasOneLineText: oneLineText.length > 0,
    });

    return {
      ok: true,
      dateKey,
      slot,
    };
  }
);

exports.toggleHarugyeolCommentLike = onCall(
  {
    region: HARUGYEOL_REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const resolved = await resolveCurrentUserForCallable(request);
    const data = request.data || {};

    const dateKey = normalizeString(data.dateKey);
    const commentId = normalizeString(data.commentId);

    if (!dateKey) {
      throw new HttpsError("invalid-argument", "dateKey required.");
    }

    if (!commentId) {
      throw new HttpsError("invalid-argument", "commentId required.");
    }

    assertHarugyeolDateKeyWithinRecent3Days(dateKey);

    const nowIso = new Date().toISOString();

    let liked = false;

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
        normalizeString(userData.status) !== "active" ||
        userData.isDeleted === true
      ) {
        throw new HttpsError(
          "failed-precondition",
          "Inactive account cannot like harugyeol comment."
        );
      }

      const commentRef = db
        .collection("harugyeolDays")
        .doc(dateKey)
        .collection("comments")
        .doc(commentId);

      const commentSnapshot = await transaction.get(commentRef);

      if (!commentSnapshot.exists) {
        throw new HttpsError("not-found", "Harugyeol comment not found.");
      }

      const commentData = commentSnapshot.data() || {};

      if (normalizeString(commentData.status) !== "active") {
        throw new HttpsError(
          "failed-precondition",
          "Inactive harugyeol comment cannot be liked."
        );
      }

      const likedUserIds = Array.isArray(commentData.likedUserIds)
        ? commentData.likedUserIds.filter((value) => typeof value === "string")
        : [];

      const hasLiked = likedUserIds.includes(resolved.userId);

      const nextLikedUserIds = hasLiked
        ? likedUserIds.filter((value) => value !== resolved.userId)
        : [...likedUserIds, resolved.userId];

      liked = !hasLiked;

      transaction.set(
        commentRef,
        {
          likedUserIds: nextLikedUserIds,
          likeCount: nextLikedUserIds.length,
          updatedAt: nowIso,
        },
        {
          merge: true,
        }
      );
    });

    logger.info("Harugyeol comment like toggled", {
      internalUserId: resolved.userId,
      firebaseUid: resolved.firebaseUid,
      dateKey,
      commentId,
      liked,
    });

    return {
      ok: true,
      liked,
    };
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

function normalizeString(value) {
  if (typeof value !== "string") {
    return "";
  }

  return value.trim();
}

function getHarugyeolKstNowParts(date = new Date()) {
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);

  const year = kst.getUTCFullYear();
  const month = String(kst.getUTCMonth() + 1).padStart(2, "0");
  const day = String(kst.getUTCDate()).padStart(2, "0");

  const hour = kst.getUTCHours();
  const minute = kst.getUTCMinutes();

  return {
    dateKey: `${year}-${month}-${day}`,
    hour,
    minute,
    minutes: hour * 60 + minute,
  };
}

function getHarugyeolDateKeyOffset(offsetDays) {
  const now = new Date();
  const shifted = new Date(now.getTime() + offsetDays * 24 * 60 * 60 * 1000);
  return getHarugyeolKstNowParts(shifted).dateKey;
}

function canSubmitHarugyeolSlot(slot, minutes) {
  const middayStart = 11 * 60;
  const eveningStart = 17 * 60 + 1;
  const eveningEnd = 23 * 60 + 59;

  if (slot === "midday") {
    return minutes >= middayStart && minutes <= eveningEnd;
  }

  if (slot === "evening") {
    return minutes >= eveningStart && minutes <= eveningEnd;
  }

  return false;
}

function resolveHarugyeolGraphHour({ slot, hour, minutes }) {
  const middayStart = 11 * 60;
  const middayEnd = 17 * 60;
  const eveningStart = 17 * 60 + 1;
  const dayEnd = 23 * 60 + 59;

  if (!HARUGYEOL_VALID_SLOTS.has(slot)) {
    return null;
  }

  if (!Number.isFinite(hour) || hour < 0 || hour > 23) {
    return null;
  }

  if (!Number.isFinite(minutes)) {
    return null;
  }

  if (slot === "midday") {
    if (minutes < middayStart || minutes > middayEnd) {
      return null;
    }

    return Math.min(Math.max(hour, 11), 16);
  }

  if (slot === "evening") {
    if (minutes < eveningStart || minutes > dayEnd) {
      return null;
    }

    return Math.min(Math.max(hour, 17), 22);
  }

  return null;
}

function parseHarugyeolReasons(rawReasons) {
  if (!Array.isArray(rawReasons)) {
    throw new HttpsError("invalid-argument", "Harugyeol reasons must be array.");
  }

  const result = [];

  rawReasons.forEach((raw) => {
    const reason = normalizeString(raw);

    if (!HARUGYEOL_VALID_REASONS.has(reason)) {
      throw new HttpsError("invalid-argument", "Invalid harugyeol reason.");
    }

    const normalizedReason = HARUGYEOL_REASON_KEY_ALIASES[reason] || reason;

    if (!result.includes(normalizedReason)) {
      result.push(normalizedReason);
    }
  });

  if (result.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Harugyeol reason must contain at least one item."
    );
  }

  if (result.length > 10) {
    throw new HttpsError(
      "invalid-argument",
      "Harugyeol reasons are too many."
    );
  }

  return result;
}

function assertHarugyeolDateKeyWithinRecent3Days(dateKey) {
  const allowed = new Set([
    getHarugyeolDateKeyOffset(0),
    getHarugyeolDateKeyOffset(-1),
    getHarugyeolDateKeyOffset(-2),
  ]);

  if (!allowed.has(dateKey)) {
    throw new HttpsError(
      "failed-precondition",
      "Only recent harugyeol comments can be liked."
    );
  }
}

function normalizeHarugyeolHourlyStats(raw) {
  const result = {};

  if (!raw || typeof raw !== "object") {
    return result;
  }

  Object.keys(raw).forEach((key) => {
    const value = raw[key];

    if (!value || typeof value !== "object") {
      return;
    }

    const slot = normalizeString(value.slot);
    const hour = Math.trunc(toFiniteNumber(value.hour));

    if (!HARUGYEOL_VALID_SLOTS.has(slot)) {
      return;
    }

    if (hour < 0 || hour > 23) {
      return;
    }

    const count = toFiniteNumber(value.count);
    const scoreSum = toFiniteNumber(value.scoreSum);

    if (count <= 0) {
      return;
    }

    const hourKey = String(hour).padStart(2, "0");
    const normalizedKey = `${slot}_${hourKey}`;

    result[normalizedKey] = {
      hour,
      slot,
      count,
      scoreSum,
      averageScore:
        count > 0
          ? toFiniteNumber(value.averageScore) || scoreSum / count
          : 0,
    };
  });

  return result;
}

function createEmptyHarugyeolHourlyStat({ slot, hour }) {
  return {
    hour,
    slot,
    count: 0,
    scoreSum: 0,
    averageScore: 0,
  };
}

function normalizeHarugyeolSlotStats(raw) {
  const result = {
    midday: createEmptyHarugyeolSlotStat(),
    evening: createEmptyHarugyeolSlotStat(),
  };

  if (!raw || typeof raw !== "object") {
    return result;
  }

  ["midday", "evening"].forEach((slot) => {
    const value = raw[slot];

    if (!value || typeof value !== "object") {
      return;
    }

    const count = toFiniteNumber(value.count);
    const scoreSum = toFiniteNumber(value.scoreSum);

    result[slot] = {
      count,
      scoreSum,
      averageScore:
        count > 0
          ? toFiniteNumber(value.averageScore) || scoreSum / count
          : 0,
      moodCounts: normalizeHarugyeolMoodCounts(value.moodCounts),
      reasonCounts: normalizeHarugyeolReasonCounts(value.reasonCounts),
    };
  });

  return result;
}

function createEmptyHarugyeolSlotStat() {
  return {
    count: 0,
    scoreSum: 0,
    averageScore: 0,
    moodCounts: normalizeHarugyeolMoodCounts(null),
    reasonCounts: normalizeHarugyeolReasonCounts(null),
  };
}

function normalizeHarugyeolMoodCounts(raw) {
  const result = {
    slow: 0,
    normal: 0,
    good: 0,
    great: 0,
  };

  if (!raw || typeof raw !== "object") {
    return result;
  }

  Object.keys(result).forEach((key) => {
    result[key] = toFiniteNumber(raw[key]);
  });

  return result;
}

function normalizeHarugyeolReasonCounts(raw) {
  const result = {
    economy: 0,
    weekdayHoliday: 0,
    delivery: 0,
    localMood: 0,
    event: 0,
    groupGuest: 0,
    rudeGuest: 0,
    unexpectedGood: 0,
    weather: 0,
    etc: 0,
  };

  if (!raw || typeof raw !== "object") {
    return result;
  }

  Object.keys(raw).forEach((key) => {
    const normalizedKey = HARUGYEOL_REASON_KEY_ALIASES[key] || key;

    if (!Object.prototype.hasOwnProperty.call(result, normalizedKey)) {
      return;
    }

    result[normalizedKey] =
      toFiniteNumber(result[normalizedKey]) + toFiniteNumber(raw[key]);
  });

  return result;
}

function toFiniteNumber(value) {
  const number = Number(value);

  if (!Number.isFinite(number)) {
    return 0;
  }

  return number;
}
