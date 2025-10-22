import 'dart:io';
import 'dart:async';
import 'dart:developer';
import 'package:get/get.dart';
import 'video_controller_panel.dart';
import 'package:flutter/services.dart';
import 'package:floating/floating.dart';
import 'package:pure_live/common/index.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:pure_live/modules/live_play/load_type.dart';
import 'package:pure_live/pkg/canvas_danmaku/danmaku_controller.dart';
import 'package:pure_live/modules/live_play/live_play_controller.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_option.dart';
import 'package:media_kit_video/media_kit_video.dart' as media_kit_video;
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:pure_live/pkg/canvas_danmaku/models/danmaku_content_item.dart';
import 'package:pure_live/modules/live_play/widgets/video_player/fullscreen.dart';

class VideoController with ChangeNotifier {
  final LiveRoom room;
  final String datasourceType;
  String datasource;
  final bool allowBackgroundPlay;
  final bool allowScreenKeepOn;
  final bool allowFullScreen;
  final bool fullScreenByDefault;
  final bool autoPlay;
  final Map<String, String> headers;

  final int videoPlayerIndex;
  final isVertical = false.obs;
  final videoFitIndex = 0.obs;
  final videoFit = BoxFit.contain.obs;
  final mediaPlayerControllerInitialized = false.obs;

  ScreenBrightness brightnessController = ScreenBrightness();

  double initBrightness = 0.0;

  final String qualiteName;

  final int currentLineIndex;

  final int currentQuality;

  final hasError = false.obs;

  final isPlaying = false.obs;

  final isBuffering = false.obs;

  final isPipMode = false.obs;

  final isFullscreen = false.obs;

  final isWindowFullscreen = false.obs;

  bool hasDestory = false;

  bool get supportPip => Platform.isAndroid;

  bool get supportWindowFull => Platform.isWindows || Platform.isLinux;

  bool get fullscreenUI => isFullscreen.value || isWindowFullscreen.value;

  final videoSizeWidth = 0.0.obs;

  final videoSizeHeight = 0.0.obs;

  // ignore: prefer_typing_uninitialized_variables
  late final Floating pip;
  // Video player status
  // A [GlobalKey<VideoState>] is required to access the programmatic fullscreen interface.
  late final GlobalKey<media_kit_video.VideoState> key = GlobalKey<media_kit_video.VideoState>();

  // Create a [Player] to control playback.
  late Player player;
  // VideoController] to handle video output from [Player].
  late media_kit_video.VideoController mediaPlayerController;
  BetterPlayerController? mobileController;
  final playerRefresh = false.obs;

  GlobalKey<BrightnessVolumnDargAreaState> brightnessKey = GlobalKey<BrightnessVolumnDargAreaState>();

  LivePlayController livePlayController = Get.find<LivePlayController>();

  final SettingsService settings = Get.find<SettingsService>();

  bool enableCodec = true;

  bool playerCompatMode = false;

  // 是否手动暂停
  var isActivePause = true.obs;

  Timer? hasActivePause;

  // Controller ui status
  ///State of navigator on widget created
  late NavigatorState navigatorState;

  ///Flag which determines if widget has initialized

  Timer? showControllerTimer;
  final showController = true.obs;
  final showSettting = false.obs;
  final showLocked = false.obs;
  final danmuKey = GlobalKey();

  GlobalKey playerKey = GlobalKey();
  List<Map<String, dynamic>> videoFitType = [
    {'attr': BoxFit.contain, 'desc': '包含'},
    {'attr': BoxFit.cover, 'desc': '覆盖'},
    {'attr': BoxFit.fill, 'desc': '填充'},
    {'attr': BoxFit.fitHeight, 'desc': '高度适应'},
    {'attr': BoxFit.fitWidth, 'desc': '宽度适应'},
    {'attr': BoxFit.scaleDown, 'desc': '缩小适应'},
  ];
  Timer? _debounceTimer;
  StreamSubscription? _widthSubscription;
  StreamSubscription? _heightSubscription;

