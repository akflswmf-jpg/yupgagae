import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/home_feed_controller.dart';
import 'package:yupgagae/features/community/controller/owner_board_controller.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
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

    _log('start');

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
      _log('run begin');

      // 1차: 앱 시작 직후 반드시 필요한 저장소/프로필/게시글 데이터 예열
      await _warmCoreRepositories();

      // 첫 프레임과 경합하지 않도록 안전하게 양보
      await _waitOneFrame();
      await Future<void>.delayed(const Duration(milliseconds: 80));

      // 2차: 홈/게시판 컨트롤러를 조용히 한 번 깨운다.
      // 첫 탭 진입/첫 리스트 접근 때 생기는 초기 비용 제거 목적.
      await _warmControllers();

      await Future<void>.delayed(const Duration(milliseconds: 80));

      // 3차: 댓글 작성에 필요한 작성자 스냅샷/댓글 경로를 최대한 예열
      await _warmCommentWritePath();

      _log('run success');
    } catch (e, st) {
      _log('run failed: $e');
      _log('$st');
    } finally {
      _finished = true;
      _log('finished');
    }
  }

  Future<void> _warmCoreRepositories() async {
    _log('warmCoreRepositories begin');

    await Future.wait<void>([
      _safe('StoreProfileRepository warm', () async {
        final repo = _findIfAvailable<StoreProfileRepository>();
        if (repo == null) {
          _log('StoreProfileRepository not available');
          return;
        }

        try {
          final dynamic dyn = repo;
          await dyn.warmUp();
          _log('StoreProfileRepository warmUp done');
          return;
        } catch (_) {
          // 서버 Repository에서는 warmUp이 없을 수 있다.
        }

        await repo.fetchProfile();
        _log('StoreProfileRepository fetchProfile done');
      }),
      _safe('PostRepository warm', () async {
        final repo = _findIfAvailable<PostRepository>();
        if (repo == null) {
          _log('PostRepository not available');
          return;
        }

        try {
          final dynamic dyn = repo;
          await dyn.ensureReady();
          _log('PostRepository ensureReady done');
        } catch (_) {
          _log('PostRepository ensureReady not available');
        }

        try {
          final dynamic dyn = repo;
          await dyn.warmUp();
          _log('PostRepository warmUp done');
        } catch (_) {
          _log('PostRepository warmUp not available');
        }
      }),
    ]);

    _log('warmCoreRepositories end');
  }

  Future<void> _warmControllers() async {
    _log('warmControllers begin');

    await _safe('PostListController create', () async {
      if (Get.isRegistered<PostListController>() ||
          Get.isPrepared<PostListController>()) {
        Get.find<PostListController>();
        _log('PostListController created');
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 40));

    await _safe('OwnerBoardController create', () async {
      if (Get.isRegistered<OwnerBoardController>() ||
          Get.isPrepared<OwnerBoardController>()) {
        Get.find<OwnerBoardController>();
        _log('OwnerBoardController created');
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 40));

    await _safe('HomeFeedController create', () async {
      if (Get.isRegistered<HomeFeedController>() ||
          Get.isPrepared<HomeFeedController>()) {
        Get.find<HomeFeedController>();
        _log('HomeFeedController created');
      }
    });

    _log('warmControllers end');
  }

  Future<void> _warmCommentWritePath() async {
    _log('warmCommentWritePath begin');

    await _safe('author snapshot warm', () async {
      final repo = _findIfAvailable<PostRepository>();
      if (repo == null) {
        _log('PostRepository not available for author snapshot');
        return;
      }

      try {
        final dynamic dyn = repo;
        await dyn.prewarmCurrentAuthorSnapshot();
        _log('prewarmCurrentAuthorSnapshot done');
      } catch (_) {
        _log('prewarmCurrentAuthorSnapshot not available');
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 40));

    await _safe('comment write path warm', () async {
      final repo = _findIfAvailable<PostRepository>();
      if (repo == null) {
        _log('PostRepository not available for comment path');
        return;
      }

      try {
        final dynamic dyn = repo;
        await dyn.prewarmCommentWritePath();
        _log('prewarmCommentWritePath done');
      } catch (_) {
        _log('prewarmCommentWritePath not available');
      }
    });

    await Future<void>.delayed(const Duration(milliseconds: 40));

    await _safe('reply write path warm', () async {
      final repo = _findIfAvailable<PostRepository>();
      if (repo == null) {
        _log('PostRepository not available for reply path');
        return;
      }

      try {
        final dynamic dyn = repo;
        await dyn.prewarmReplyWritePath();
        _log('prewarmReplyWritePath done');
      } catch (_) {
        _log('prewarmReplyWritePath not available');
      }
    });

    _log('warmCommentWritePath end');
  }

  T? _findIfAvailable<T>() {
    try {
      if (Get.isRegistered<T>() || Get.isPrepared<T>()) {
        return Get.find<T>();
      }
    } catch (e) {
      _log('find failed: $T / $e');
      return null;
    }

    return null;
  }

  Future<void> _safe(
    String name,
    Future<void> Function() job,
  ) async {
    try {
      _log('$name begin');
      await job();
      _log('$name end');
    } catch (e, st) {
      _log('$name failed: $e');
      _log('$st');
    }
  }

  Future<void> _waitOneFrame() async {
    await SchedulerBinding.instance.endOfFrame;
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[AppWarmUpService] $message');
    }
  }
}