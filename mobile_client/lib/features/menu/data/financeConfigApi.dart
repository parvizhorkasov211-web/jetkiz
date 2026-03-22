import 'package:jetkiz_mobile/core/network/apiClient.dart';

class FinanceConfigApi {
  FinanceConfigApi(this._apiClient);

  final ApiClient _apiClient;

  Future<FinanceConfigData> getFinanceConfig() async {
    final response = await _apiClient.dio.get('/restaurants/finance/config');
    final data = response.data as Map<String, dynamic>? ?? <String, dynamic>{};

    return FinanceConfigData.fromJson(data);
  }
}

class FinanceConfigData {
  const FinanceConfigData({
    required this.clientDeliveryFeeDefault,
    required this.clientDeliveryFeeWeather,
    required this.courierPayoutDefault,
    required this.courierPayoutWeather,
    required this.weatherEnabled,
  });

  final int clientDeliveryFeeDefault;
  final int clientDeliveryFeeWeather;
  final int courierPayoutDefault;
  final int courierPayoutWeather;
  final bool weatherEnabled;

  int get activeDeliveryFee {
    return weatherEnabled ? courierPayoutWeather : courierPayoutDefault;
  }

  factory FinanceConfigData.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.round();
      return 0;
    }

    return FinanceConfigData(
      clientDeliveryFeeDefault: asInt(json['clientDeliveryFeeDefault']),
      clientDeliveryFeeWeather: asInt(json['clientDeliveryFeeWeather']),
      courierPayoutDefault: asInt(json['courierPayoutDefault']),
      courierPayoutWeather: asInt(json['courierPayoutWeather']),
      weatherEnabled: json['weatherEnabled'] == true,
    );
  }
}
