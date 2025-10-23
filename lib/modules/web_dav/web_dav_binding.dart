import 'package:get/get.dart';
import 'package:pure_live/modules/web_dav/web_dav_controller.dart';

class WebDavBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => WebDavController())];
  }
}
