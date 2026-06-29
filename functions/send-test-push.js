// 일회성 테스트 푸시 발송 스크립트 (배포 대상 아님 / 로컬 전용)
//
// 사용법:
//   1) Firebase Console → 프로젝트 설정 → 서비스 계정 → "새 비공개 키 생성"
//      → 내려받은 JSON을 functions/serviceAccountKey.json 으로 저장
//   2) functions 디렉터리에서:
//        node send-test-push.js
//
//   userId 를 바꾸려면:  node send-test-push.js usr_xxxxx
//
// 키 파일은 절대 커밋하지 마세요 (.gitignore 확인).

const path = require("path");
const admin = require("firebase-admin");

const KEY_PATH =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, "serviceAccountKey.json");

const TARGET_USER_ID = process.argv[2] || "usr_1779000921321_a2dd38c469d8";

const PUSH_TOKEN_DOC_COLLECTION = "pushTokens";

function initAdmin() {
  let credential;
  try {
    // eslint-disable-next-line global-require, import/no-dynamic-require
    const serviceAccount = require(KEY_PATH);
    credential = admin.credential.cert(serviceAccount);
  } catch (e) {
    console.error(
      `\n[ERROR] 서비스 계정 키를 찾을 수 없습니다: ${KEY_PATH}\n` +
        `Firebase Console → 프로젝트 설정 → 서비스 계정 → "새 비공개 키 생성"으로\n` +
        `JSON을 받아 functions/serviceAccountKey.json 으로 저장한 뒤 다시 실행하세요.\n`
    );
    process.exit(1);
  }

  admin.initializeApp({ credential });
}

async function main() {
  initAdmin();

  const db = admin.firestore();

  const snapshot = await db
    .collection(PUSH_TOKEN_DOC_COLLECTION)
    .where("userId", "==", TARGET_USER_ID)
    .get();

  const tokens = [];
  snapshot.forEach((doc) => {
    const data = doc.data() || {};
    if (data.enabled === false) return;
    const token = (data.token || "").toString().trim();
    if (!token) return;
    tokens.push({ docId: doc.id, token, platform: data.platform || "" });
  });

  console.log(`userId=${TARGET_USER_ID} 대상 토큰 ${tokens.length}개 발견`);

  if (tokens.length === 0) {
    console.log("등록된 토큰이 없습니다. 앱 실행/로그인 후 다시 시도하세요.");
    process.exit(0);
  }

  const response = await admin.messaging().sendEachForMulticast({
    tokens: tokens.map((t) => t.token),
    notification: {
      title: "옆가게 테스트 알림",
      body: "푸시 알림 연결이 정상입니다.",
    },
    data: {
      type: "harugyeol",
      target: "harugyeol",
      source: "manual_test",
    },
    android: {
      priority: "high",
      notification: { channelId: "yupgagae_high", priority: "high" },
    },
    apns: {
      payload: { aps: { sound: "default", badge: 1 } },
    },
  });

  console.log(
    `발송 완료: success=${response.successCount}, failure=${response.failureCount}`
  );

  response.responses.forEach((r, i) => {
    if (r.success) {
      console.log(`  [OK]   ${tokens[i].platform} ${tokens[i].docId.slice(0, 12)}…`);
    } else {
      console.log(
        `  [FAIL] ${tokens[i].platform} ${tokens[i].docId.slice(0, 12)}… → ${
          r.error && r.error.code
        }`
      );
    }
  });

  process.exit(0);
}

main().catch((e) => {
  console.error("테스트 푸시 실패:", e);
  process.exit(1);
});
