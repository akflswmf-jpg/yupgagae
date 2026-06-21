const admin = require("firebase-admin");
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const {
  buildAuditActor,
  createAuditLogInTransaction,
} = require("./audit_log");

const db = admin.firestore();
const bucket = admin.storage().bucket();

const REGION = "asia-northeast3";
const REPORT_THRESHOLD = 3;
const MAX_REASON_LENGTH = 60;

exports.deletePostOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 30,
    memory: "512MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    const postId = normalizeString(request.data && request.data.postId);

    if (!postId) {
      throw new HttpsError("invalid-argument", "게시글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();
    let extraImageObjectNames = [];
    let alreadyDeleted = false;

    await db.runTransaction(async (tx) => {
      const postRef = db.collection("posts").doc(postId);
      const postSnap = await tx.get(postRef);

      if (!postSnap.exists) {
        throw new HttpsError("not-found", "게시글을 찾을 수 없습니다.");
      }

      const post = postSnap.data() || {};
      const authorId = normalizeString(post.authorId);
      const currentStatus = normalizeString(post.status || "active");

      if (!authorId || authorId !== caller.userId) {
        throw new HttpsError("permission-denied", "삭제 권한이 없습니다.");
      }

      extraImageObjectNames = extractPostStorageObjectNames({
        postId,
        post,
      });

      alreadyDeleted =
        currentStatus === "deletedByAuthor" || post.deletedAt != null;

      if (alreadyDeleted) {
        return;
      }

      tx.update(postRef, {
        title: "삭제된 게시글입니다.",
        body: "",
        imageUrls: [],
        imagePaths: [],
        status: "deletedByAuthor",
        deletedAt: nowIso,
        updatedAt: nowIso,
        isSold: false,
      });

      createAuditLogInTransaction(tx, {
        eventType: "post.deleted_by_author",
        actor: buildAuditActor(caller),
        targetType: "post",
        targetId: postId,
        postId,
        targetAuthorId: authorId || "",
        previousStatus: currentStatus || "active",
        nextStatus: "deletedByAuthor",
        reason: "author_delete",
        createdAtIso: nowIso,
        metadata: {
          imageObjectCount: extraImageObjectNames.length,
        },
      });
    });

    const deletedImageCount = await deletePostImagesForPost({
      postId,
      extraObjectNames: extraImageObjectNames,
    });

    return {
      ok: true,
      postId,
      status: "deletedByAuthor",
      alreadyDeleted,
      deletedImageCount,
    };
  }
);

exports.removePostByAdminOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 30,
    memory: "512MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    assertAdmin(caller);

    const postId = normalizeString(request.data && request.data.postId);

    if (!postId) {
      throw new HttpsError("invalid-argument", "게시글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();
    let extraImageObjectNames = [];
    let alreadyRemoved = false;
    let removedReason = "관리자에 의해 제거된 게시글입니다.";

    await db.runTransaction(async (tx) => {
      const postRef = db.collection("posts").doc(postId);
      const postSnap = await tx.get(postRef);

      if (!postSnap.exists) {
        throw new HttpsError("not-found", "게시글을 찾을 수 없습니다.");
      }

      const post = postSnap.data() || {};
      const currentStatus = normalizeString(post.status || "active");
      const currentRemovedReason = normalizeString(post.adminRemovedReason);

      extraImageObjectNames = extractPostStorageObjectNames({
        postId,
        post,
      });

      alreadyRemoved =
        currentStatus === "removedByAdmin" || post.adminRemovedAt != null;

      removedReason =
        currentRemovedReason ||
        getPrimaryReportReason(post) ||
        "관리자에 의해 제거된 게시글입니다.";

      if (alreadyRemoved) {
        return;
      }

      tx.update(postRef, {
        status: "removedByAdmin",
        isReportThresholdReached: false,
        isHiddenByAdmin: false,
        adminHiddenReason: null,
        adminHiddenAt: null,
        adminRemovedAt: nowIso,
        adminRemovedReason: removedReason,
        imageUrls: [],
        imagePaths: [],
        updatedAt: nowIso,
        isSold: false,
      });

      const actionRef = db.collection("admin_actions").doc();

      tx.set(actionRef, {
        id: actionRef.id,
        targetType: "post",
        targetId: postId,
        actionType: "remove",
        previousStatus: currentStatus || "active",
        nextStatus: "removedByAdmin",
        reason: removedReason,
        createdAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "post.removed_by_admin",
        actor: buildAuditActor(caller),
        targetType: "post",
        targetId: postId,
        postId,
        targetAuthorId: normalizeString(post.authorId),
        actionType: "remove",
        previousStatus: currentStatus || "active",
        nextStatus: "removedByAdmin",
        reason: removedReason,
        createdAtIso: nowIso,
        metadata: {
          adminActionId: actionRef.id,
          imageObjectCount: extraImageObjectNames.length,
        },
      });
    });

    const deletedImageCount = await deletePostImagesForPost({
      postId,
      extraObjectNames: extraImageObjectNames,
    });

    return {
      ok: true,
      postId,
      status: "removedByAdmin",
      alreadyRemoved,
      deletedImageCount,
    };
  }
);

