import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/notification/domain/push_notification_repository.dart';
import 'package:yupgagae/routes/app_routes.dart';

const String _kHighChannelId = 'yupgagae_high';
const String _kHighChannelName = '옆가게 알림';
const String _kHighChannelDescription = '댓글, 답글, 하루결 알림을 알려드립니다.';
const String _kAndroidNotificationIcon = 'ic_stat_yupgagae_notification';

class PushNotificationService extends GetxService {
  final PushNotificationRepository repository;
  final FirebaseMessaging messaging;
  final FirebaseAuth auth;
  final FlutterLocalNotificationsPlugin localNotifications;

  PushNotificationService({
    required this.repository,
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : messaging = messaging ?? FirebaseMessaging.instance,
        auth = auth ?? FirebaseAuth.instance,
        localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  final Rxn<Map<String, String>> lastOpenedPayload = Rxn<Map<String, String>>();

  StreamSubscription<User?>? _authStateSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _openedMessageSub;

  bool _started = false;
  bool _starting = false;
  bool _isRouting = false;
  bool _localNotificationInitialized = false;

  String? _lastRegisteredToken;
  String? _lastRegisteredUserUid;
  String? _lastRouteSignature;
  DateTime? _lastRouteAt;

  Future<void> start() async {
    if (_started || _starting) return;

    _starting = true;

    try {
      await _initializeLocalNotifications();
      await _requestPermission();
      await _configureForegroundPresentation();

      _listenAuthState();
      _listenTokenRefresh();
      _listenForegroundMessages();
      _listenOpenedMessages();

      await _registerCurrentTokenIfAuthenticated(
        reason: 'service_start',
        force: false,
      );

      await _handleInitialMessage();

      _started = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PushNotificationService start failed: $e');
      }
    } finally {
      _starting = false;
    }
  }

  Future<void> refreshTokenRegistration() async {
    await _registerCurrentTokenIfAuthenticated(
      reason: 'manual_refresh',
      force: true,
    );
  }

  Future<void> deleteCurrentToken() async {
    try {
      final user = auth.currentUser;
      if (user == null) return;

      final token = await messaging.getToken();
      if (token == null || token.trim().isEmpty) return;

      await repository.deleteToken(
        token: token,
        platform: _platformKey,
      );

      if (_lastRegisteredToken == token) {
        _lastRegisteredToken = null;
        _lastRegisteredUserUid = null;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('deleteCurrentToken failed: $e');
      }
    }
  }

  void _listenAuthState() {
    _authStateSub ??= auth.authStateChanges().listen((user) async {
      if (user == null) {
        _lastRegisteredUserUid = null;
        _lastRegisteredToken = null;

        if (kDebugMode) {
          debugPrint('Push auth state changed: signed out');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('Push auth state changed: signed in ${user.uid}');
      }

      await _registerCurrentTokenIfAuthenticated(
        reason: 'auth_state_changed',
        force: true,
      );
    });
  }

  Future<void> _initializeLocalNotifications() async {
    if (_localNotificationInitialized) return;

    const androidChannel = AndroidNotificationChannel(
      _kHighChannelId,
      _kHighChannelName,
      description: _kHighChannelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    final androidPlugin =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(androidChannel);

    const androidSettings = AndroidInitializationSettings(
      _kAndroidNotificationIcon,
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: iosSettings,
    );

    await localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _handleLocalNotificationPayload(response.payload);
      },
    );

    _localNotificationInitialized = true;
  }

  Future<void> _requestPermission() async {
    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final androidPlugin =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _configureForegroundPresentation() async {
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _registerCurrentTokenIfAuthenticated({
    required String reason,
    required bool force,
  }) async {
    try {
      final user = auth.currentUser;

      if (user == null) {
        if (kDebugMode) {
          debugPrint('Push token register skipped: auth missing ($reason)');
        }
        return;
      }

      final settings = await messaging.getNotificationSettings();

      if (!_isPermissionUsable(settings.authorizationStatus)) {
        if (kDebugMode) {
          debugPrint(
            'Push token register skipped: notification permission ${settings.authorizationStatus} ($reason)',
          );
        }
        return;
      }

      final token = await messaging.getToken();

      if (token == null || token.trim().isEmpty) {
        if (kDebugMode) {
          debugPrint('Push token register skipped: empty token ($reason)');
        }
        return;
      }

      final normalizedToken = token.trim();
      final userUid = user.uid.trim();

      if (!force &&
          _lastRegisteredToken == normalizedToken &&
          _lastRegisteredUserUid == userUid) {
        if (kDebugMode) {
          debugPrint('Push token register skipped: already registered ($reason)');
        }
        return;
      }

      await repository.registerToken(
        token: normalizedToken,
        platform: _platformKey,
      );

      _lastRegisteredToken = normalizedToken;
      _lastRegisteredUserUid = userUid;

      if (kDebugMode) {
        debugPrint('Push token registered: $reason / $userUid');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('registerCurrentToken failed: $e');
      }
    }
  }

  void _listenTokenRefresh() {
    _tokenRefreshSub ??= messaging.onTokenRefresh.listen((token) async {
      try {
        final user = auth.currentUser;

        if (user == null) {
          if (kDebugMode) {
            debugPrint('onTokenRefresh skipped: auth missing');
          }
          return;
        }

        final normalizedToken = token.trim();
        if (normalizedToken.isEmpty) return;

        await repository.registerToken(
          token: normalizedToken,
          platform: _platformKey,
        );

        _lastRegisteredToken = normalizedToken;
        _lastRegisteredUserUid = user.uid.trim();

        if (kDebugMode) {
          debugPrint('Push token refreshed and registered: ${user.uid}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('onTokenRefresh register failed: $e');
        }
      }
    });
  }

  void _listenForegroundMessages() {
    _foregroundMessageSub ??= FirebaseMessaging.onMessage.listen((message) {
      if (kDebugMode) {
        debugPrint('FCM foreground message: ${message.messageId}');
        debugPrint('FCM foreground payload: ${message.data}');
      }

      unawaited(_showForegroundNotification(message));
    });
  }

  void _listenOpenedMessages() {
    _openedMessageSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleOpenedMessage(message);
    });
  }

  Future<void> _handleInitialMessage() async {
    final message = await messaging.getInitialMessage();
    if (message == null) return;

    _handleOpenedMessage(message);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    await _initializeLocalNotifications();

    final payload = _normalizePayload(message.data);
    final notification = message.notification;

    final title = notification?.title?.trim().isNotEmpty == true
        ? notification!.title!.trim()
        : _titleFromPayload(payload);

    final body = notification?.body?.trim().isNotEmpty == true
        ? notification!.body!.trim()
        : _bodyFromPayload(payload);

    const androidDetails = AndroidNotificationDetails(
      _kHighChannelId,
      _kHighChannelName,
      channelDescription: _kHighChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      ticker: '옆가게 알림',
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      icon: _kAndroidNotificationIcon,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    await localNotifications.show(
      id: _notificationId(message),
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(payload),
    );
  }

  void _handleOpenedMessage(RemoteMessage message) {
    final payload = _normalizePayload(message.data);
    lastOpenedPayload.value = payload;

    if (kDebugMode) {
      debugPrint('FCM opened payload: $payload');
    }

    _routeFromPayloadSafely(payload);
  }

  void _handleLocalNotificationPayload(String? rawPayload) {
    final text = rawPayload?.trim();
    if (text == null || text.isEmpty) return;

    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return;

      final payload = <String, String>{};

      decoded.forEach((key, value) {
        final normalizedKey = key.toString().trim();
        final normalizedValue = value?.toString().trim() ?? '';

        if (normalizedKey.isEmpty || normalizedValue.isEmpty) return;

        payload[normalizedKey] = normalizedValue;
      });

      if (payload.isEmpty) return;

      lastOpenedPayload.value = Map<String, String>.unmodifiable(payload);
      _routeFromPayloadSafely(payload);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Local notification payload parse failed: $e');
      }
    }
  }

  void _routeFromPayloadSafely(Map<String, String> payload) {
    if (payload.isEmpty) return;

    final signature = _routeSignature(payload);
    final now = DateTime.now();

    if (_lastRouteSignature == signature && _lastRouteAt != null) {
      final diff = now.difference(_lastRouteAt!);
      if (diff.inMilliseconds < 1200) {
        return;
      }
    }

    _lastRouteSignature = signature;
    _lastRouteAt = now;

    unawaited(_routeFromPayloadAfterFrame(payload));
  }

  Future<void> _routeFromPayloadAfterFrame(Map<String, String> payload) async {
    if (_isRouting) return;

    _isRouting = true;

    try {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 80));

      final target = _payloadValue(payload, 'target');
      final type = _payloadValue(payload, 'type');

      if (target == 'harugyeol' || type == 'harugyeol') {
        await _goHarugyeol(payload);
        return;
      }

      if (target == 'comment' || type == 'comment_reply') {
        await _goCommentTarget(payload);
        return;
      }

      if (target == 'post' || type == 'post_comment') {
        await _goPostTarget(payload);
        return;
      }

      if (target == 'inquiry') {
        await _goRoot();
        return;
      }

      if (type == 'report_result' || type == 'sanction') {
        await _goRoot();
        return;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Push route failed: $e');
      }
    } finally {
      _isRouting = false;
    }
  }

  Future<void> _goPostTarget(Map<String, String> payload) async {
    final postId = _payloadValue(payload, 'postId');

    if (postId.isEmpty) {
      await _goRoot();
      return;
    }

    await _openPostDetail(
      postId: postId,
      commentId: _payloadValue(payload, 'commentId'),
      rootCommentId: _payloadValue(payload, 'rootCommentId'),
    );
  }

  Future<void> _goCommentTarget(Map<String, String> payload) async {
    final postId = _payloadValue(payload, 'postId');
    final commentId = _payloadValue(payload, 'commentId');
    final rootCommentId = _payloadValue(payload, 'rootCommentId');

    if (postId.isEmpty) {
      await _goRoot();
      return;
    }

    if (rootCommentId.isNotEmpty) {
      await _openCommentThread(
        postId: postId,
        rootCommentId: rootCommentId,
        focusCommentId: commentId.isEmpty ? rootCommentId : commentId,
      );
      return;
    }

    await _openPostDetail(
      postId: postId,
      commentId: commentId,
      rootCommentId: rootCommentId,
    );
  }

  Future<void> _goHarugyeol(Map<String, String> payload) async {
    if (Get.currentRoute == AppRoutes.harugyeol) {
      return;
    }

    await Get.toNamed(
      AppRoutes.harugyeol,
      arguments: {
        'fromPush': true,
        'dateKey': _payloadValue(payload, 'dateKey'),
        'slot': _payloadValue(payload, 'slot'),
      },
    );
  }

  Future<void> _goRoot() async {
    if (Get.currentRoute == AppRoutes.root) {
      return;
    }

    await Get.offAllNamed(AppRoutes.root);
  }

  Future<void> _openPostDetail({
    required String postId,
    required String commentId,
    required String rootCommentId,
  }) async {
    final normalizedPostId = postId.trim();

    if (normalizedPostId.isEmpty) {
      await _goRoot();
      return;
    }

    final route = AppRoutes.postDetail;
    final current = Get.currentRoute;

    if (current == route) {
      Get.back();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    await Get.toNamed(
      route,
      arguments: {
        'postId': normalizedPostId,
        'fromPush': true,
        'commentId': commentId.trim(),
        'rootCommentId': rootCommentId.trim(),
      },
    );
  }

  Future<void> _openCommentThread({
    required String postId,
    required String rootCommentId,
    required String focusCommentId,
  }) async {
    final normalizedPostId = postId.trim();
    final normalizedRootCommentId = rootCommentId.trim();

    if (normalizedPostId.isEmpty || normalizedRootCommentId.isEmpty) {
      await _openPostDetail(
        postId: normalizedPostId,
        commentId: focusCommentId,
        rootCommentId: normalizedRootCommentId,
      );
      return;
    }

    final current = Get.currentRoute;

    if (current == AppRoutes.commentThread) {
      Get.back();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    await Get.toNamed(
      AppRoutes.commentThread,
      arguments: {
        'postId': normalizedPostId,
        'rootCommentId': normalizedRootCommentId,
        'focusCommentId': focusCommentId.trim().isEmpty
            ? normalizedRootCommentId
            : focusCommentId.trim(),
        'fromPush': true,
      },
    );
  }

  Map<String, String> _normalizePayload(Map<String, dynamic> data) {
    final result = <String, String>{};

    for (final entry in data.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) continue;

      final value = entry.value;
      if (value == null) continue;

      final text = value.toString().trim();
      if (text.isEmpty) continue;

      result[key] = text;
    }

    return Map<String, String>.unmodifiable(result);
  }

  String _titleFromPayload(Map<String, String> payload) {
    final type = _payloadValue(payload, 'type');

    if (type == 'comment_reply') return '새 답글이 달렸어요';
    if (type == 'post_comment') return '새 댓글이 달렸어요';
    if (type == 'harugyeol') return '하루결 알림';

    return '옆가게 알림';
  }

  String _bodyFromPayload(Map<String, String> payload) {
    final type = _payloadValue(payload, 'type');

    if (type == 'comment_reply') return '내 댓글에 새 답글이 달렸습니다.';
    if (type == 'post_comment') return '내 글에 새 댓글이 달렸습니다.';
    if (type == 'harugyeol') return '오늘 장사 체감을 남겨보세요.';

    return '새 알림이 도착했습니다.';
  }

  int _notificationId(RemoteMessage message) {
    final id = message.messageId?.hashCode;
    if (id != null) return id & 0x7fffffff;

    return DateTime.now().millisecondsSinceEpoch.remainder(2147483647);
  }

  String _payloadValue(Map<String, String> payload, String key) {
    return (payload[key] ?? '').trim();
  }

  String _routeSignature(Map<String, String> payload) {
    final keys = payload.keys.toList()..sort();

    return keys.map((key) => '$key=${payload[key]}').join('&');
  }

  bool _isPermissionUsable(AuthorizationStatus status) {
    return status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;
  }

  String get _platformKey {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  @override
  void onClose() {
    _authStateSub?.cancel();
    _tokenRefreshSub?.cancel();
    _openedMessageSub?.cancel();
    _foregroundMessageSub?.cancel();

    _authStateSub = null;
    _tokenRefreshSub = null;
    _foregroundMessageSub = null;
    _openedMessageSub = null;

    super.onClose();
  }
}