  // ✅ 保存所有订阅以便清理
  StreamSubscription? _playingSubscription;
  StreamSubscription? _errorSubscription;
  StreamSubscription? _pipStatusSubscription;
  StreamSubscription<BatteryState>? _batterySubscription; // ✅ 新增
  Worker? _hasErrorWorker;
  Worker? _showControllerWorker;
  Worker? _isPlayingWorker;
  Worker? _mediaInitializedWorker;
  Worker? _mobileInitializedWorker;
  
  // Danmaku 监听器
  Worker? _hideDanmakuWorker;
  Worker? _danmakuTopAreaWorker;
  Worker? _danmakuBottomAreaWorker;
  Worker? _danmakuSpeedWorker;
  Worker? _danmakuFontSizeWorker;
  Worker? _danmakuFontBorderWorker;
  Worker? _danmakuOpacityWorker;

  // Timer 引用
  Timer? _fullscreenTimer;
  Timer? _refreshTimer;
  Timer? _changeLineTimer;
  Timer? _toggleFullscreenTimer;
  Timer? _toggleWindowFullscreenTimer;

  void enableController() {
    if (hasDestory) return; // ✅ 添加检查
    showControllerTimer?.cancel();
    showControllerTimer = Timer(const Duration(seconds: 2), () {
      if (!hasDestory) {
        showController.value = false;
      }
    });
    showController.value = true;
  }

  final hideDanmaku = false.obs;
  final danmakuTopArea = 0.0.obs;
  final danmakuBottomArea = 0.0.obs;
  final danmakuSpeed = 8.0.obs;
  final danmakuFontSize = 16.0.obs;
  final danmakuFontBorder = 4.0.obs;
  final danmakuOpacity = 1.0.obs;
  
  VideoController({
    required this.room,
    required this.datasourceType,
    required this.datasource,
    required this.headers,
    this.allowBackgroundPlay = false,
    this.allowScreenKeepOn = false,
    this.allowFullScreen = true,
    this.fullScreenByDefault = false,
    this.autoPlay = true,
    BoxFit fitMode = BoxFit.contain,
    required this.qualiteName,
    required this.currentLineIndex,
    required this.currentQuality,
    required this.videoPlayerIndex,
  }) {
    danmakuController = DanmakuController(
      onAddDanmaku: (item) {},
      onUpdateOption: (option) {},
      onPause: () {},
      onResume: () {},
      onClear: () {},
    );

    videoFitIndex.value = settings.videoFitIndex.value;
    videoFit.value = settings.videofitArrary[videoFitIndex.value];
    hideDanmaku.value = settings.hideDanmaku.value;
    danmakuTopArea.value = settings.danmakuTopArea.value;
    danmakuBottomArea.value = settings.danmakuBottomArea.value;
    danmakuSpeed.value = settings.danmakuSpeed.value;
    danmakuFontSize.value = settings.danmakuFontSize.value;
    danmakuFontBorder.value = settings.danmakuFontBorder.value;
    danmakuOpacity.value = settings.danmakuOpacity.value;
    initPagesConfig();
  }

  void initPagesConfig() {
    if (allowScreenKeepOn) WakelockPlus.enable();
    initVideoController();
    initDanmaku();
    initBattery();
  }

  // Battery level control
  final Battery _battery = Battery();
  final batteryLevel = 100.obs;

  late DanmakuController danmakuController;
  
  void initBattery() {
    if (Platform.isAndroid || Platform.isIOS) {
      _battery.batteryLevel.then((value) {
        if (!hasDestory) {
          batteryLevel.value = value;
        }
      });
      // ✅ 保存订阅引用
      _batterySubscription = _battery.onBatteryStateChanged.listen((BatteryState state) async {
        if (hasDestory) return;
        batteryLevel.value = await _battery.batteryLevel;
      });
    }
  }

