import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/auth/auth_binding.dart';
import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/ui/app_toast.dart';
import 'package:yupgagae/features/community/controller/home_feed_controller.dart';
import 'package:yupgagae/features/community/view/community_shell.dart';
import 'package:yupgagae/features/harugyeol/view/harugyeol_screen.dart';
import 'package:yupgagae/features/home/home_screen.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/view/my_store_screen.dart'
    as my_store_screen;
import 'package:yupgagae/routes/app_routes.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  static const int homeTabIndex = 0;
  static const int communityTabIndex = 1;
  static const int harugyeolTabIndex = 2;
  static const int myStoreTabIndex = 3;

  int index = _resolveInitialIndex();

  late final List<Widget> pages;

  late final AuthController authController;
  late final MyStoreController myStoreController;

  DateTime? _lastHomeSoftRefreshAt;

  Worker? _sanctionNoticeWorker;

  bool _startupGuardStarted = false;
  bool _nativeSplashRemoved = false;
  bool _sanctionNoticeOpen = false;

  String? _lastPresentedSanctionNoticeKey;
  String? _lastAcknowledgedWarningNoticeKey;

  static const Color kYupgagaeAccent = Color(0xFFA56E5F);
  static const Color _backgroundColor = Colors.white;
  static const Color _inactiveTabColor = Color(0xFF9CA3AF);
  static const Duration _homeSoftRefreshCooldown = Duration(seconds: 30);

  static int _resolveInitialIndex() {
    final args = Get.arguments;

    if (args is Map) {
      final value = args['initialIndex'] ?? args['tabIndex'] ?? args['tab'];

      if (value is int && value >= homeTabIndex && value <= myStoreTabIndex) {
        return value;
      }

      if (value is String) {
        switch (value.trim()) {
          case 'home':
            return homeTabIndex;
          case 'community':
            return communityTabIndex;
          case 'harugyeol':
          case 'haru':
          case 'daily':
          case 'flow':
          case '하루결':
            return harugyeolTabIndex;
          case 'myStore':
          case 'my_store':
          case 'store':
            return myStoreTabIndex;
        }
      }
    }

    return homeTabIndex;
  }

  @override
  void initState() {
    super.initState();

    if (!Get.isRegistered<AuthController>()) {
      AuthBinding().dependencies();
    }

    authController = Get.find<AuthController>();
    myStoreController = Get.find<MyStoreController>();

    pages = <Widget>[
      const HomeScreen(),
      const CommunityShell(),
      const HarugyeolScreen(),
      const my_store_screen.MyStoreScreen(),
    ];

    _sanctionNoticeWorker = ever<AppUser?>(
      authController.currentUser,
      (user) {
        _scheduleSanctionNotice(user);
      },
    );

    unawaited(_runStartupGuard());
  }

  @override
  void dispose() {
    _sanctionNoticeWorker?.dispose();
    super.dispose();
  }

  Future<void> _runStartupGuard() async {
    if (_startupGuardStarted) return;
    _startupGuardStarted = true;

    try {
      await SchedulerBinding.instance.endOfFrame;

      final user = await authController.restoreCurrentUserForStartup();

      if (!mounted) {
        _removeNativeSplashSafely();
        return;
      }

      _normalizeProtectedInitialTab(user);
      _scheduleSanctionNotice(user);

      await _removeNativeSplashAfterFirstFrame();
      _scheduleHomeStartupRefresh();
    } catch (_) {
      if (!mounted) {
        _removeNativeSplashSafely();
        return;
      }

      _normalizeProtectedInitialTab(null);

      await _removeNativeSplashAfterFirstFrame();
      _scheduleHomeStartupRefresh();
    }
  }

  void _normalizeProtectedInitialTab(dynamic user) {
    if (!_isProtectedTab(index)) return;

    if (user == null) {
      setState(() {
        index = homeTabIndex;
      });
      return;
    }

    if (user.needsProfileSetup) {
      setState(() {
        index = homeTabIndex;
      });

      Get.toNamed(AppRoutes.profileSetup);
    }
  }

  Future<void> _removeNativeSplashAfterFirstFrame() async {
    if (_nativeSplashRemoved) return;
    _nativeSplashRemoved = true;

    try {
      await SchedulerBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 16));
      FlutterNativeSplash.remove();
    } catch (_) {
      FlutterNativeSplash.remove();
    }
  }

  void _removeNativeSplashSafely() {
    if (_nativeSplashRemoved) return;
    _nativeSplashRemoved = true;

    try {
      FlutterNativeSplash.remove();
    } catch (_) {}
  }

  void _scheduleHomeStartupRefresh() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (index != homeTabIndex) return;

      _softRefreshHomeIfAllowed();
    });
  }

  bool _isPublicTab(int tabIndex) {
    return tabIndex == homeTabIndex ||
        tabIndex == communityTabIndex ||
        tabIndex == harugyeolTabIndex;
  }

  bool _isProtectedTab(int tabIndex) {
    return tabIndex == myStoreTabIndex;
  }

  void _handleTap(int nextIndex) {
    final user = authController.currentUser.value;

    if (_isPublicTab(nextIndex)) {
      if (index == nextIndex) {
        if (nextIndex == homeTabIndex) {
          _softRefreshHomeIfAllowed();
        }
        return;
      }

      setState(() {
        index = nextIndex;
      });

      if (nextIndex == homeTabIndex) {
        _softRefreshHomeIfAllowed();
      }

      return;
    }

    if (_isProtectedTab(nextIndex) && user == null) {
      Get.toNamed(AppRoutes.login);
      return;
    }

    if (_isProtectedTab(nextIndex) && user != null && user.needsProfileSetup) {
      Get.toNamed(AppRoutes.profileSetup);
      return;
    }

    if (index == nextIndex) {
      if (nextIndex == homeTabIndex) {
        _softRefreshHomeIfAllowed();
      }
      return;
    }

    setState(() {
      index = nextIndex;
    });

    if (nextIndex == homeTabIndex) {
      _softRefreshHomeIfAllowed();
    }
  }

  void _softRefreshHomeIfAllowed() {
    if (!Get.isRegistered<HomeFeedController>()) return;

    final now = DateTime.now();
    final last = _lastHomeSoftRefreshAt;

    if (last != null && now.difference(last) < _homeSoftRefreshCooldown) {
      return;
    }

    _lastHomeSoftRefreshAt = now;

    unawaited(Get.find<HomeFeedController>().refreshIfStale());
  }

  void _scheduleSanctionNotice(AppUser? user) {
    if (!mounted) return;
    if (user == null) return;
    if (user.needsProfileSetup) return;

    final key = _sanctionNoticeKey(user);
    if (key == null) return;
    if (key == _lastPresentedSanctionNoticeKey) return;
    if (key == _lastAcknowledgedWarningNoticeKey) return;

    _lastPresentedSanctionNoticeKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_showSanctionNoticeIfNeeded(user, key));
    });
  }

  String? _sanctionNoticeKey(AppUser user) {
    final updatedAtMs = user.sanctionUpdatedAt?.millisecondsSinceEpoch ?? 0;
    final untilMs = user.sanctionUntil?.millisecondsSinceEpoch ?? 0;
    final sanctionId = user.lastSanctionId ?? '';

    if (user.isPermanentlyBanned) {
      return 'permanent:${user.userId}:$sanctionId:$updatedAtMs';
    }

    if (user.isCurrentlySuspendedBySanction) {
      return 'suspended:${user.userId}:$sanctionId:$updatedAtMs:$untilMs';
    }

    if (user.shouldShowWarningNotice) {
      return 'warning:${user.userId}:$sanctionId:$updatedAtMs';
    }

    return null;
  }

  Future<void> _showSanctionNoticeIfNeeded(
    AppUser user,
    String scheduledKey,
  ) async {
    if (_sanctionNoticeOpen) return;
    if (!mounted) return;

    final latestUser = authController.currentUser.value;
    if (latestUser == null || latestUser.userId != user.userId) return;

    final latestKey = _sanctionNoticeKey(latestUser);
    if (latestKey == null) return;
    if (latestKey != scheduledKey) return;
    if (latestKey == _lastAcknowledgedWarningNoticeKey) return;

    _sanctionNoticeOpen = true;

    try {
      if (latestUser.isPermanentlyBanned) {
        await _showSanctionDialog(
          title: '커뮤니티 이용 제한',
          message: '운영정책 위반으로 커뮤니티 이용이 제한되었습니다.\n\n'
              '사유: ${latestUser.sanctionDisplayReason}\n\n'
              '문의가 필요한 경우 내가게의 의견함을 이용해주세요.',
          confirmText: '확인',
          isDanger: true,
          barrierDismissible: false,
        );
        return;
      }

      if (latestUser.isCurrentlySuspendedBySanction) {
        await _showSanctionDialog(
          title: '커뮤니티 이용 정지',
          message: '정지 기간 중에는 글쓰기, 댓글, 좋아요, 신고 기능을 이용할 수 없습니다.\n\n'
              '사유: ${latestUser.sanctionDisplayReason}\n'
              '해제 예정: ${latestUser.sanctionUntilLabel}',
          confirmText: '확인',
          isDanger: true,
          barrierDismissible: false,
        );
        return;
      }

      if (latestUser.shouldShowWarningNotice) {
        final acknowledged = await _showSanctionDialog(
          title: '운영정책 경고',
          message: '작성한 글 또는 댓글이 운영정책에 맞지 않아 경고가 부여되었습니다.\n\n'
              '사유: ${latestUser.sanctionDisplayReason}\n\n'
              '반복될 경우 일정 기간 커뮤니티 이용이 제한될 수 있습니다.',
          confirmText: '확인했습니다',
          isDanger: false,
          barrierDismissible: false,
        );

        if (acknowledged == true) {
          try {
            _lastAcknowledgedWarningNoticeKey = latestKey;
            await authController.acknowledgeLatestWarning();
          } catch (e) {
            _lastAcknowledgedWarningNoticeKey = null;
            AppToast.show(
              '$e',
              title: '경고 확인 처리 실패',
              isError: true,
            );
          }
        }
      }
    } finally {
      _sanctionNoticeOpen = false;
    }
  }

  Future<bool> _showSanctionDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool isDanger,
    required bool barrierDismissible,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF25211F),
              letterSpacing: -0.3,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
              height: 1.5,
              letterSpacing: -0.15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                confirmText,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isDanger
                      ? const Color(0xFFE11D48)
                      : kYupgagaeAccent,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Widget _buildHomeIcon({required bool active}) {
    return Icon(
      active ? Icons.home_rounded : Icons.home_outlined,
      size: active ? 28 : 25,
    );
  }

  Widget _buildStoreIcon({required bool active}) {
    return Obx(() {
      final unread = myStoreController.unreadNotificationCount;

      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            active ? Icons.storefront : Icons.storefront_outlined,
          ),
          if (unread > 0)
            Positioned(
              right: -4,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 14,
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: IndexedStack(
          index: index,
          children: pages,
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: _backgroundColor,
          border: Border(
            top: BorderSide(
              color: Color(0xFFF1F3F5),
              width: 1,
            ),
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            currentIndex: index,
            onTap: _handleTap,
            type: BottomNavigationBarType.fixed,
            backgroundColor: _backgroundColor,
            elevation: 0,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedItemColor: kYupgagaeAccent,
            unselectedItemColor: _inactiveTabColor,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            items: [
              BottomNavigationBarItem(
                icon: _buildHomeIcon(active: false),
                activeIcon: _buildHomeIcon(active: true),
                label: '홈',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.forum_outlined),
                activeIcon: Icon(Icons.forum),
                label: '커뮤니티',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.insights_outlined),
                activeIcon: Icon(Icons.insights),
                label: '하루결',
              ),
              BottomNavigationBarItem(
                icon: _buildStoreIcon(active: false),
                activeIcon: _buildStoreIcon(active: true),
                label: '내가게',
              ),
            ],
          ),
        ),
      ),
    );
  }
}