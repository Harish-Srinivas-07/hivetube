class HistoryEntry {
  const HistoryEntry(
    this.videoId,
    this.position,
    this.duration, {
    this.isShort = false,
    this.channelName = '',
    this.title = '',
    this.channelId = '',
    this.thumbUrl = '',
  });
  final String videoId;
  final Duration position, duration;
  final bool isShort;
  final String channelName, title, channelId, thumbUrl;
}