  void initVideoController() async {
    FlutterVolumeController.updateShowSystemUI(false);
    registerVolumeListener();
    
    if (videoPlayerIndex == 0 || Platform.isWindows) {
      enableCodec = settings.enableCodec.value;
      playerCompatMode = settings.playerCompatMode.value;
      player = Player();
      if (player.platform is NativePlayer) {
        (player.platform as dynamic).setProperty('cache', 'no');
        (player.platform as dynamic).setProperty('cache-secs', '0');
        (player.platform as dynamic).setProperty('demuxer-seekable-cache', 'no');
        (player.platform as dynamic).setProperty('demuxer-max-back-bytes', '0');
        (player.platform as dynamic).setProperty('demuxer-donate-buffer', 'no');
        if (settings.customPlayerOutput.value) {
          (player.platform as dynamic).setProperty('ao', settings.audioOutputDriver.value);
        }
      }
      mediaPlayerController = media_kit_video.VideoController(
        player,
        configuration: settings.customPlayerOutput.value
            ? VideoControllerConfiguration(
                vo: settings.videoOutputDriver.value,
                hwdec: settings.videoHardwareDecoder.value,
              )
            : playerCompatMode
            ? VideoControllerConfiguration(vo: 'mediacodec_embed', hwdec: 'mediacodec')
            : VideoControllerConfiguration(
                enableHardwareAcceleration: enableCodec,
                androidAttachSurfaceAfterVideoParameters: false,
              ),
      );
      setDataSource(datasource);
      
      // ✅ 保存订阅引用
      _playingSubscription = mediaPlayerController.player.stream.playing.listen((bool playing) {
        if (hasDestory) return;
        isPlaying.value = playing;
        if (playing && mediaPlayerControllerInitialized.value == false) {
          mediaPlayerControllerInitialized.value = true;
          setVolume(settings.volume.value);
        }
      });
      
      _errorSubscription = mediaPlayerController.player.stream.error.listen((event) {
        if (hasDestory) return;
        if (event.toString().contains('Failed to open')) {
          hasError.value = true;
          isPlaying.value = false;
        }
      });
      
      _widthSubscription = player.stream.width.listen((event) {
        if (hasDestory) return;
        isVertical.value = (player.state.height ?? 9) > (player.state.width ?? 16);
      });
      
      _heightSubscription = player.stream.height.listen((event) {
        if (hasDestory) return;
        isVertical.value = (player.state.height ?? 9) > (player.state.width ?? 16);
      });
      
      // ✅ 保存 Worker
      _hasErrorWorker = debounce(hasError, (callback) {
        if (hasDestory) return;
        if (hasError.value && !livePlayController.isLastLine.value) {
          SmartDialog.showToast("视频播放失败,正在为您切换线路");
          changeLine();
        }
      }, time: const Duration(seconds: 2));

      _showControllerWorker = showController.listen((p0) {
        if (hasDestory) return;
        if (showController.value) {
          if (isPlaying.value) {
            isActivePause.value = false;
          }
        }
        if (isPlaying.value) {
          hasActivePause?.cancel();
        }
      });

      _isPlayingWorker = isPlaying.listen((p0) {
        if (hasDestory) return;
        // 代表手动暂停了
        if (!isPlaying.value) {
          if (showController.value) {
            isActivePause.value = true;
            hasActivePause?.cancel();
          } else {
            if (isActivePause.value) {
              hasActivePause?.cancel();
              hasActivePause = Timer(const Duration(seconds: 20), () {
                if (hasDestory) return;
                SmartDialog.showToast("系统监测视频已停止播放,正在为您刷新视频");
                isActivePause.value = false;
                refresh();
              });
            }
          }
        } else {
          hasActivePause?.cancel();
          isActivePause.value = false;
        }
      });

      _mediaInitializedWorker = mediaPlayerControllerInitialized.listen((value) {
        if (hasDestory) return;
        if (fullScreenByDefault && datasource.isNotEmpty && value) {
          _fullscreenTimer?.cancel();
          _fullscreenTimer = Timer(const Duration(milliseconds: 500), () {
            if (!hasDestory) toggleFullScreen();
          });
        }
      });
      
      if (Platform.isAndroid) {
        pip = Floating();
        _pipStatusSubscription = pip.pipStatusStream.listen((status) async {
          if (hasDestory) return;
          if (status == PiPStatus.enabled) {
            isPipMode.value = true;
          } else {
            isPipMode.value = false;
            isFullscreen.value = false;
            doExitFullScreen();
          }
        });
      }
    } else {
      mobileController = BetterPlayerController(
        BetterPlayerConfiguration(
          controlsConfiguration: BetterPlayerControlsConfiguration(
            playerTheme: BetterPlayerTheme.custom,
            customControlsBuilder: (controller, onControlsVisibilityChanged) => VideoControllerPanel(controller: this),
          ),
          autoPlay: true,
          fit: videoFit.value,
          allowedScreenSleep: !allowScreenKeepOn,
          autoDetectFullscreenDeviceOrientation: true,
          autoDetectFullscreenAspectRatio: true,
          errorBuilder: (context, errorMessage) => Container(),
          handleLifecycle: true,
        ),
      );
      mobileController?.setControlsEnabled(false);
      setDataSource(datasource);

      mobileController?.addEventsListener(mobileStateListener);
      
      _mobileInitializedWorker = mediaPlayerControllerInitialized.listen((value) {
        if (hasDestory) return;
        if (fullScreenByDefault && datasource.isNotEmpty && value) {
          _fullscreenTimer?.cancel();
          _fullscreenTimer = Timer(const Duration(milliseconds: 500), () {
            if (!hasDestory) toggleFullScreen();
          });
        }
      });
      
      _hasErrorWorker = debounce(hasError, (callback) {
        if (hasDestory) return;
        if (hasError.value && !livePlayController.isLastLine.value) {
          SmartDialog.showToast("视频播放失败,正在为您切换线路");
          changeLine();
        }
      }, time: const Duration(seconds: 2));

      _showControllerWorker = showController.listen((p0) {
        if (hasDestory) return;
        if (showController.value) {
          if (isPlaying.value) {
            isActivePause.value = false;
          }
        }
        if (isPlaying.value) {
          hasActivePause?.cancel();
        }
      });

      _isPlayingWorker = isPlaying.listen((p0) {
        if (hasDestory) return;
        if (!isPlaying.value) {
          if (showController.value) {
            isActivePause.value = true;
            hasActivePause?.cancel();
          } else {
            if (isActivePause.value) {
              hasActivePause?.cancel();
              hasActivePause = Timer(const Duration(seconds: 20), () {
                if (hasDestory) return;
                SmartDialog.showToast("系统监测视频已停止播放,正在为您刷新视频");
                isActivePause.value = false;
                refresh();
              });
            }
          }
        } else {
          hasActivePause?.cancel();
          isActivePause.value = false;
        }
      });
    }
  }