exports.hidePostByAdminOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    assertAdmin(caller);

    const postId = normalizeString(request.data && request.data.postId);

    if (!postId) {
      throw new HttpsError("invalid-argument", "게시글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();

    await db.runTransaction(async (tx) => {
      const postRef = db.collection("posts").doc(postId);
      const postSnap = await tx.get(postRef);

      if (!postSnap.exists) {
        throw new HttpsError("not-found", "게시글을 찾을 수 없습니다.");
      }

      const post = postSnap.data() || {};
      const currentStatus = normalizeString(post.status || "active");

      if (
        currentStatus === "deletedByAuthor" ||
        currentStatus === "removedByAdmin" ||
        post.deletedAt != null ||
        post.adminRemovedAt != null
      ) {
        throw new HttpsError(
          "failed-precondition",
          "삭제 또는 제거된 게시글은 숨김 처리할 수 없습니다."
        );
      }

      if (post.isHiddenByAdmin === true && currentStatus === "hiddenByAdmin") {
        return;
      }

      const hiddenReason = getPrimaryReportReason(post) || "운영 정책 위반 가능성";

      tx.update(postRef, {
        isHiddenByAdmin: true,
        status: "hiddenByAdmin",
        adminHiddenReason: hiddenReason,
        adminHiddenAt: nowIso,
        updatedAt: nowIso,
      });

      const actionRef = db.collection("admin_actions").doc();

      tx.set(actionRef, {
        id: actionRef.id,
        targetType: "post",
        targetId: postId,
        actionType: "hide",
        previousStatus: currentStatus || "active",
        nextStatus: "hiddenByAdmin",
        reason: hiddenReason,
        createdAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "post.hidden_by_admin",
        actor: buildAuditActor(caller),
        targetType: "post",
        targetId: postId,
        postId,
        targetAuthorId: normalizeString(post.authorId),
        actionType: "hide",
        previousStatus: currentStatus || "active",
        nextStatus: "hiddenByAdmin",
        reason: hiddenReason,
        reportCount: normalizeCount(post.reportCount),
        createdAtIso: nowIso,
        metadata: {
          adminActionId: actionRef.id,
        },
      });
    });

    return {
      ok: true,
      postId,
      status: "hiddenByAdmin",
    };
  }
);

exports.unhidePostByAdminOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    assertAdmin(caller);

    const postId = normalizeString(request.data && request.data.postId);

    if (!postId) {
      throw new HttpsError("invalid-argument", "게시글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();

    await db.runTransaction(async (tx) => {
      const postRef = db.collection("posts").doc(postId);
      const postSnap = await tx.get(postRef);

      if (!postSnap.exists) {
        throw new HttpsError("not-found", "게시글을 찾을 수 없습니다.");
      }

      const post = postSnap.data() || {};
      const currentStatus = normalizeString(post.status || "active");

      if (
        currentStatus === "deletedByAuthor" ||
        currentStatus === "removedByAdmin" ||
        post.deletedAt != null ||
        post.adminRemovedAt != null
      ) {
        throw new HttpsError(
          "failed-precondition",
          "삭제 또는 제거된 게시글은 숨김 해제할 수 없습니다."
        );
      }

      const nextStatus =
        post.isReportThresholdReached === true ? "hiddenByReport" : "active";

      tx.update(postRef, {
        isHiddenByAdmin: false,
        status: nextStatus,
        adminHiddenReason: null,
        adminHiddenAt: null,
        updatedAt: nowIso,
      });

      const actionRef = db.collection("admin_actions").doc();

      tx.set(actionRef, {
        id: actionRef.id,
        targetType: "post",
        targetId: postId,
        actionType: "unhide",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason: "관리자 숨김 해제",
        createdAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "post.unhidden_by_admin",
        actor: buildAuditActor(caller),
        targetType: "post",
        targetId: postId,
        postId,
        targetAuthorId: normalizeString(post.authorId),
        actionType: "unhide",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason: "관리자 숨김 해제",
        reportCount: normalizeCount(post.reportCount),
        createdAtIso: nowIso,
        metadata: {
          adminActionId: actionRef.id,
        },
      });
    });

    return {
      ok: true,
      postId,
    };
  }
);

exports.clearPostReportThresholdByAdminOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    assertAdmin(caller);

    const postId = normalizeString(request.data && request.data.postId);

    if (!postId) {
      throw new HttpsError("invalid-argument", "게시글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();

    await db.runTransaction(async (tx) => {
      const postRef = db.collection("posts").doc(postId);
      const postSnap = await tx.get(postRef);

      if (!postSnap.exists) {
        throw new HttpsError("not-found", "게시글을 찾을 수 없습니다.");
      }

      const post = postSnap.data() || {};
      const currentStatus = normalizeString(post.status || "active");

      if (
        currentStatus === "deletedByAuthor" ||
        currentStatus === "removedByAdmin" ||
        post.deletedAt != null ||
        post.adminRemovedAt != null
      ) {
        throw new HttpsError(
          "failed-precondition",
          "삭제 또는 제거된 게시글은 신고 블라인드를 해제할 수 없습니다."
        );
      }

      const nextStatus = post.isHiddenByAdmin === true ? "hiddenByAdmin" : "active";

      tx.update(postRef, {
        isReportThresholdReached: false,
        status: nextStatus,
        updatedAt: nowIso,
      });

      const actionRef = db.collection("admin_actions").doc();

      tx.set(actionRef, {
        id: actionRef.id,
        targetType: "post",
        targetId: postId,
        actionType: "clearReportThreshold",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason: "신고 블라인드 해제",
        reportCount: normalizeCount(post.reportCount),
        createdAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "post.report_threshold_cleared_by_admin",
        actor: buildAuditActor(caller),
        targetType: "post",
        targetId: postId,
        postId,
        targetAuthorId: normalizeString(post.authorId),
        actionType: "clearReportThreshold",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason: "신고 블라인드 해제",
        reportCount: normalizeCount(post.reportCount),
        createdAtIso: nowIso,
        metadata: {
          adminActionId: actionRef.id,
        },
      });
    });

    return {
      ok: true,
      postId,
    };
  }
);

exports.deleteCommentOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    const postId = normalizeString(request.data && request.data.postId);
    const commentId = normalizeString(request.data && request.data.commentId);

    if (!postId || !commentId) {
      throw new HttpsError("invalid-argument", "댓글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();
    let alreadyDeleted = false;

    await db.runTransaction(async (tx) => {
      const postRef = db.collection("posts").doc(postId);
      const commentRef = db.collection("comments").doc(commentId);
      const postSnap = await tx.get(postRef);
      const commentSnap = await tx.get(commentRef);

      if (!postSnap.exists || !commentSnap.exists) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      const post = postSnap.data() || {};
      const comment = commentSnap.data() || {};
      const currentStatus = normalizeString(comment.status || "active");

      if (normalizeString(comment.postId) !== postId) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      if (normalizeString(comment.authorId) !== caller.userId) {
        throw new HttpsError("permission-denied", "삭제 권한이 없습니다.");
      }

      alreadyDeleted =
        comment.isDeleted === true ||
        currentStatus === "deletedByAuthor" ||
        comment.deletedAt != null;

      if (alreadyDeleted) {
        return;
      }

      const currentCommentCount = normalizeCount(post.commentCount);
      const nextCommentCount = Math.max(0, currentCommentCount - 1);

      tx.update(commentRef, {
        text: "삭제된 댓글입니다.",
        isDeleted: true,
        status: "deletedByAuthor",
        deletedAt: nowIso,
        updatedAt: nowIso,
      });

      tx.update(postRef, {
        commentCount: nextCommentCount,
        updatedAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "comment.deleted_by_author",
        actor: buildAuditActor(caller),
        targetType: "comment",
        targetId: commentId,
        postId,
        commentId,
        targetAuthorId: normalizeString(comment.authorId),
        previousStatus: currentStatus || "active",
        nextStatus: "deletedByAuthor",
        reason: "author_delete",
        createdAtIso: nowIso,
        metadata: {
          previousCommentCount: currentCommentCount,
          nextCommentCount,
        },
      });
    });

    return {
      ok: true,
      postId,
      commentId,
      status: "deletedByAuthor",
      alreadyDeleted,
    };
  }
);

exports.hideCommentByAdminOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    assertAdmin(caller);

    const postId = normalizeString(request.data && request.data.postId);
    const commentId = normalizeString(request.data && request.data.commentId);

    if (!postId || !commentId) {
      throw new HttpsError("invalid-argument", "댓글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();

    await db.runTransaction(async (tx) => {
      const commentRef = db.collection("comments").doc(commentId);
      const commentSnap = await tx.get(commentRef);

      if (!commentSnap.exists) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      const comment = commentSnap.data() || {};
      const currentStatus = normalizeString(comment.status || "active");

      if (normalizeString(comment.postId) !== postId) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      if (
        comment.isDeleted === true ||
        currentStatus === "deletedByAuthor" ||
        currentStatus === "removedByAdmin" ||
        comment.deletedAt != null ||
        comment.adminRemovedAt != null
      ) {
        throw new HttpsError(
          "failed-precondition",
          "삭제 또는 제거된 댓글은 숨김 처리할 수 없습니다."
        );
      }

      const hiddenReason = getPrimaryReportReason(comment) || "운영 정책 위반 가능성";

      tx.update(commentRef, {
        isHiddenByAdmin: true,
        status: "hiddenByAdmin",
        adminHiddenReason: hiddenReason,
        adminHiddenAt: nowIso,
        updatedAt: nowIso,
      });

      const actionRef = db.collection("admin_actions").doc();

      tx.set(actionRef, {
        id: actionRef.id,
        targetType: "comment",
        targetId: commentId,
        postId,
        actionType: "hide",
        previousStatus: currentStatus || "active",
        nextStatus: "hiddenByAdmin",
        reason: hiddenReason,
        createdAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "comment.hidden_by_admin",
        actor: buildAuditActor(caller),
        targetType: "comment",
        targetId: commentId,
        postId,
        commentId,
        targetAuthorId: normalizeString(comment.authorId),
        actionType: "hide",
        previousStatus: currentStatus || "active",
        nextStatus: "hiddenByAdmin",
        reason: hiddenReason,
        reportCount: normalizeCount(comment.reportCount),
        createdAtIso: nowIso,
        metadata: {
          adminActionId: actionRef.id,
        },
      });
    });

    return {
      ok: true,
      postId,
      commentId,
      status: "hiddenByAdmin",
    };
  }
);

