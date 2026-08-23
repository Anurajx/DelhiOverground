import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:metroapp/elements/ServicesDir/analytics_service.dart';

/// Live Bus Tracking Map Screen
///
/// Embeds the sleek, minimalist Delhi Live Transit web map directly
/// inside the Flutter application using `webview_flutter`.
class LiveBusMapScreen extends StatefulWidget {
  final String? customBackendUrl;
  final double? initialLat;
  final double? initialLng;

  const LiveBusMapScreen({
    super.key,
    this.customBackendUrl,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<LiveBusMapScreen> createState() => _LiveBusMapScreenState();
}

class _LiveBusMapScreenState extends State<LiveBusMapScreen> {
  late final WebViewController _controller;
  Position? _currentPosition;
  double _loadingProgress = 0.0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreenViewed('Live Bus Map In-App');
    _initWebViewController();
    _fetchLocationAndPushToWebview();
  }

  String _getEffectiveBackendUrl() {
    if (widget.customBackendUrl != null && widget.customBackendUrl!.isNotEmpty) {
      return widget.customBackendUrl!;
    }
    // Android emulator connects to host localhost via 10.0.2.2
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    }
    // iOS simulator, macOS, desktop, web
    return 'http://localhost:5000';
  }

  void _initWebViewController() {
    final backendUrl = _getEffectiveBackendUrl();
    final wsUrl = backendUrl.replaceFirst(RegExp(r'^http'), 'ws');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF8FAFC))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100.0;
              });
            }
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            // Configure API and WebSocket URLs inside JavaScript context
            _controller.runJavaScript('''
              window.FLUTTER_API_BASE = "$backendUrl";
              window.FLUTTER_WS_URL = "$wsUrl/realtime";
            ''');

            // Inject location if already resolved
            if (_currentPosition != null) {
              _pushLocationToMap(_currentPosition!.latitude, _currentPosition!.longitude);
            }
          },
          onWebResourceError: (WebResourceError error) {
            // Ignore minor resource errors (e.g. subresource 404)
            if (error.isForMainFrame == true) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = 'Failed to load map (${error.description})';
                });
              }
            }
          },
        ),
      );

    _loadMapContent();
  }

  Future<void> _loadMapContent() async {
    try {
      // First try loading local asset for instant zero-latency UI rendering
      await _controller.loadFlutterAsset('assets/index.html');
    } catch (_) {
      // Fallback to loading directly from backend server
      final backendUrl = _getEffectiveBackendUrl();
      final lat = widget.initialLat ?? 28.6139;
      final lng = widget.initialLng ?? 77.2090;
      await _controller.loadRequest(Uri.parse('$backendUrl/?lat=$lat&lng=$lng'));
    }
  }

  Future<void> _fetchLocationAndPushToWebview() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (mounted) {
        setState(() {
          _currentPosition = pos;
        });
        _pushLocationToMap(pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint('Location error in LiveBusMapScreen: $e');
    }
  }

  void _pushLocationToMap(double lat, double lng) {
    _controller.runJavaScript('''
      if (typeof window.updateUserLocation === 'function') {
        window.updateUserLocation($lat, $lng);
      }
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              margin: EdgeInsets.only(right: 6.w),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
            ),
            Text(
              'Live Buses (1 km)',
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.location_fill, color: Color(0xFF0284C7), size: 20),
            tooltip: 'My Location',
            onPressed: () {
              _fetchLocationAndPushToWebview();
              if (_currentPosition != null) {
                _pushLocationToMap(_currentPosition!.latitude, _currentPosition!.longitude);
              }
            },
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.refresh, color: Color(0xFF0F172A), size: 20),
            tooltip: 'Reload Map',
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
        bottom: _isLoading
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2.0),
                child: LinearProgressIndicator(
                  value: _loadingProgress > 0 ? _loadingProgress : null,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0284C7)),
                  minHeight: 2.0,
                ),
              )
            : null,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_errorMessage != null)
            Positioned(
              bottom: 24.h,
              left: 20.w,
              right: 20.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A0F172A),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.exclamationmark_triangle, color: Color(0xFFEF4444), size: 20),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 12.sp, color: const Color(0xFF334155)),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _errorMessage = null;
                        });
                        _loadMapContent();
                      },
                      child: Text(
                        'Retry',
                        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: const Color(0xFF0284C7)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
