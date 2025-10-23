
import 'dart:async';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';

class FavoriteController extends GetxController with GetTickerProviderStateMixin {
  final SettingsService settings = Get.find<SettingsService>();
  late TabController tabController;
  late TabController tabSiteController;
  final tabBottomIndex = 0.obs;
  final tabSiteIndex = 0.obs;
  final tabOnlineIndex = 0.obs;
  bool isFirstLoad = true;
  FavoriteController() {
    tabController = TabController(length: 2, vsync: this);
    tabSiteController = TabController(length: Sites().availableSites().length + 1, vsync: this);
  }

  @override
  void onInit() {
    super.onInit();
    // 初始化关注页
    syncRooms();
    // 监听settings rooms变化
    debounce(settings.favoriteRooms, (rooms) => syncRooms(), time: const Duration(milliseconds: 1000));
    onRefresh();
    tabController.addListener(() {
      tabOnlineIndex.value = tabController.index;
    });
    tabSiteController.addListener(() {
      tabSiteIndex.value = tabSiteController.index;
    });
    // 定时自动刷新
    if (settings.autoRefreshTime.value != 0) {
      Timer.periodic(Duration(minutes: settings.autoRefreshTime.value), (timer) => onRefresh());
    }
  }

  final onlineRooms = [].obs;
  final offlineRooms = [].obs;

  void syncRooms() {
    onlineRooms.clear();
    offlineRooms.clear();
    onlineRooms.addAll(settings.favoriteRooms.where((room) => room.liveStatus == LiveStatus.live));
    offlineRooms.addAll(settings.favoriteRooms.where((room) => room.liveStatus != LiveStatus.live));
    for (var room in onlineRooms) {
      if (int.tryParse(room.watching!) == null) {
        room.watching = "0";
      }
    }
    onlineRooms.sort((a, b) => int.parse(b.watching!).compareTo(int.parse(a.watching!)));
  }

  bool _isSupportedPlatform(String? platform) {
    final p = SettingsService.normalizePlatformId(platform);
    if (p.isEmpty) return false;
    return Sites.supportSites.any((s) => s.id == p);
  }

  Future<bool> onRefresh() async {
    // 如果是首次加载，则等待一秒
    if (isFirstLoad) await Future.delayed(const Duration(seconds: 1));

    if (settings.favoriteRooms.value.isEmpty) return false;

    // 过滤无效平台/空房间，规范化平台ID（如 kuaishow -> kuaishou）
    final targets = settings.favoriteRooms.value.where((room) {
      final pid = SettingsService.normalizePlatformId(room.platform);
      return (room.roomId ?? '').isNotEmpty && _isSupportedPlatform(pid);
    }).toList();

    // 分批并发请求，单批最多5个，失败时保留原状态（不强制改为离线）
    try {
      for (int i = 0; i < targets.length; i += 5) {
        final batch = targets.sublist(i, i + 5 > targets.length ? targets.length : i + 5);
        try {
          final rooms = await Future.wait(batch.map((r) async {
            final pid = SettingsService.normalizePlatformId(r.platform);
            try {
              final site = Sites.of(pid).liveSite;
              final detail = await site.getRoomDetail(roomId: r.roomId!, platform: pid);
              // 规范化平台字段，避免 'kuaishow' 写回失败
              detail.platform = pid;
              return detail;
            } catch (e) {
              debugPrint('Favorite refresh failed: $pid/${r.roomId} -> $e');
              // 保持上次已知状态，避免误判为离线
              return settings.getLiveRoomByRoomId(r.roomId!, pid);
            }
          }));
          for (var room in rooms) {
            try {
              settings.updateRoom(room);
            } catch (e) {
              debugPrint('Error during refresh for a single request: $e');
            }
          }
        } catch (e) {
          debugPrint('Error during refresh for a batch of requests: $e');
        }
      }
      syncRooms();
    } catch (e) {
      debugPrint('Error during refresh: $e');
    }
    isFirstLoad = false;
    // UI 侧以 false 作为“刷新完成”的信号，保持兼容
    return false;
  }
}