exports.unhideCommentByAdminOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    assertAdmin(caller);

    const postId = normalizeString(request.data && request.data.postId);
    const commentId = normalizeString(request.data && request.data.commentId);

    if (!postId || !commentId) {
      throw new HttpsError("invalid-argument", "댓글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();

    await db.runTransaction(async (tx) => {
      const commentRef = db.collection("comments").doc(commentId);
      const commentSnap = await tx.get(commentRef);

      if (!commentSnap.exists) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      const comment = commentSnap.data() || {};
      const currentStatus = normalizeString(comment.status || "active");

      if (normalizeString(comment.postId) !== postId) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      if (
        comment.isDeleted === true ||
        currentStatus === "deletedByAuthor" ||
        currentStatus === "removedByAdmin" ||
        comment.deletedAt != null ||
        comment.adminRemovedAt != null
      ) {
        throw new HttpsError(
          "failed-precondition",
          "삭제 또는 제거된 댓글은 숨김 해제할 수 없습니다."
        );
      }

      const nextStatus =
        comment.isReportThresholdReached === true ? "hiddenByReport" : "active";

      tx.update(commentRef, {
        isHiddenByAdmin: false,
        status: nextStatus,
        adminHiddenReason: null,
        adminHiddenAt: null,
        updatedAt: nowIso,
      });

      const actionRef = db.collection("admin_actions").doc();

      tx.set(actionRef, {
        id: actionRef.id,
        targetType: "comment",
        targetId: commentId,
        postId,
        actionType: "unhide",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason: "관리자 숨김 해제",
        createdAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "comment.unhidden_by_admin",
        actor: buildAuditActor(caller),
        targetType: "comment",
        targetId: commentId,
        postId,
        commentId,
        targetAuthorId: normalizeString(comment.authorId),
        actionType: "unhide",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason: "관리자 숨김 해제",
        reportCount: normalizeCount(comment.reportCount),
        createdAtIso: nowIso,
        metadata: {
          adminActionId: actionRef.id,
        },
      });
    });

    return {
      ok: true,
      postId,
      commentId,
    };
  }
);

exports.clearCommentReportThresholdByAdminOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    assertAdmin(caller);

    const postId = normalizeString(request.data && request.data.postId);
    const commentId = normalizeString(request.data && request.data.commentId);

    if (!postId || !commentId) {
      throw new HttpsError("invalid-argument", "댓글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();

    await db.runTransaction(async (tx) => {
      const commentRef = db.collection("comments").doc(commentId);
      const commentSnap = await tx.get(commentRef);

      if (!commentSnap.exists) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      const comment = commentSnap.data() || {};
      const currentStatus = normalizeString(comment.status || "active");

      if (normalizeString(comment.postId) !== postId) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      if (
        comment.isDeleted === true ||
        currentStatus === "deletedByAuthor" ||
        currentStatus === "removedByAdmin" ||
        comment.deletedAt != null ||
        comment.adminRemovedAt != null
      ) {
        throw new HttpsError(
          "failed-precondition",
          "삭제 또는 제거된 댓글은 신고 블라인드를 해제할 수 없습니다."
        );
      }

      const nextStatus =
        comment.isHiddenByAdmin === true ? "hiddenByAdmin" : "active";

      tx.update(commentRef, {
        isReportThresholdReached: false,
        status: nextStatus,
        updatedAt: nowIso,
      });

      const actionRef = db.collection("admin_actions").doc();

      tx.set(actionRef, {
        id: actionRef.id,
        targetType: "comment",
        targetId: commentId,
        postId,
        actionType: "clearReportThreshold",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason: "신고 블라인드 해제",
        reportCount: normalizeCount(comment.reportCount),
        createdAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "comment.report_threshold_cleared_by_admin",
        actor: buildAuditActor(caller),
        targetType: "comment",
        targetId: commentId,
        postId,
        commentId,
        targetAuthorId: normalizeString(comment.authorId),
        actionType: "clearReportThreshold",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason: "신고 블라인드 해제",
        reportCount: normalizeCount(comment.reportCount),
        createdAtIso: nowIso,
        metadata: {
          adminActionId: actionRef.id,
        },
      });
    });

    return {
      ok: true,
      postId,
      commentId,
    };
  }
);