  dynamic mobileStateListener(BetterPlayerEvent event) {
    if (hasDestory) return; // ✅ 添加检查
    if (mobileController?.videoPlayerController != null) {
      hasError.value = mobileController?.videoPlayerController?.value.hasError ?? false;
      isPlaying.value = mobileController?.isPlaying() ?? false;
      isBuffering.value = mobileController?.isBuffering() ?? false;
      isPipMode.value = mobileController?.videoPlayerController?.value.isPip ?? false;
      if (isPlaying.value && mediaPlayerControllerInitialized.value == false) {
        mediaPlayerControllerInitialized.value = true;
        setVolume(settings.volume.value);
        isVertical.value =
            (mobileController?.videoPlayerController!.value.size!.height ?? 9) >
            (mobileController?.videoPlayerController!.value.size!.width ?? 16);
      }
    }
  }

  void debounceListen(Function? func, [int delay = 1000]) {
    if (_debounceTimer != null) {
      _debounceTimer?.cancel();
    }
    _debounceTimer = Timer(Duration(milliseconds: delay), () {
      if (!hasDestory) {
        func?.call();
      }
      _debounceTimer = null;
    });
  }

  void initDanmaku() {
    hideDanmaku.value = PrefUtil.getBool('hideDanmaku') ?? false;
    
    // ✅ 保存所有 Worker
    _hideDanmakuWorker = hideDanmaku.listen((data) {
      if (hasDestory) return;
      if (data) {
        danmakuController.clear();
      }
      PrefUtil.setBool('hideDanmaku', data);
      settings.hideDanmaku.value = data;
    });
    
    danmakuTopArea.value = PrefUtil.getDouble('danmakuTopArea') ?? 0.0;
    _danmakuTopAreaWorker = danmakuTopArea.listen((data) {
      if (hasDestory) return;
      PrefUtil.setDouble('danmakuTopArea', data);
      settings.danmakuTopArea.value = data;
      updateDanmaku();
    });
    
    danmakuBottomArea.value = PrefUtil.getDouble('danmakuBottomArea') ?? 0.0;
    _danmakuBottomAreaWorker = danmakuBottomArea.listen((data) {
      if (hasDestory) return;
      PrefUtil.setDouble('danmakuBottomArea', data);
      settings.danmakuBottomArea.value = data;
      updateDanmaku();
    });
    
    danmakuSpeed.value = PrefUtil.getDouble('danmakuSpeed') ?? 8;
    _danmakuSpeedWorker = danmakuSpeed.listen((data) {
      if (hasDestory) return;
      PrefUtil.setDouble('danmakuSpeed', data);
      settings.danmakuSpeed.value = data;
      updateDanmaku();
    });
    
    danmakuFontSize.value = PrefUtil.getDouble('danmakuFontSize') ?? 16;
    _danmakuFontSizeWorker = danmakuFontSize.listen((data) {
      if (hasDestory) return;
      PrefUtil.setDouble('danmakuFontSize', data);
      settings.danmakuFontSize.value = data;
      updateDanmaku();
    });
    
    danmakuFontBorder.value = PrefUtil.getDouble('danmakuFontBorder') ?? 4.0;
    _danmakuFontBorderWorker = danmakuFontBorder.listen((data) {
      if (hasDestory) return;
      PrefUtil.setDouble('danmakuFontBorder', data);
      settings.danmakuFontBorder.value = data;
      updateDanmaku();
    });
    
    danmakuOpacity.value = PrefUtil.getDouble('danmakuOpacity') ?? 1.0;
    _danmakuOpacityWorker = danmakuOpacity.listen((data) {
      if (hasDestory) return;
      PrefUtil.setDouble('danmakuOpacity', data);
      settings.danmakuOpacity.value = data;
      updateDanmaku();
    });
  }

