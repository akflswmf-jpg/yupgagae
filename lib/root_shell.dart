import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/home_feed_controller.dart';
import 'package:yupgagae/features/community/view/community_shell.dart';
import 'package:yupgagae/features/home/home_screen.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/view/my_store_screen.dart';
import 'package:yupgagae/features/revenue/view/revenue_screen.dart';

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int index = 0;

  late final List<Widget> pages;

  late final MyStoreController myStoreController;

  DateTime? _lastHomeSoftRefreshAt;

  static const Color kYupgagaeAccent = Color(0xFFA56E5F);
  static const Duration _homeSoftRefreshCooldown = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();

    myStoreController = Get.find<MyStoreController>();

    pages = <Widget>[
      const HomeScreen(),
      const CommunityShell(),
      const RevenueScreen(),
      const MyStoreScreen(),
    ];
  }

  void _handleTap(int nextIndex) {
    if (index == nextIndex) {
      if (nextIndex == 0) {
        _softRefreshHomeIfAllowed();
      }
      return;
    }

    setState(() {
      index = nextIndex;
    });

    if (nextIndex == 0) {
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
      body: IndexedStack(
        index: index,
        children: pages,
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
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
            backgroundColor: Colors.white,
            elevation: 0,
            selectedFontSize: 11,
            unselectedFontSize: 11,
            selectedItemColor: kYupgagaeAccent,
            unselectedItemColor: const Color(0xFF9CA3AF),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: '홈',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.forum_outlined),
                activeIcon: Icon(Icons.forum),
                label: '커뮤니티',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: '매출',
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