exports.removeCommentByAdminOnServer = onCall(
  {
    region: REGION,
    timeoutSeconds: 15,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);
    assertAdmin(caller);

    const postId = normalizeString(request.data && request.data.postId);
    const commentId = normalizeString(request.data && request.data.commentId);

    if (!postId || !commentId) {
      throw new HttpsError("invalid-argument", "댓글 정보를 찾을 수 없습니다.");
    }

    const nowIso = new Date().toISOString();

    await db.runTransaction(async (tx) => {
      const commentRef = db.collection("comments").doc(commentId);
      const commentSnap = await tx.get(commentRef);

      if (!commentSnap.exists) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      const comment = commentSnap.data() || {};
      const currentStatus = normalizeString(comment.status || "active");

      if (normalizeString(comment.postId) !== postId) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      if (currentStatus === "removedByAdmin" || comment.adminRemovedAt != null) {
        return;
      }

      const removedReason = getPrimaryReportReason(comment) || "관리자 제거 처리";

      tx.update(commentRef, {
        status: "removedByAdmin",
        isReportThresholdReached: false,
        isHiddenByAdmin: false,
        adminHiddenReason: null,
        adminHiddenAt: null,
        adminRemovedAt: nowIso,
        adminRemovedReason: removedReason,
        updatedAt: nowIso,
      });

      const actionRef = db.collection("admin_actions").doc();

      tx.set(actionRef, {
        id: actionRef.id,
        targetType: "comment",
        targetId: commentId,
        postId,
        actionType: "remove",
        previousStatus: currentStatus || "active",
        nextStatus: "removedByAdmin",
        reason: removedReason,
        createdAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "comment.removed_by_admin",
        actor: buildAuditActor(caller),
        targetType: "comment",
        targetId: commentId,
        postId,
        commentId,
        targetAuthorId: normalizeString(comment.authorId),
        actionType: "remove",
        previousStatus: currentStatus || "active",
        nextStatus: "removedByAdmin",
        reason: removedReason,
        reportCount: normalizeCount(comment.reportCount),
        createdAtIso: nowIso,
        metadata: {
          adminActionId: actionRef.id,
        },
      });
    });

    return {
      ok: true,
      postId,
      commentId,
      status: "removedByAdmin",
    };
  }
);

exports.reportPost = onCall(
  {
    region: REGION,
    timeoutSeconds: 10,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);

    const postId = normalizeString(request.data && request.data.postId);
    const reason = normalizeReportReason(request.data && request.data.reason);

    if (!postId) {
      throw new HttpsError("invalid-argument", "게시글 정보를 찾을 수 없습니다.");
    }

    if (!reason) {
      throw new HttpsError("invalid-argument", "신고 사유를 선택하세요.");
    }

    const result = await db.runTransaction(async (tx) => {
      const postRef = db.collection("posts").doc(postId);
      const postSnap = await tx.get(postRef);

      if (!postSnap.exists) {
        throw new HttpsError("not-found", "게시글을 찾을 수 없습니다.");
      }

      const post = postSnap.data() || {};
      const authorId = normalizeString(post.authorId);
      const currentStatus = normalizeString(post.status || "active");

      if (isPostClosedForReport(post)) {
        throw new HttpsError(
          "failed-precondition",
          "이미 숨김 처리된 게시글입니다."
        );
      }

      if (authorId && authorId === caller.userId) {
        throw new HttpsError(
          "failed-precondition",
          "본인 글은 신고할 수 없습니다."
        );
      }

      const reportId = makeReportId({
        targetType: "post",
        targetId: postId,
        reporterId: caller.userId,
      });

      const reportRef = db.collection("reports").doc(reportId);
      const reportSnap = await tx.get(reportRef);

      if (reportSnap.exists) {
        throw new HttpsError("already-exists", "이미 신고한 게시글입니다.");
      }

      const reportedUserIds = normalizeStringSet(post.reportedUserIds);

      if (reportedUserIds.has(caller.userId)) {
        throw new HttpsError("already-exists", "이미 신고한 게시글입니다.");
      }

      reportedUserIds.add(caller.userId);

      const reportReasons = normalizeStringArray(post.reportReasons);
      reportReasons.push(reason);

      const reportReasonCounts = normalizeCountMap(post.reportReasonCounts);
      reportReasonCounts[reason] = (reportReasonCounts[reason] || 0) + 1;

      const previousReportCount = normalizeCount(post.reportCount);
      const nextReportCount = previousReportCount + 1;

      const thresholdReached =
        post.isReportThresholdReached === true ||
        nextReportCount >= REPORT_THRESHOLD;

      const nowIso = new Date().toISOString();

      const nextStatus = thresholdReached
        ? "hiddenByReport"
        : currentStatus || "active";

      tx.set(reportRef, {
        id: reportId,
        targetType: "post",
        targetId: postId,
        postId,
        commentId: null,
        reporterId: caller.userId,
        targetAuthorId: authorId || "",
        reason,
        status: thresholdReached ? "autoHidden" : "pending",
        createdAt: nowIso,
        handledAt: null,
        handledBy: null,
      });

      tx.update(postRef, {
        reportCount: nextReportCount,
        reportedUserIds: Array.from(reportedUserIds),
        reportReasons,
        reportReasonCounts,
        isReportThresholdReached: thresholdReached,
        status: nextStatus,
        updatedAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "post.reported",
        actor: buildAuditActor(caller),
        targetType: "post",
        targetId: postId,
        postId,
        targetAuthorId: authorId || "",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason,
        reportCount: nextReportCount,
        createdAtIso: nowIso,
        metadata: {
          reportId,
          thresholdReached,
        },
      });

      if (thresholdReached) {
        const actionRef = db.collection("admin_actions").doc();

        tx.set(actionRef, {
          id: actionRef.id,
          targetType: "post",
          targetId: postId,
          actionType: "autoHideByReport",
          previousStatus: currentStatus || "active",
          nextStatus: "hiddenByReport",
          reason,
          reportCount: nextReportCount,
          createdAt: nowIso,
        });

        createAuditLogInTransaction(tx, {
          eventType: "post.auto_hidden_by_report",
          actor: buildAuditActor(caller),
          targetType: "post",
          targetId: postId,
          postId,
          targetAuthorId: authorId || "",
          actionType: "autoHideByReport",
          previousStatus: currentStatus || "active",
          nextStatus: "hiddenByReport",
          reason,
          reportCount: nextReportCount,
          createdAtIso: nowIso,
          metadata: {
            adminActionId: actionRef.id,
            reportId,
          },
        });
      }

      return {
        reportCount: nextReportCount,
        isReportThresholdReached: thresholdReached,
      };
    });

    return {
      ok: true,
      ...result,
    };
  }
);

