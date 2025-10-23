import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';

class FavoriteAreasController extends GetxController with GetTickerProviderStateMixin {
  late TabController tabSiteController;
  final setting = Get.find<SettingsService>();
  var tabSiteIndex = 0.obs;
  var favoriteAreas = [].obs;
  @override
  void onInit() {
    tabSiteController = TabController(length: Sites().availableSites().length + 1, vsync: this);
    tabSiteController.addListener(() {
      tabSiteIndex.value = tabSiteController.index;
    });
    favoriteAreas.value = setting.favoriteAreas.value;
    super.onInit();
  }
}
