/// 金额格式化：null 显示为 "-"。
String formatMoney(double? value) {
  if (value == null) {
    return '-';
  }
  return value.toStringAsFixed(4);
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime t) {
  return '${t.year}-${_two(t.month)}-${_two(t.day)} '
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

String formatTime(DateTime t) {
  return '${_two(t.hour)}:${_two(t.minute)}';
}

/// 提供商显示名。
String providerLabel(String provider) {
  switch (provider) {
    case 'deepseek':
      return 'DeepSeek';
    case 'openai':
      return 'OpenAI';
    case 'openai_compat':
      return '中转渠道';
    default:
      return provider;
  }
}

/// 字节数格式化：用于显示更新包大小。
String formatBytes(int bytes) {
  if (bytes <= 0) {
    return '未知大小';
  }
  if (bytes >= 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}