exports.reportComment = onCall(
  {
    region: REGION,
    timeoutSeconds: 10,
    memory: "256MiB",
    maxInstances: 20,
    invoker: "public",
  },
  async (request) => {
    const caller = await resolveCaller(request);

    const postId = normalizeString(request.data && request.data.postId);
    const commentId = normalizeString(request.data && request.data.commentId);
    const reason = normalizeReportReason(request.data && request.data.reason);

    if (!postId || !commentId) {
      throw new HttpsError("invalid-argument", "댓글 정보를 찾을 수 없습니다.");
    }

    if (!reason) {
      throw new HttpsError("invalid-argument", "신고 사유를 선택하세요.");
    }

    const result = await db.runTransaction(async (tx) => {
      const commentRef = db.collection("comments").doc(commentId);
      const commentSnap = await tx.get(commentRef);

      if (!commentSnap.exists) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      const comment = commentSnap.data() || {};
      const commentPostId = normalizeString(comment.postId);
      const authorId = normalizeString(comment.authorId);
      const currentStatus = normalizeString(comment.status || "active");

      if (commentPostId !== postId) {
        throw new HttpsError("not-found", "댓글을 찾을 수 없습니다.");
      }

      if (isCommentClosedForReport(comment)) {
        throw new HttpsError(
          "failed-precondition",
          "이미 숨김 처리된 댓글입니다."
        );
      }

      if (authorId && authorId === caller.userId) {
        throw new HttpsError(
          "failed-precondition",
          "본인 댓글은 신고할 수 없습니다."
        );
      }

      const reportId = makeReportId({
        targetType: "comment",
        targetId: commentId,
        reporterId: caller.userId,
      });

      const reportRef = db.collection("reports").doc(reportId);
      const reportSnap = await tx.get(reportRef);

      if (reportSnap.exists) {
        throw new HttpsError("already-exists", "이미 신고한 댓글입니다.");
      }

      const reportedUserIds = normalizeStringSet(comment.reportedUserIds);

      if (reportedUserIds.has(caller.userId)) {
        throw new HttpsError("already-exists", "이미 신고한 댓글입니다.");
      }

      reportedUserIds.add(caller.userId);

      const reportReasons = normalizeStringArray(comment.reportReasons);
      reportReasons.push(reason);

      const reportReasonCounts = normalizeCountMap(comment.reportReasonCounts);
      reportReasonCounts[reason] = (reportReasonCounts[reason] || 0) + 1;

      const previousReportCount = normalizeCount(comment.reportCount);
      const nextReportCount = previousReportCount + 1;

      const thresholdReached =
        comment.isReportThresholdReached === true ||
        nextReportCount >= REPORT_THRESHOLD;

      const nowIso = new Date().toISOString();

      const nextStatus = thresholdReached
        ? "hiddenByReport"
        : currentStatus || "active";

      tx.set(reportRef, {
        id: reportId,
        targetType: "comment",
        targetId: commentId,
        postId,
        commentId,
        reporterId: caller.userId,
        targetAuthorId: authorId || "",
        reason,
        status: thresholdReached ? "autoHidden" : "pending",
        createdAt: nowIso,
        handledAt: null,
        handledBy: null,
      });

      tx.update(commentRef, {
        reportCount: nextReportCount,
        reportedUserIds: Array.from(reportedUserIds),
        reportReasons,
        reportReasonCounts,
        isReportThresholdReached: thresholdReached,
        status: nextStatus,
        updatedAt: nowIso,
      });

      createAuditLogInTransaction(tx, {
        eventType: "comment.reported",
        actor: buildAuditActor(caller),
        targetType: "comment",
        targetId: commentId,
        postId,
        commentId,
        targetAuthorId: authorId || "",
        previousStatus: currentStatus || "active",
        nextStatus,
        reason,
        reportCount: nextReportCount,
        createdAtIso: nowIso,
        metadata: {
          reportId,
          thresholdReached,
        },
      });

      if (thresholdReached) {
        const actionRef = db.collection("admin_actions").doc();

        tx.set(actionRef, {
          id: actionRef.id,
          targetType: "comment",
          targetId: commentId,
          postId,
          actionType: "autoHideByReport",
          previousStatus: currentStatus || "active",
          nextStatus: "hiddenByReport",
          reason,
          reportCount: nextReportCount,
          createdAt: nowIso,
        });

        createAuditLogInTransaction(tx, {
          eventType: "comment.auto_hidden_by_report",
          actor: buildAuditActor(caller),
          targetType: "comment",
          targetId: commentId,
          postId,
          commentId,
          targetAuthorId: authorId || "",
          actionType: "autoHideByReport",
          previousStatus: currentStatus || "active",
          nextStatus: "hiddenByReport",
          reason,
          reportCount: nextReportCount,
          createdAtIso: nowIso,
          metadata: {
            adminActionId: actionRef.id,
            reportId,
          },
        });
      }

      return {
        reportCount: nextReportCount,
        isReportThresholdReached: thresholdReached,
      };
    });

    return {
      ok: true,
      ...result,
    };
  }
);

