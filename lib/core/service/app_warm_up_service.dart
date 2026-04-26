import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class AppWarmUpService extends GetxService {
  bool _started = false;
  bool _finished = false;

  Future<void>? _runFuture;

  bool get started => _started;
  bool get finished => _finished;

  Future<void> start() {
    if (_started) {
      return _runFuture ?? Future<void>.value();
    }

    _started = true;
    _runFuture = _run();

    unawaited(_runFuture);

    return _runFuture!;
  }

  Future<void> waitUntilFinished() async {
    final future = _runFuture;
    if (future == null) return;
    await future;
  }

  Future<void> _run() async {
    try {
      // 서버 작업 전 마지막 안정화 기준:
      // 컨트롤러까지 강제로 깨우지 않는다.
      // RootBinding/Home/Community의 기존 생명주기와 경합하지 않도록
      // Repository와 작성자 스냅샷까지만 조용히 예열한다.
      await _warmRepositories();
      await _warmAuthorSnapshot();
    } catch (_) {
      // 워밍업 실패는 앱 진입/사용을 막지 않는다.
    } finally {
      _finished = true;
    }
  }

  Future<void> _warmRepositories() async {
    await Future.wait<void>([
      _safe(() async {
        final repo = _findIfAvailable<StoreProfileRepository>();
        if (repo == null) return;

        try {
          final dynamic dyn = repo;
          await dyn.warmUp();
        } catch (_) {
          await repo.fetchProfile();
        }
      }),
      _safe(() async {
        final repo = _findIfAvailable<PostRepository>();
        if (repo == null) return;

        try {
          final dynamic dyn = repo;
          await dyn.ensureReady();
          return;
        } catch (_) {
          // 서버 Repository에서는 ensureReady가 없을 수 있다.
        }

        try {
          final dynamic dyn = repo;
          await dyn.warmUp();
        } catch (_) {
          // 서버 Repository에서는 warmUp이 없을 수 있다.
        }
      }),
    ]);
  }

  Future<void> _warmAuthorSnapshot() async {
    await _safe(() async {
      final repo = _findIfAvailable<PostRepository>();
      if (repo == null) return;

      try {
        final dynamic dyn = repo;
        await dyn.prewarmCurrentAuthorSnapshot();
      } catch (_) {
        // 서버 Repository에서는 이 메서드가 없을 수 있다.
      }
    });
  }

  T? _findIfAvailable<T>() {
    try {
      if (Get.isRegistered<T>() || Get.isPrepared<T>()) {
        return Get.find<T>();
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> _safe(Future<void> Function() job) async {
    try {
      await job();
    } catch (_) {
      // 개별 워밍업 실패는 무시한다.
    }
  }
}