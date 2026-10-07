import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/models.dart';
import '../utils/constants.dart';

class ApiService {
  static String _genSessionId() {
    final r = Random.secure();
    final hex = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  static Map<String, String> baseHeaders({Map<String, String>? extra}) {
    final h = <String, String>{
      'user-agent': 'Twist-Mobile/9999 (Android; 12; SM-A217F; music; ar-AE)',
      'app_version': '9999',
      'appversion': '9999',
      'channel': 'mobileapp',
      'content-type': 'application/json',
      'platform': 'android',
      'accept': 'application/json',
      'accept-language': 'ar',
      'device_id': 'SP1A.210812.016',
      'tgdeviceid': '26284330',
      'device_token': '',
      'tg-token': '',
      'tg-refresh-token': '',
      'access-token': '',
      'sessionid': _genSessionId(),
      'connection': 'keep-alive',
    };
    if (extra != null) h.addAll(extra);
    return h;
  }

  static Future<bool> sendOtp(String phone) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiBase}/music/Dlogin/sendCode'),
        headers: baseHeaders(),
        body: jsonEncode({'dial': phone}),
      ).timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>?> verifyOtp(String phone, String code) async {
    try {
      final headers = baseHeaders();
      final res = await http.post(
        Uri.parse('${AppConstants.apiBase}/music/Dlogin/verify'),
        headers: headers,
        body: jsonEncode({
          'dial': phone,
          'verifyCode': code,
          'socialServiceName': '',
          'socialServiceToken': '',
        }),
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) return null;

      dynamic data;
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = null;
      }

      String? token;
      if (data is Map) token = data['token'] ?? data['authorization'];
      token ??= res.headers['authorization'];
      if (token == null || token.isEmpty) return null;
      token = token.replaceAll('Bearer ', '');

      final newHeaders = Map<String, String>.from(headers);
      newHeaders['authorization'] = 'Bearer $token';

      if (data is Map) {
        newHeaders['access-token'] = (data['accessToken'] ?? '').toString();
        newHeaders['tg-token'] = (data['tgToken'] ?? data['tg_token'] ?? '').toString();
        newHeaders['tg-refresh-token'] =
            (data['tgRefreshToken'] ?? data['tg_refresh_token'] ?? '').toString();
        newHeaders['tgdeviceid'] =
            (data['tgDeviceId'] ?? data['tg_device_id'] ?? '26284330').toString();
      }

      return newHeaders;
    } catch (_) {
      return null;
    }
  }

  static Future<int> getBalance(Map<String, String> headers) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.apiBase}/music/user/loyalty/balance/details'),
        headers: headers,
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return int.tryParse((data['balance'] ?? 0).toString()) ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<bool> isSessionValid(Map<String, String> headers) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.apiBase}/music/user/loyalty/balance/details'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<List<Task>> getTasks(Map<String, String> headers) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.apiBase}/music/user/loyalty/achievements/v2'),
        headers: headers,
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      final list = <Task>[];
      final badges = data['badges'];
      if (badges is List) {
        for (final cat in badges) {
          if (cat is Map) {
            final tasks = cat['badges'];
            if (tasks is List) {
              for (final t in tasks) {
                if (t is Map) {
                  final id = t['id']?.toString();
                  final rewarded = t['rewarded'] == true;
                  final coins = int.tryParse((t['coins'] ?? 0).toString()) ?? 0;
                  final title = (t['title'] ?? id ?? '').toString();
                  if (id != null && !rewarded) {
                    list.add(Task(id: id, coins: coins, title: title));
                  }
                }
              }
            }
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<int> completeTask(Map<String, String> headers, String actionId) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiBase}/music/loyalty/action/$actionId'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));
      return res.statusCode;
    } catch (_) {
      return -1;
    }
  }

  static Future<List<Transaction>> getHistory(Map<String, String> headers) async {
    final all = <Transaction>[];
    String? token;
    while (true) {
      try {
        var url = '${AppConstants.apiBase}/music/user/loyalty/history';
        if (token != null && token.isNotEmpty) {
          url += '?paginationToken=$token';
        }
        final res = await http.get(Uri.parse(url), headers: headers)
            .timeout(const Duration(seconds: 12));
        if (res.statusCode != 200) break;
        final data = jsonDecode(res.body);
        final list = data['data'];
        if (list is! List || list.isEmpty) break;
        for (final t in list) {
          if (t is Map) {
            all.add(Transaction.fromJson(Map<String, dynamic>.from(t)));
          }
        }
        token = data['paginationTokens']?.toString();
        if (token == null || token.isEmpty) break;
      } catch (_) {
        break;
      }
    }
    return all;
  }

  static Future<List<RedeemPackage>> getPackages(Map<String, String> headers) async {
    try {
      final res = await http.get(
        Uri.parse('${AppConstants.apiBase}/music/user/loyalty/packages'),
        headers: headers,
      ).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return _fallbackPackages();
      final data = jsonDecode(res.body);
      final list = <RedeemPackage>[];
      final pkgs = data['packages']?['E_AND'];
      if (pkgs is List) {
        for (final p in pkgs) {
          if (p is Map && p['available'] == true) {
            final cost = int.tryParse((p['cost'] ?? 0).toString()) ?? 0;
            final units = int.tryParse((p['value'] ?? 0).toString()) ?? 0;
            final code = (p['id'] ?? '').toString();
            if (cost > 0 && units > 0 && code.isNotEmpty) {
              list.add(RedeemPackage(cost: cost, units: units, code: code));
            }
          }
        }
      }
      if (list.isEmpty) return _fallbackPackages();
      list.sort((a, b) => a.cost.compareTo(b.cost));
      return list;
    } catch (_) {
      return _fallbackPackages();
    }
  }

  static List<RedeemPackage> _fallbackPackages() => [
        RedeemPackage(cost: 100, units: 50, code: 'EAND_50_UNITS_ID_9'),
        RedeemPackage(cost: 200, units: 100, code: 'EAND_100_UNITS_ID_10'),
        RedeemPackage(cost: 300, units: 150, code: 'EAND_150_UNITS_ID_11'),
        RedeemPackage(cost: 600, units: 300, code: 'EAND_300_UNITS_ID_12'),
        RedeemPackage(cost: 1000, units: 500, code: 'EAND_500_UNITS_ID_13'),
        RedeemPackage(cost: 2000, units: 1000, code: 'EAND_1000_UNITS_ID_15'),
      ];

  static Future<bool> redeem(Map<String, String> headers, String code) async {
    try {
      final res = await http.post(
        Uri.parse('${AppConstants.apiBase}/music/loyalty/redeem/$code'),
        headers: headers,
      ).timeout(const Duration(seconds: 12));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
