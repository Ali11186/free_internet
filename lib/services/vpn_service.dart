import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class VpnService {
  static final Connectivity _connectivity = Connectivity();

  // ============================================================
  // الطبقة 1: فحص VPN محلي (نظام أندرويد)
  // ============================================================
  static Future<bool> isVpnActive() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return results.contains(ConnectivityResult.vpn);
    } catch (_) {
      return false;
    }
  }

  static Stream<bool> watchVpn() {
    return _connectivity.onConnectivityChanged
        .map((r) => r.contains(ConnectivityResult.vpn))
        .distinct();
  }

  // ============================================================
  // الطبقة 2: فحص شبكة الجهاز (interfaces) — يكشف tun/tap/ppp
  // ============================================================
  static Future<bool> hasVpnInterface() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        includeLinkLocal: false,
      );
      for (final i in interfaces) {
        final name = i.name.toLowerCase();
        if (name.contains('tun') ||
            name.contains('tap') ||
            name.contains('ppp') ||
            name.contains('wg') ||
            name.contains('utun') ||
            name.contains('ipsec') ||
            name.contains('vpn')) {
          return true;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // قائمة الكلمات المفتاحية للـ VPN والاستضافة
  // ============================================================
  static const List<String> _vpnKeywords = [
    // VPN services
    'vpn', 'nordvpn', 'nord', 'expressvpn', 'express', 'surfshark',
    'cyberghost', 'private internet', 'pia', 'protonvpn', 'proton',
    'mullvad', 'tunnelbear', 'hotspot shield', 'hidemyass', 'hide.me',
    'windscribe', 'ipvanish', 'purevpn', 'astrill', 'strongvpn',
    'perfect privacy', 'ivacy', 'kaspersky', 'bitdefender vpn',
    'privatevpn', 'torguard', 'safervpn', 'vyprvpn', 'zenmate',
    'cloak', 'shadowsocks', 'wireguard', 'openvpn', 'hoxx',
    'privado', 'betternet', 'touchvpn', 'thunder vpn', 'turbo vpn',
    'hola vpn', 'speedify', 'ivpn', 'azirevpn',
    // Cloud/Hosting/Datacenters
    'digitalocean', 'amazon', 'aws', 'google cloud', 'gcp',
    'microsoft azure', 'azure', 'linode', 'akamai', 'vultr',
    'hetzner', 'ovh', 'contabo', 'hostinger', 'leaseweb',
    'colocrossing', 'colocross', 'm247', 'datacamp', 'choopa',
    'hostwinds', 'ionos', 'godaddy', 'namecheap', 'hostgator',
    'bluehost', 'dreamhost', 'liquidweb', 'kamatera', 'scaleway',
    'oracle cloud', 'alibaba', 'tencent', 'cloudflare', 'fastly',
    'stackpath', 'ibm cloud', 'rackspace', 'equinix', 'gcore',
    'quadranet', 'psychz', 'frantech', 'buyvm', 'racknerd',
    'servarica', 'dmit', 'bandwagonhost', 'nexus',
    'virtono', 'hosthatch', 'greencloud', 'inleed', 'aeza',
    'cloudie', 'gsl', 'xvmlabs', 'hostens', 'nforce', 'worldstream',
    'serverius', 'neterra', 'zenlayer', 'softlayer',
    'logicweb', 'fdcservers', 'sharktech', 'reliablesite',
    'internap', 'ubiquity', 'phoenixnap', 'singlehop',
    // Proxy / anonymizers
    'proxy', 'anonymiz', 'tor exit', 'tor relay', 'tor node',
    'private layer',
  ];

  static const List<String> _hostingAsnKeywords = [
    'as14061', 'as16509', 'as15169', 'as8075', 'as24940',
    'as63949', 'as20473', 'as9009', 'as12876', 'as16276',
    'as51167', 'as197540', 'as60781', 'as20773', 'as49981',
    'as30633', 'as29802', 'as46844', 'as32475', 'as36352',
  ];

  // ============================================================
  // الطبقة 3: فحص 3 APIs خارجية (كلها HTTPS)
  // ============================================================
  static Future<bool> checkIpReputation() async {
    try {
      final results = await Future.wait([
        _checkIpWho(),
        _checkIpApiCo(),
        _checkIpInfo(),
      ]).timeout(
        const Duration(seconds: 8),
        onTimeout: () => <bool>[false, false, false],
      );

      return results.any((r) => r);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkIpWho() async {
    try {
      final res = await http.get(
        Uri.parse('https://ipwho.is/'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return false;
      final d = jsonDecode(res.body);
      if (d['success'] != true) return false;
      final conn = d['connection'];
      if (conn is! Map) return false;
      final c =
          '${conn['org']} ${conn['isp']} ${conn['domain']}'.toLowerCase();
      return _matchesKeywords(c);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkIpApiCo() async {
    try {
      final res = await http.get(
        Uri.parse('https://ipapi.co/json/'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return false;
      final d = jsonDecode(res.body);
      final c = '${d['org']} ${d['asn']}'.toLowerCase();
      return _matchesKeywords(c);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _checkIpInfo() async {
    try {
      final res = await http.get(
        Uri.parse('https://ipinfo.io/json'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return false;
      final d = jsonDecode(res.body);
      final c = '${d['org']} ${d['hostname']}'.toLowerCase();
      return _matchesKeywords(c);
    } catch (_) {
      return false;
    }
  }

  static bool _matchesKeywords(String combined) {
    for (final k in _vpnKeywords) {
      if (combined.contains(k)) return true;
    }
    for (final a in _hostingAsnKeywords) {
      if (combined.contains(a)) return true;
    }
    return false;
  }

  // ============================================================
  // الفحص الشامل
  // ============================================================
  static Future<bool> shouldBlock() async {
    if (await isVpnActive()) return true;
    if (await hasVpnInterface()) return true;
    if (await checkIpReputation()) return true;
    return false;
  }
}