async function resolveCaller(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요한 기능입니다.");
  }

  const firebaseUid = normalizeString(request.auth.uid);
  const authLinkRef = db.collection("auth_links").doc(firebaseUid);
  const authLinkSnap = await authLinkRef.get();

  if (!authLinkSnap.exists) {
    throw new HttpsError("permission-denied", "로그인이 필요한 기능입니다.");
  }

  const authLink = authLinkSnap.data() || {};
  const userId = normalizeString(authLink.userId);

  if (!userId) {
    throw new HttpsError("permission-denied", "로그인이 필요한 기능입니다.");
  }

  const userRef = db.collection("users").doc(userId);
  const userSnap = await userRef.get();

  if (!userSnap.exists) {
    throw new HttpsError("permission-denied", "사용자 정보를 찾을 수 없습니다.");
  }

  const user = userSnap.data() || {};

  if (normalizeString(user.firebaseUid) !== firebaseUid) {
    throw new HttpsError("permission-denied", "사용자 정보가 일치하지 않습니다.");
  }

  if (normalizeString(user.status) !== "active") {
    throw new HttpsError("permission-denied", "정상 이용 가능한 계정이 아닙니다.");
  }

  if (user.isDeleted === true) {
    throw new HttpsError("permission-denied", "탈퇴 처리된 계정입니다.");
  }

  if (user.profileSetupCompleted !== true) {
    throw new HttpsError("failed-precondition", "가입 설정을 먼저 완료해주세요.");
  }

  return {
    userId,
    firebaseUid,
    user,
  };
}

function isPostClosedForReport(post) {
  const status = normalizeString(post.status);

  return (
    status === "hiddenByReport" ||
    status === "hiddenByAdmin" ||
    status === "deletedByAuthor" ||
    status === "removedByAdmin" ||
    post.isReportThresholdReached === true ||
    post.isHiddenByAdmin === true ||
    post.deletedAt != null ||
    post.adminRemovedAt != null
  );
}

function isCommentClosedForReport(comment) {
  const status = normalizeString(comment.status);

  return (
    status === "hiddenByReport" ||
    status === "hiddenByAdmin" ||
    status === "deletedByAuthor" ||
    status === "removedByAdmin" ||
    comment.isReportThresholdReached === true ||
    comment.isHiddenByAdmin === true ||
    comment.isDeleted === true ||
    comment.deletedAt != null ||
    comment.adminRemovedAt != null
  );
}

function makeReportId({ targetType, targetId, reporterId }) {
  return `${targetType}_${targetId}_${reporterId}`;
}

function assertAdmin(caller) {
  const role = normalizeString(caller && caller.user && caller.user.role);

  if (role !== "admin") {
    throw new HttpsError("permission-denied", "관리자 권한이 필요합니다.");
  }
}

async function deletePostImagesForPost({
  postId,
  extraObjectNames,
}) {
  const safePostId = normalizeString(postId);

  if (!safePostId) {
    return 0;
  }

  const prefix = `posts/${safePostId}/images/`;
  let deletedCount = 0;

  try {
    const [files] = await bucket.getFiles({
      prefix,
    });

    if (files.length > 0) {
      await Promise.all(
        files.map((file) =>
          file.delete({
            ignoreNotFound: true,
          })
        )
      );

      deletedCount += files.length;
    }
  } catch (error) {
    throw new HttpsError(
      "internal",
      "게시글 이미지를 삭제하는 중 문제가 발생했습니다."
    );
  }

  const extraNames = normalizeStringArray(extraObjectNames)
    .map((item) => normalizeStorageObjectName(item))
    .filter((item) => item.length > 0)
    .filter((item) => item.startsWith(prefix));

  const uniqueExtraNames = Array.from(new Set(extraNames));

  for (const objectName of uniqueExtraNames) {
    try {
      await bucket.file(objectName).delete({
        ignoreNotFound: true,
      });

      deletedCount += 1;
    } catch (error) {
      const code = error && error.code ? String(error.code) : "";

      if (code === "404") {
        continue;
      }

      throw new HttpsError(
        "internal",
        "게시글 이미지를 삭제하는 중 문제가 발생했습니다."
      );
    }
  }

  return deletedCount;
}

