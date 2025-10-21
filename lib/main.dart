import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:get/get.dart';
import 'package:flutter/services.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/plugins/global.dart';
import 'package:pure_live/routes/app_navigation.dart';
import 'package:pure_live/plugins/file_recover_utils.dart';
import 'package:pure_live/common/services/bilibili_account_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

const kWindowsScheme = 'purelive://signin';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  PrefUtil.prefs = await SharedPreferences.getInstance();
  MediaKit.ensureInitialized();
  if (Platform.isWindows) {
    await WindowsSingleInstance.ensureSingleInstance(args, "pure_live_instance_checker");
    await windowManager.ensureInitialized();
    await WindowUtil.init(width: 1280, height: 720);
  }
  // 先初始化supdatabase
  await SupaBaseManager.getInstance().initial();
  // 初始化服务
  initService();
  initRefresh();
  runApp(const MyApp());
}

void initService() {
  Get.put(SettingsService());
  Get.put(AuthController());
  Get.put(FavoriteController());
  Get.put(BiliBiliAccountService());
  Get.put(PopularController());
  Get.put(AreasController());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  final settings = Get.find<SettingsService>();
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _init();
  }

  String getName(String fullName) {
    return fullName.split(Platform.pathSeparator).last;
  }

  bool isDataSourceM3u(String url) => url.contains('.m3u');
  String getUUid() {
    var currentTime = DateTime.now().millisecondsSinceEpoch;
    var randomValue = Random().nextInt(4294967295);
    var result = (currentTime % 10000000000 * 1000 + randomValue) % 4294967295;
    return result.toString();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initShareM3uState() async {
    if (Platform.isAndroid) {
      final handler = ShareHandler.instance;
      await handler.getInitialSharedMedia();
      handler.sharedMediaStream.listen((SharedMedia media) async {
        if (isDataSourceM3u(media.content!)) {
          FileRecoverUtils().recoverM3u8BackupByShare(media);
        }
      });
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowFocus() {
    setState(() {});
    super.onWindowFocus();
  }

  @override
  void onWindowEvent(String eventName) {
    WindowUtil.setPosition();
  }

  void _init() async {
    if (Platform.isWindows) {
      await WindowUtil.setTitle();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // ===============================================================
    // │                  [核心修正] 使用 ScreenUtilInit 包裹 App        │
    // ===============================================================
    return ScreenUtilInit(
      // 设置设计稿尺寸
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      // 使用 builder 来确保 ScreenUtil 初始化完成后再构建 MaterialApp
      builder: (context, child) {
        return Shortcuts(
          shortcuts: {LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent()},
          child: DynamicColorBuilder(
            builder: (lightDynamic, darkDynamic) {
              return Obx(() {
                if (Platform.isWindows) {
                  settings.videoPlayerIndex.value = 0;
                } else {
                  if (settings.videoPlayerIndex.value > 1) {
                    settings.videoPlayerIndex.value = 0;
                  }
                }

                var themeColor = HexColor(settings.themeColorSwitch.value);
                ThemeData lightTheme = MyTheme(primaryColor: themeColor).lightThemeData;
                ThemeData darkTheme = MyTheme(primaryColor: themeColor).darkThemeData;
                if (settings.enableDynamicTheme.value) {
                  lightTheme = MyTheme(colorScheme: lightDynamic).lightThemeData;
                  darkTheme = MyTheme(colorScheme: darkDynamic).darkThemeData;
                }
                return GetMaterialApp(
                  // [核心修正] 将弹窗初始化和字体缩放逻辑放到这里的 builder 中
                  builder: (context, widget) {
                    // 初始化弹窗工具
                    widget = FlutterSmartDialog.init()(context, widget);
                    // 保证文字大小不随系统设置变化
                    return MediaQuery(
                      data: MediaQuery.of(context).copyWith(
                        textScaler: TextScaler.linear(1.0),
                      ),
                      child: widget,
                    );
                  },
                  title: '纯粹直播',
                  themeMode: SettingsService.themeModes[settings.themeModeName.value]!,
                  theme: lightTheme.copyWith(appBarTheme: AppBarTheme(surfaceTintColor: Colors.transparent)),
                  darkTheme: darkTheme.copyWith(appBarTheme: AppBarTheme(surfaceTintColor: Colors.transparent)),
                  locale: SettingsService.languages[settings.languageName.value]!,
                  navigatorObservers: [FlutterSmartDialog.observer, BackButtonObserver()],
                  supportedLocales: S.delegate.supportedLocales,
                  localizationsDelegates: const [
                    S.delegate,
                    GlobalMaterialLocalizations.delegate,
                    GlobalWidgetsLocalizations.delegate,
                    GlobalCupertinoLocalizations.delegate,
                  ],
                  initialRoute: RoutePath.kSplash,
                  defaultTransition: Transition.native,
                  getPages: AppPages.routes,
                );
              });
            },
          ),
        );
      },
    );
  }
}