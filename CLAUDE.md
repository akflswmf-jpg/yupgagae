# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# 실행
flutter run

# 빌드
flutter build apk
flutter build ios

# 분석 / 린트
flutter analyze

# 테스트
flutter test
flutter test test/widget_test.dart   # 단일 파일

# 아이콘 생성 (pubspec.yaml의 flutter_launcher_icons 설정 기반)
flutter pub run flutter_launcher_icons
```

## Project Rules

### 프로젝트 방향

- GetX 구조 유지, Repository 단일 진입 유지
- 기존 기능 제거 금지 — 동작 유지하면서 구조 개선
- 구조화 최우선 (나중에 큰 앵꼬 방지)
- 최소 MVP가 아닌 상용화 수준 목표
- 프레임 드랍 0 기준 — 성능 최적화 필수
- 더 나은 의견이 있으면 언제든지 제안할 것

### 아키텍처

- Controller는 UI를 몰라야 한다
- UI는 표시 역할만, 비즈니스 로직 금지
- Repository는 유일한 데이터 입구
- Controller는 화면 하나당 하나
- DI 생성은 Binding에서만
- argument + postId 병행 구조 유지

### 상태 관리

- `build`는 상태를 바꾸지 않는다
- `Obx`는 번거롭더라도 작게 나눈다 (불필요한 rebuild 최소화)
- 로딩/에러/데이터 상태를 항상 3개 세트로 관리: `isLoading`, `errorMessage`, `data`
- `RxList`, `RxMap`은 Controller 밖으로 읽기 전용으로만 노출

### 에러 처리

- Controller에서 `try/catch`로 에러 잡고 UI에는 에러 상태만 전달
- 사용자에게 보여주는 에러 메시지는 Controller가 결정, UI는 표시만
- 모든 Repository 메서드는 무조건 `try/catch`
- 오프라인 대응 고려 (Firebase 연동 시 필수)

### 코드 품질

- 매직 넘버 금지 — 숫자 직접 쓰지 말고 상수로
- TODO 주석에는 반드시 이유 포함
- 구조화를 위해 필요하면 기존 파일을 분할해도 됨

### 코드 제공 방식

- 매 답변마다 코드는 반드시 파일 통째로 (import부터) 제공 — 부분 제공 금지
- Ctrl+A → Ctrl+C → 붙여넣기로 즉시 교체 가능하게
- 파일 코드 줄 수가 기존보다 이상할 정도로 줄어들면 다시 검토
- 기존 파일 수정이 필요한 경우, 바로 코드 제시하지 말고 해당 파일 먼저 요청할 것

---

## Architecture

**Flutter + GetX** 기반 소상공인 커뮤니티 앱. 하단 탭 4개: 홈 · 커뮤니티 · 매출 · 내가게.

### 레이어 구조 (features/ 내 각 기능별 반복)

```
domain/     → 순수 모델 + 추상 Repository 인터페이스
data/       → In-memory 구현체 (현재는 로컬 JSON 파일로 persist)
controller/ → GetX Controller (상태 + 비즈니스 로직)
bindings/   → GetX Binding (DI 등록)
view/       → Screen + widgets/
service/    → 도메인 서비스 (ModerationService, SearchHistoryService 등)
policy/     → 순수 규칙 함수 (PostPolicy, ModerationPolicy)
```

### DI 흐름

`RootBinding` (앱 시작 시 1회 실행) → 전역 싱글턴 등록:
- `AnonSessionService` (permanent) — 익명 사용자 ID (`shared_preferences`로 영속)
- `PostRepository` → `InMemoryPostRepository`
- `StoreProfileRepository` → `InMemoryStoreProfileRepository`
- `PostListController`, `OwnerBoardController`, `HomeFeedController`
- `MyStoreBinding().dependencies()` / `RevenueBinding().dependencies()` (탭이 IndexedStack이라 앱 시작 시 선등록 필요)

각 내비게이션 전용 화면(글쓰기, 게시글 상세 등)은 `AppPages`의 `GetPage(binding: ...)` 으로 화면 진입 시점에 등록.

### 현재 데이터 저장 방식

백엔드 없음. 모든 데이터는 인메모리 + 로컬 파일:
- 게시글/댓글: `getApplicationDocumentsDirectory()/community_store_v1.json`
- 매출: `InMemoryRevenueRepository` (in-memory only, 앱 재시작 시 초기화)
- 프로필: `InMemoryStoreProfileRepository` (in-memory only)
- 익명 ID: `SharedPreferences` (`anon_id_v1` 키)

### 라우팅

`AppRoutes` (상수) + `AppPages` (GetPage 목록). `RootShell`은 라우트가 아닌 `IndexedStack` 탭 컨테이너. 탭 간 이동은 `setState`로 index 교체, 화면 push는 `Get.toNamed(AppRoutes.xxx, arguments: {...})`.

### 주요 도메인 규칙

- `BoardType.owner` 게시판은 `isOwnerVerified == true`인 사용자만 작성 가능 (`PostPolicy`, `OwnerBoardController` 확인)
- 신고 3회 이상 → `isReportThresholdReached = true` (Post/Comment 공통)
- 댓글 삭제는 hard delete가 아닌 `isDeleted = true` soft delete
- 핫 게시글 점수: `likeCount × 3 + commentCount × 4 + viewCount`
