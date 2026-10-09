import 'dart:async';
import 'package:flutter/material.dart';
import '../screens/vpn_block_screen.dart';
import '../services/vpn_service.dart';

class VpnGuard extends StatefulWidget {
  final Widget child;
  const VpnGuard({super.key, required this.child});

  @override
  State<VpnGuard> createState() => _VpnGuardState();
}

class _VpnGuardState extends State<VpnGuard> with WidgetsBindingObserver {
  bool _blocked = false;
  bool _initialized = false;
  StreamSubscription<bool>? _sub;
  Timer? _periodic;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    final blocked = await VpnService.shouldBlock();
    if (!mounted) return;
    setState(() {
      _blocked = blocked;
      _initialized = true;
    });

    // مراقبة VPN محلي
    _sub = VpnService.watchVpn().listen((isVpn) async {
      if (!mounted) return;
      if (isVpn && !_blocked) {
        setState(() => _blocked = true);
      } else if (!isVpn && _blocked) {
        final still = await VpnService.shouldBlock();
        if (mounted && !still) setState(() => _blocked = false);
      }
    });

    // ⚡ فحص كل 5 ثواني (كان 30 — بقى أقوى)
    _periodic = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      final blocked = await VpnService.shouldBlock();
      if (mounted && blocked != _blocked) {
        setState(() => _blocked = blocked);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // لو المستخدم رجع للتطبيق من الخلفية — نفحص فوراً
    if (state == AppLifecycleState.resumed) {
      _quickRecheck();
    }
  }

  Future<void> _quickRecheck() async {
    final blocked = await VpnService.shouldBlock();
    if (mounted && blocked != _blocked) {
      setState(() => _blocked = blocked);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    _periodic?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0612),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF1493)),
        ),
      );
    }
    if (_blocked) return const VpnBlockScreen();
    return widget.child;
  }
}
