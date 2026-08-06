/// 账户配置，与桌面版 config.json 的账户字段对应。
class Account {
  const Account({
    required this.name,
    required this.provider,
    required this.apiKey,
    this.baseUrl,
    this.quotaDenominator = 500000,
    this.quotaCurrency = 'CNY',
  });

  /// 显示名称，同时作为账户唯一标识。
  final String name;

  /// deepseek / openai / openai_compat。
  final String provider;

  /// API Key，手机端保存在系统安全存储（Keychain/Keystore）中。
  final String apiKey;

  /// openai_compat 必填，如 https://your-relay.example.com。
  final String? baseUrl;

  /// 中转渠道 quota 换算分母，默认 500000。
  final double quotaDenominator;

  /// 中转渠道币种，默认 CNY。
  final String quotaCurrency;

  static const List<String> providerOptions = <String>[
    'deepseek',
    'openai',
    'openai_compat',
  ];

  bool get isCompat => provider == 'openai_compat';

  Account copyWith({
    String? name,
    String? provider,
    String? apiKey,
    String? baseUrl,
    double? quotaDenominator,
    String? quotaCurrency,
  }) {
    return Account(
      name: name ?? this.name,
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      quotaDenominator: quotaDenominator ?? this.quotaDenominator,
      quotaCurrency: quotaCurrency ?? this.quotaCurrency,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'provider': provider,
        'api_key': apiKey,
        'base_url': baseUrl,
        'quota_denominator': quotaDenominator,
        'quota_currency': quotaCurrency,
      };

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      name: json['name'] as String,
      provider: json['provider'] as String,
      apiKey: (json['api_key'] as String?) ?? '',
      baseUrl: json['base_url'] as String?,
      quotaDenominator:
          (json['quota_denominator'] as num?)?.toDouble() ?? 500000,
      quotaCurrency: (json['quota_currency'] as String?) ?? 'CNY',
    );
  }
}
