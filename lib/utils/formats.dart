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