function extractPostStorageObjectNames({ postId, post }) {
  const safePostId = normalizeString(postId);

  if (!safePostId || !post || typeof post !== "object") {
    return [];
  }

  const rawValues = [
    ...normalizeStringArray(post.imagePaths),
    ...normalizeStringArray(post.imageUrls),
  ];

  const prefix = `posts/${safePostId}/images/`;
  const result = [];

  rawValues.forEach((rawValue) => {
    const objectName = normalizeStorageObjectName(rawValue);

    if (!objectName) {
      return;
    }

    if (!objectName.startsWith(prefix)) {
      return;
    }

    result.push(objectName);
  });

  return Array.from(new Set(result));
}

function normalizeStorageObjectName(value) {
  const raw = normalizeString(value);

  if (!raw) {
    return "";
  }

  if (raw.startsWith("gs://")) {
    const withoutScheme = raw.slice("gs://".length);
    const slashIndex = withoutScheme.indexOf("/");

    if (slashIndex < 0) {
      return "";
    }

    return decodeURIComponent(withoutScheme.slice(slashIndex + 1)).trim();
  }

  const encodedMarker = "/o/";
  const markerIndex = raw.indexOf(encodedMarker);

  if (markerIndex >= 0) {
    const afterMarker = raw.slice(markerIndex + encodedMarker.length);
    const queryIndex = afterMarker.indexOf("?");

    const encodedPath =
      queryIndex >= 0 ? afterMarker.slice(0, queryIndex) : afterMarker;

    try {
      return decodeURIComponent(encodedPath).trim();
    } catch (_) {
      return "";
    }
  }

  if (raw.startsWith("posts/")) {
    return raw;
  }

  return "";
}

function buildPostAuditSnapshot(post) {
  const src = post && typeof post === "object" ? post : {};

  return {
    postTitlePreview: truncateAuditText(src.title, 80),
    postBodyPreview: truncateAuditText(src.body, 120),
    boardType: normalizeString(src.boardType) || null,
    usedType: normalizeString(src.usedType) || null,
    targetAuthorId: normalizeString(src.authorId) || null,
    targetAuthorLabel: normalizeString(src.authorLabel) || null,
    targetIndustryId: normalizeString(src.industryId) || null,
    targetLocationLabel: normalizeString(src.locationLabel) || null,
    status: normalizeString(src.status) || null,
    reportCount: normalizeCount(src.reportCount),
  };
}

function buildCommentAuditSnapshot(comment) {
  const src = comment && typeof comment === "object" ? comment : {};

  return {
    commentTextPreview: truncateAuditText(src.text, 120),
    parentId: normalizeString(src.parentId) || null,
    postId: normalizeString(src.postId) || null,
    targetAuthorId: normalizeString(src.authorId) || null,
    targetAuthorLabel: normalizeString(src.authorLabel) || null,
    targetIndustryId: normalizeString(src.industryId) || null,
    targetLocationLabel: normalizeString(src.locationLabel) || null,
    status: normalizeString(src.status) || null,
    reportCount: normalizeCount(src.reportCount),
  };
}

function truncateAuditText(value, maxLength) {
  const text = normalizeString(value)
    .replace(/\s+/g, " ")
    .trim();

  if (!text) {
    return null;
  }

  if (text.length <= maxLength) {
    return text;
  }

  return `${text.slice(0, maxLength)}…`;
}
function getPrimaryReportReason(value) {
  const src = value && typeof value === "object" ? value : {};
  const counts = normalizeCountMap(src.reportReasonCounts);

  let bestReason = "";
  let bestCount = 0;

  Object.entries(counts).forEach(([reason, count]) => {
    if (count > bestCount) {
      bestReason = reason;
      bestCount = count;
    }
  });

  if (bestReason) {
    return bestReason;
  }

  const reasons = normalizeStringArray(src.reportReasons);
  return reasons.length > 0 ? reasons[0] : "";
}

function normalizeReportReason(value) {
  const reason = normalizeString(value);

  if (!reason) {
    return "";
  }

  if (reason.length > MAX_REASON_LENGTH) {
    return reason.slice(0, MAX_REASON_LENGTH);
  }

  return reason;
}

function normalizeString(value) {
  if (value === undefined || value === null) {
    return "";
  }

  return String(value).trim();
}

function normalizeStringArray(value) {
  if (!Array.isArray(value)) {
    return [];
  }

  return value
    .map((item) => normalizeString(item))
    .filter((item) => item.length > 0);
}

function normalizeStringSet(value) {
  return new Set(normalizeStringArray(value));
}

function normalizeCount(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.max(0, Math.floor(value));
  }

  const parsed = Number(value);

  if (!Number.isFinite(parsed)) {
    return 0;
  }

  return Math.max(0, Math.floor(parsed));
}

function normalizeCountMap(value) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }

  const result = {};

  for (const [rawKey, rawValue] of Object.entries(value)) {
    const key = normalizeString(rawKey);
    const count = normalizeCount(rawValue);

    if (!key || count <= 0) {
      continue;
    }

    result[key] = count;
  }

  return result;
}