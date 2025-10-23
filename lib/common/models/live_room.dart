
enum LiveStatus { live, offline, replay, unknown, banned }

class LiveRoom {
  String? roomId;
  String? userId = '';
  String? link = '';
  String? title = '';
  String? nick = '';
  String? avatar = '';
  String? cover = '';
  String? area = '';
  String? watching = '';
  String? followers = '';
  String? platform = 'UNKNOWN';

  /// 介绍
  String? introduction;

  /// 公告
  String? notice;

  /// 状态
  bool? status;

  /// 附加信息
  dynamic data;

  /// 弹幕附加信息
  dynamic danmakuData;

  /// 是否录播
  bool? isRecord = false;
  // 直播状态
  LiveStatus? liveStatus = LiveStatus.offline;

  // 添加未命名的默认构造函数
  LiveRoom({
    this.roomId,
    this.userId,
    this.link,
    this.title = '',
    this.nick = '',
    this.avatar = '',
    this.cover = '',
    this.area,
    this.watching = '0',
    this.followers = '0',
    this.platform,
    this.liveStatus,
    this.data,
    this.danmakuData,
    this.isRecord = false,
    this.status = false,
    this.notice,
    this.introduction,
  });

  LiveRoom.fromJson(Map<String, dynamic> json)
    : roomId = json['roomId'] ?? '',
      userId = json['userId'] ?? '',
      title = json['title'] ?? '',
      link = json['link'] ?? '',
      nick = json['nick'] ?? '',
      avatar = json['avatar'] ?? '',
      cover = json['cover'] ?? '',
      area = json['area'] ?? '',
      watching = json['watching'] ?? '',
      followers = json['followers'] ?? '',
      platform = json['platform'] ?? '',
      liveStatus = LiveStatus.values[json['liveStatus'] ?? 1],
      status = json['status'] ?? false,
      notice = json['notice'] ?? '',
      introduction = json['introduction'] ?? '',
      isRecord = json['isRecord'] ?? false;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'roomId': roomId,
    'userId': userId,
    'title': title,
    'nick': nick,
    'avatar': avatar,
    'cover': cover,
    'area': area,
    'watching': watching,
    'followers': followers,
    'platform': platform,
    'liveStatus': liveStatus?.index ?? 1,
    'isRecord': isRecord,
    'status': status,
    'notice': notice,
    'introduction': introduction,
  };

  /// 创建一个新的LiveRoom实例，并用提供的值更新指定字段
  LiveRoom copyWith({
    String? roomId,
    String? userId,
    String? link,
    String? title,
    String? nick,
    String? avatar,
    String? cover,
    String? area,
    String? watching,
    String? followers,
    String? platform,
    String? introduction,
    String? notice,
    bool? status,
    dynamic data,
    dynamic danmakuData,
    bool? isRecord,
    LiveStatus? liveStatus,
  }) {
    return LiveRoom(
      roomId: roomId ?? this.roomId,
      userId: userId ?? this.userId,
      link: link ?? this.link,
      title: title ?? this.title,
      nick: nick ?? this.nick,
      avatar: avatar ?? this.avatar,
      cover: cover ?? this.cover,
      area: area ?? this.area,
      watching: watching ?? this.watching,
      followers: followers ?? this.followers,
      platform: platform ?? this.platform,
      introduction: introduction ?? this.introduction,
      notice: notice ?? this.notice,
      status: status ?? this.status,
      data: data ?? this.data,
      danmakuData: danmakuData ?? this.danmakuData,
      isRecord: isRecord ?? this.isRecord,
      liveStatus: liveStatus ?? this.liveStatus,
    );
  }

  /// 外部收藏结构转 LiveRoom（适配第三方 txt/json）
  /// 支持字段：
  /// - siteId/platform/id 前缀：平台
  /// - roomId 或 id 的后半段：房间号
  /// - userName -> nick
  /// - face/avatar -> avatar
  factory LiveRoom.fromExternalFavorite(Map<String, dynamic> ext) {
    String? rawPlatform = (ext['siteId'] ?? ext['platform'] ?? '').toString();
    String? rawId = (ext['id'] ?? '').toString();
    String? rawRoomId = (ext['roomId'] ?? '').toString();
    String? rawLink = (ext['link'] ?? '').toString();
    String? userName = (ext['userName'] ?? ext['name'] ?? ext['nick'] ?? '').toString();
    String? face = (ext['face'] ?? ext['avatar'] ?? '').toString();

    String platform = _normalizePlatform(rawPlatform, fallbackId: rawId, fallbackLink: rawLink);
    String roomId = _extractRoomId(rawRoomId, rawId);

    return LiveRoom(
      roomId: roomId,
      platform: platform,
      nick: userName,
      avatar: face,
      liveStatus: LiveStatus.unknown,
      title: '',
      link: rawLink,
      isRecord: false,
      status: false,
    );
  }

  static String _extractRoomId(String rawRoomId, String rawId) {
    if (rawRoomId.isNotEmpty) return rawRoomId;
    // 尝试从 id 里截取 platform_roomId 的后半段
    if (rawId.contains('_')) {
      final parts = rawId.split('_');
      if (parts.length >= 2 && parts[1].isNotEmpty) return parts[1];
    }
    // 兜底：提取连续数字
    final match = RegExp(r'(\d{2,})').firstMatch(rawId);
    if (match != null) return match.group(1) ?? '';
    return '';
  }

  static String _normalizePlatform(String? platform, {String? fallbackId, String? fallbackLink}) {
    final p = (platform ?? '').toLowerCase().trim();
    String byP;
    if (p.contains('bili')) byP = 'bilibili';
    else if (p.contains('douyu')) byP = 'douyu';
    else if (p.contains('huya')) byP = 'huya';
    else if (p.contains('douyin') || p.contains('tik')) byP = 'douyin';
    else if (p.contains('kuaishou') || p.contains('kuaishow')) byP = 'kuaishou';
    else if (p == 'cc' || p.contains('cc.163')) byP = 'cc';
    else if (p.contains('iptv') || p.contains('网络')) byP = 'iptv';
    else byP = '';

    if (byP.isNotEmpty) return byP;

    // 通过 id 前缀推断
    if ((fallbackId ?? '').contains('_')) {
      final pref = fallbackId!.split('_').first.toLowerCase();
      if (['bilibili', 'douyu', 'huya', 'douyin', 'kuaishou', 'kuaishow', 'cc', 'iptv'].contains(pref)) {
        return pref == 'kuaishow' ? 'kuaishou' : pref;
      }
    }

    // 通过链接域名推断
    final link = (fallbackLink ?? '').toLowerCase();
    if (link.contains('bilibili.com')) return 'bilibili';
    if (link.contains('douyu.com')) return 'douyu';
    if (link.contains('huya.com')) return 'huya';
    if (link.contains('douyin.com') || link.contains('iesdouyin.com')) return 'douyin';
    if (link.contains('kuaishou.com') || link.contains('kwai.com')) return 'kuaishou';
    if (link.contains('cc.163.com')) return 'cc';
    return 'UNKNOWN';
  }

  @override
  bool operator ==(covariant LiveRoom other) => platform == other.platform && roomId == other.roomId;

  @override
  int get hashCode => Object.hash(platform, roomId);
}