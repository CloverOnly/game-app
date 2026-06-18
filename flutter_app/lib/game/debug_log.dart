/// 게임 디버그 로그 (HUD + 콘솔)
class GameDebugLog {
  GameDebugLog();

  final List<String> lines = [];
  static const maxLines = 8;

  void log(String message) {
    final ts = DateTime.now().toString().substring(11, 19);
    final line = '[$ts] $message';
    lines.insert(0, line);
    if (lines.length > maxLines) {
      lines.removeRange(maxLines, lines.length);
    }
    // ignore: avoid_print
    print('[LandGrabber] $message');
  }

  void clear() => lines.clear();
}
