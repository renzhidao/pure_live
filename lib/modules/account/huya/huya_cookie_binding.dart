import 'package:get/get.dart';
import 'package:pure_live/modules/account/huya/huya_cookie_controller.dart';

class HuyaCookieBinding extends Binding {
  @override
  List<Bind> dependencies() {
    return [Bind.lazyPut(() => HuyaCookieController())];
  }
}
