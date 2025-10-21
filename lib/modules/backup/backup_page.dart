import 'dart:io';
import 'dart:convert';
import 'package:get/get.dart';
import 'package:pure_live/common/index.dart';
import 'package:pure_live/modules/backup/scan_page.dart';
import 'package:pure_live/plugins/file_recover_utils.dart';
import 'package:pure_live/modules/auth/utils/constants.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key});

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  final settings = Get.find<SettingsService>();

  // 创建备份
  Future<void> _createBackup() async {
    try {
      // 1. 检查权限
      if (Platform.isAndroid || Platform.isIOS) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            SmartDialog.showToast('需要存储权限来创建备份');
            return;
          }
        }
      }

      // 2. 获取数据并转为格式化的JSON字符串
      final backupData = settings.toJson();
      const jsonEncoder = JsonEncoder.withIndent('  ');
      final jsonString = jsonEncoder.convert(backupData);

      // 3. 选择保存路径
      final fileName = 'pure_live_backup_${DateTime.now().toIso8601String().split('T').first}.json';
      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: '请选择备份文件保存位置',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      
      if (outputPath == null) {
        SmartDialog.showToast('取消了备份');
        return;
      }
      
      // 4. 写入文件
      final file = File(outputPath);
      await file.writeAsString(jsonString);

      SmartDialog.showToast('备份成功!\n路径: $outputPath');
    } catch (e) {
      SmartDialog.showToast('备份失败: ${e.toString()}');
    }
  }

  // 恢复备份
  Future<void> _recoverBackup() async {
    try {
      // 1. 选择备份文件
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.single.path == null) {
        SmartDialog.showToast('取消了恢复');
        return;
      }

      // 2. 读取文件内容
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();

      // 3. 解析JSON并应用数据
      final jsonData = jsonDecode(jsonString);
      settings.fromJson(jsonData);

      SmartDialog.showToast('恢复成功!');
    } catch (e) {
      SmartDialog.showToast('恢复失败: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).backup_recover),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          ListTile(
            leading: const Icon(Icons.cloud_upload_rounded),
            title: Text(S.of(context).create_backup),
            subtitle: Text(S.of(context).create_backup_subtitle),
            onTap: _createBackup,
          ),
          ListTile(
            leading: const Icon(Icons.cloud_download_rounded),
            title: Text(S.of(context).recover_backup),
            subtitle: Text(S.of(context).recover_backup_subtitle),
            onTap: _recoverBackup,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.important_devices_rounded),
            title: const Text('同步TV数据'),
            subtitle: const Text('将数据远程同步到TV'),
            onTap: () {
              Get.to(() => const ScanCodePage());
            },
          ),
          ListTile(
            leading: const Icon(Icons.sync_alt_rounded),
            title: Text('WebDav'),
            subtitle: Text('通过WebDav服务器同步/备份'),
            onTap: () async {
              Get.toNamed(RoutePath.kWebDavPage);
            },
          ),
        ],
      ),
    );
  }
}