  void updateDanmaku() {
    if (hasDestory) return; // ✅ 添加检查
    danmakuController.updateOption(
      DanmakuOption(
        fontSize: danmakuFontSize.value,
        topArea: danmakuTopArea.value,
        bottomArea: danmakuBottomArea.value,
        duration: danmakuSpeed.value.toInt(),
        opacity: danmakuOpacity.value,
        fontWeight: danmakuFontBorder.value.toInt(),
      ),
    );
  }

  void sendDanmaku(LiveMessage msg) {
    if (hasDestory || hideDanmaku.value) return; // ✅ 添加检查
    if (isPlaying.value) {
      danmakuController.addDanmaku(
        DanmakuContentItem(msg.message, color: Color.fromARGB(255, msg.color.r, msg.color.g, msg.color.b)),
      );
    }
  }

  @override
  void dispose() {
    // ✅ 移除 async
    if (hasDestory == false) {
      destory(); // ✅ 移除 await
    }
    super.dispose();
  }

  void refresh() async {
    if (hasDestory) return; // ✅ 添加检查
    await destory();
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(seconds: 2), () {
      if (!hasDestory) {
        livePlayController.onInitPlayerState(reloadDataType: ReloadDataType.refreash);
      }
    });
  }

  void changeLine({bool active = false}) async {
    if (hasDestory) return; // ✅ 添加检查
    await destory();
    _changeLineTimer?.cancel();
    _changeLineTimer = Timer(const Duration(seconds: 2), () {
      if (!hasDestory) {
        livePlayController.onInitPlayerState(
          reloadDataType: ReloadDataType.changeLine,
          line: currentLineIndex,
          active: active,
        );
      }
    });
  }

  Future<void> destory() async {
    hasDestory = true;
    
    // ✅ 取消所有 Timer
    showControllerTimer?.cancel();
    hasActivePause?.cancel();
    _debounceTimer?.cancel();
    _fullscreenTimer?.cancel();
    _refreshTimer?.cancel();
    _changeLineTimer?.cancel();
    _toggleFullscreenTimer?.cancel();
    _toggleWindowFullscreenTimer?.cancel();
    
    // ✅ 取消所有订阅
    _playingSubscription?.cancel();
    _errorSubscription?.cancel();
    _widthSubscription?.cancel();
    _heightSubscription?.cancel();
    _pipStatusSubscription?.cancel();
    _batterySubscription?.cancel(); // ✅ 新增
    
    // ✅ 释放所有 Worker
    _hasErrorWorker?.dispose();
    _showControllerWorker?.dispose();
    _isPlayingWorker?.dispose();
    _mediaInitializedWorker?.dispose();
    _mobileInitializedWorker?.dispose();
    _hideDanmakuWorker?.dispose();
    _danmakuTopAreaWorker?.dispose();
    _danmakuBottomAreaWorker?.dispose();
    _danmakuSpeedWorker?.dispose();
    _danmakuFontSizeWorker?.dispose();
    _danmakuFontBorderWorker?.dispose();
    _danmakuOpacityWorker?.dispose();
    
    // ✅ 释放 danmakuController
    danmakuController.dispose();
    
    isPlaying.value = false;
    hasError.value = false;
    livePlayController.success.value = false;

    if (allowScreenKeepOn) WakelockPlus.disable();

    FlutterVolumeController.removeListener();
    
    if (Platform.isAndroid || Platform.isIOS) {
      brightnessController.resetApplicationScreenBrightness();
      if (isFullscreen.value) {
        if (videoPlayerIndex == 1) {
          mobileController?.exitFullScreen();
        } else {
          doExitFullScreen();
        }
      }
      if (videoPlayerIndex == 0) {
        player.dispose();
      } else {
        // ✅ 移除事件监听器
        mobileController?.removeEventsListener(mobileStateListener);
        mobileController?.dispose();
      }
    } else {
      if (isFullscreen.value) {
        doExitFullScreen();
      }
      player.dispose();
    }
    isFullscreen.value = false;
  }

  void setDataSource(String url) async {
    if (hasDestory) return; // ✅ 添加检查
    datasource = url;
    // fix datasource empty error
    if (datasource.isEmpty) {
      hasError.value = true;
      return;
    } else {
      hasError.value = false;
    }
    if (Platform.isWindows || videoPlayerIndex == 0) {
      player.pause();
      player.open(Media(datasource, httpHeaders: headers));
    } else {
      BetterPlayerVideoFormat? videoFormat;
      if (room.platform == Sites.bilibiliSite) {
        videoFormat = BetterPlayerVideoFormat.hls;
      }
      if (room.platform == Sites.huyaSite) {
        if (url.contains('.m3u8')) {
          videoFormat = BetterPlayerVideoFormat.hls;
        }
      }

      final result = await mobileController?.setupDataSource(
        BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          url,
          videoFormat: videoFormat,
          liveStream: true,
          notificationConfiguration: allowBackgroundPlay
              ? BetterPlayerNotificationConfiguration(
                  showNotification: true,
                  title: room.title,
                  author: room.nick,
                  imageUrl: room.avatar,
                  activityName: "MainActivity",
                )
              : null,
          headers: headers,
          bufferingConfiguration: BetterPlayerBufferingConfiguration(),
          cacheConfiguration: BetterPlayerCacheConfiguration(
            useCache: false,
          ),
        ),
      );
      log(result.toString(), name: 'video_player');
    }
    notifyListeners();
  }

  void setVideoFit(BoxFit fit) {
    if (hasDestory) return; // ✅ 添加检查
    videoFit.value = fit;
    settings.videoFitIndex.value = videoFitIndex.value;
    if (videoPlayerIndex == 1) {
      mobileController?.setOverriddenFit(videoFit.value);
      mobileController?.retryDataSource();
    }
  }

  void togglePlayPause() {
    if (hasDestory) return; // ✅ 添加检查
    if (Platform.isWindows || videoPlayerIndex == 0) {
      mediaPlayerController.player.playOrPause();
    } else {
      // ✅ 添加 null 检查
      if (mobileController != null) {
        isPlaying.value ? mobileController!.pause() : mobileController!.play();
      }
    }
  }

  void exitFullScreen() {
    if (hasDestory) return; // ✅ 添加检查
    if (videoPlayerIndex == 1) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!hasDestory) {
          mobileController?.exitFullScreen();
        }
      });
    } else {
      doExitFullScreen();
    }
    isFullscreen.value = false;
    showSettting.value = false;
  }

  /// 设置横屏
  Future setLandscapeOrientation() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }

  /// 设置竖屏
  Future setPortraitOrientation() async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
  }

  void toggleFullScreen() async {
    if (hasDestory) return; // ✅ 添加检查
    showLocked.value = false;
    showControllerTimer?.cancel();
    _toggleFullscreenTimer?.cancel();
    _toggleFullscreenTimer = Timer(const Duration(seconds: 2), () {
      if (!hasDestory) enableController();
    });
    
    if (isFullscreen.value) {
      if (Platform.isAndroid) {
        if (videoPlayerIndex == 1) {
          Future.delayed(const Duration(milliseconds: 100), () {
            if (!hasDestory) {
              mobileController?.exitFullScreen();
            }
          });
        } else {
          doExitFullScreen();
          await verticalScreen();
        }
      } else {
        doExitFullScreen();
      }
    } else {
      if (Platform.isAndroid) {
        if (videoPlayerIndex == 1) {
          mobileController?.enterFullScreen();
        } else {
          await doEnterFullScreen();
          if (isVertical.value) {
            await verticalScreen();
          } else {
            await landScape();
          }
        }
      } else {
        await doEnterFullScreen();
      }
    }

    isFullscreen.toggle();
  }

  void toggleWindowFullScreen() {
    if (hasDestory) return; // ✅ 添加检查
    showLocked.value = false;
    showControllerTimer?.cancel();
    _toggleWindowFullscreenTimer?.cancel();
    _toggleWindowFullscreenTimer = Timer(const Duration(seconds: 2), () {
      if (!hasDestory) enableController();
    });

    if (Platform.isWindows || Platform.isLinux) {
      if (!isWindowFullscreen.value) {
        Get.to(() => DesktopFullscreen(controller: this, key: UniqueKey()));
      } else {
        Navigator.of(Get.context!).pop();
      }
      isWindowFullscreen.toggle();
    } else {
      throw UnimplementedError('Unsupported Platform');
    }
    enableController();
  }

  void enterPipMode(BuildContext context) async {
    if (hasDestory) return; // ✅ 添加检查
    if ((Platform.isAndroid || Platform.isIOS)) {
      danmakuController.clear();
      danmakuController.resume();
      if (Platform.isWindows || videoPlayerIndex == 0) {
        isFullscreen.toggle();
        if (isVertical.value) {
          await verticalScreen();
        }
        doEnterFullScreen();
        await pip.enable(ImmediatePiP());
      } else {
        if (await mobileController?.isPictureInPictureSupported() ?? false) {
          isPipMode.value = true;
          mobileController?.enablePictureInPicture(playerKey);
        }
      }
    }
  }

  // 注册音量变化监听器
  void registerVolumeListener() {
    FlutterVolumeController.addListener((volume) {
      if (hasDestory) return;
      if (Platform.isAndroid) {
        settings.volume.value = volume;
      }
    });
  }

  // volume & brightness
  Future<double?> volume() async {
    if (Platform.isWindows) {
      return mediaPlayerController.player.state.volume / 100;
    }
    return await FlutterVolumeController.getVolume();
  }

  Future<double> brightness() async {
    return await brightnessController.application;
  }

  void setVolume(double value) async {
    if (hasDestory) return; // ✅ 添加检查
    if (Platform.isWindows) {
      mediaPlayerController.player.setVolume(value * 100);
    } else {
      await FlutterVolumeController.setVolume(value);
    }
    settings.volume.value = value;
  }

  void setBrightness(double value) async {
    if (hasDestory) return; // ✅ 添加检查
    if (Platform.isAndroid || Platform.isIOS) {
      await brightnessController.setApplicationScreenBrightness(value);
    }
  }
}

// use fullscreen with controller provider

class DesktopFullscreen extends StatelessWidget {
  const DesktopFullscreen({super.key, required this.controller});
  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.passthrough,
          children: [
            Container(
              color: Colors.black,
            ),
            Obx(
              () => media_kit_video.Video(
                key: ValueKey(controller.videoFit.value),
                pauseUponEnteringBackgroundMode: !controller.settings.enableBackgroundPlay.value,
                resumeUponEnteringForegroundMode: !controller.settings.enableBackgroundPlay.value,
                controller: controller.mediaPlayerController,
                fit: controller.videoFit.value,
                controls: controller.room.platform == Sites.iptvSite
                    ? media_kit_video.MaterialVideoControls
                    : (state) => VideoControllerPanel(controller: controller),
              ),
            ),
          ],
        ),
      ),
    );
  }
}