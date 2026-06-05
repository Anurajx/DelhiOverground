import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:metroapp/main.dart';
import 'package:metroapp/elements/ServicesDir/geolocator_service.dart';

class LiveBusMarker {
  final String vehicleId;
  final String routeId;
  final String routeLongName;
  LatLng currentLatLng;
  LatLng targetLatLng;
  int distanceMeters;

  LiveBusMarker({
    required this.vehicleId,
    required this.routeId,
    required this.routeLongName,
    required this.currentLatLng,
    required this.targetLatLng,
    required this.distanceMeters,
  });
}

class MapMetroScreen extends StatefulWidget {
  const MapMetroScreen({super.key});

  @override
  State<MapMetroScreen> createState() => _MapMetroScreenState();
}

class _MapMetroScreenState extends State<MapMetroScreen> {
  LatLng _center = const LatLng(28.6139, 77.2090); // default Delhi
  bool _isLoadingLocation = true;
  String? _mapStyle;

  final Map<String, LiveBusMarker> _activeBuses = {};
  final ValueNotifier<Set<Marker>> _markersNotifier = ValueNotifier({});
  bool _isMapInteracting = false;
  BitmapDescriptor? _busIcon;
  int _currentZoomBucket = 2; // 0 = collapsed (zoom < 13.5), 1 = compact (13.5 <= zoom < 15.5), 2 = detailed (zoom >= 15.5)

  Timer? _fetchTimer;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _determinePosition();
  }

  @override
  void dispose() {
    _fetchTimer?.cancel();
    _animationTimer?.cancel();
    _markersNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await rootBundle.loadString('assets/Map/map_style.json');
      if (mounted) {
        setState(() {
          _mapStyle = style;
        });
      }
    } catch (e) {
      debugPrint("Error loading map style: $e");
    }
  }

  String _getBackendUrl() {
    if (kDebugMode) {
      return 'http://localhost:3000';
    } else {
      return 'https://delhioverground.onrender.com';
    }
  }



  int _getZoomBucket(double zoom) {
    if (zoom < 13.5) return 0;
    if (zoom < 15.5) return 1;
    return 2;
  }

  void _handleZoomChange(double zoom) {
    final int newBucket = _getZoomBucket(zoom);
    if (newBucket != _currentZoomBucket) {
      if (mounted) {
        setState(() {
          _currentZoomBucket = newBucket;
        });
        _updateMarkers();
      }
    }
  }

  Future<void> _determinePosition() async {
    try {
      final position = await getCurrentLocation();
      if (mounted) {
        setState(() {
          _center = LatLng(position.latitude, position.longitude);
          _isLoadingLocation = false;
        });
        _startLiveTracking();
      }
    } catch (e) {
      debugPrint("Could not determine user location: $e");
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
        });
        _startLiveTracking();
      }
    }
  }

  void _startLiveTracking() {
    // Poll the backend server for nearby buses every 10 seconds
    _fetchTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _fetchNearbyBuses();
    });
    _fetchNearbyBuses(); // Initial fetch immediately

    // Smooth animation loop running at 20 FPS (every 50ms)
    _startAnimationLoop();
  }



  Future<void> _fetchNearbyBuses() async {
    try {
      final url = '${_getBackendUrl()}/nearby?lat=${_center.latitude}&lng=${_center.longitude}&radius=1000';
      debugPrint("Live PIS request: $url");
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> busesJson = data['buses'] ?? [];
        debugPrint("Live PIS response: Loaded ${busesJson.length} buses.");
        final Set<String> updatedVehicleIds = {};

        for (final busJson in busesJson) {
          final String vehicleId = busJson['vehicleId'] ?? 'unknown';
          final String routeId = busJson['routeId']?.toString() ?? 'unknown';
          final double lat = (busJson['lat'] as num?)?.toDouble() ?? 0.0;
          final double lng = (busJson['lng'] as num?)?.toDouble() ?? 0.0;
          final int distanceMeters = (busJson['distanceMeters'] as num?)?.toInt() ?? 0;

          if (lat == 0.0 || lng == 0.0 || vehicleId == 'unknown') continue;

          updatedVehicleIds.add(vehicleId);
          final newLatLng = LatLng(lat, lng);

          if (_activeBuses.containsKey(vehicleId)) {
            final activeBus = _activeBuses[vehicleId]!;
            activeBus.targetLatLng = newLatLng;
            activeBus.distanceMeters = distanceMeters;
          } else {
            _activeBuses[vehicleId] = LiveBusMarker(
              vehicleId: vehicleId,
              routeId: routeId,
              routeLongName: routeId,
              currentLatLng: newLatLng,
              targetLatLng: newLatLng,
              distanceMeters: distanceMeters,
            );
          }
        }

        // Clean up inactive buses
        _activeBuses.removeWhere((key, value) => !updatedVehicleIds.contains(key));
        _updateMarkers();
      }
    } catch (e) {
      debugPrint("Error fetching nearby buses: $e");
    }
  }

  void _startAnimationLoop() {
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      bool updated = false;
      const double step = 0.15; // Interpolation speed per frame

      _activeBuses.forEach((vehicleId, bus) {
        if (bus.currentLatLng != bus.targetLatLng) {
          final latDiff = bus.targetLatLng.latitude - bus.currentLatLng.latitude;
          final lngDiff = bus.targetLatLng.longitude - bus.currentLatLng.longitude;

          if (latDiff.abs() < 0.00001 && lngDiff.abs() < 0.00001) {
            bus.currentLatLng = bus.targetLatLng;
          } else {
            bus.currentLatLng = LatLng(
              bus.currentLatLng.latitude + latDiff * step,
              bus.currentLatLng.longitude + lngDiff * step,
            );
          }
          updated = true;
        }
      });

      if (updated && !_isMapInteracting && mounted) {
        _updateMarkers();
      }
    });
  }

  Future<void> _loadBusIcon(BuildContext context) async {
    if (_busIcon != null) return;
    try {
      final icon = await BitmapDescriptor.asset(
        createLocalImageConfiguration(context, size: const Size(36, 36)),
        'assets/Image/bus.png',
      );
      if (mounted) {
        setState(() {
          _busIcon = icon;
        });
        _updateMarkers();
      }
    } catch (e) {
      debugPrint("Error loading bus icon asset: $e");
    }
  }

  void _updateMarkers() {
    final List<Marker> newMarkers = [];

    final BitmapDescriptor icon = _busIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

    for (final entry in _activeBuses.entries) {
      final bus = entry.value;

      newMarkers.add(
        Marker(
          markerId: MarkerId(bus.vehicleId),
          position: bus.currentLatLng,
          icon: icon,
          infoWindow: InfoWindow(
            title: "Route ${bus.routeLongName}",
            snippet: "Bus ID: ${bus.vehicleId} • ${bus.distanceMeters}m away",
          ),
        ),
      );
    }

    _markersNotifier.value = newMarkers.toSet();
  }

  @override
  Widget build(BuildContext context) {
    _loadBusIcon(context);
    if (_isLoadingLocation) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CupertinoActivityIndicator(radius: 20, color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: ValueListenableBuilder<Set<Marker>>(
                valueListenable: _markersNotifier,
                builder: (context, markers, child) {
                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: 16.0,
                    ),
                    onMapCreated: (controller) {},
                    onCameraMoveStarted: () {
                      _isMapInteracting = true;
                    },
                    onCameraIdle: () {
                      _isMapInteracting = false;
                      _updateMarkers();
                    },
                    onCameraMove: (position) {
                      _handleZoomChange(position.zoom);
                    },
                    style: _mapStyle,
                    markers: markers,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                  );
                },
              ),
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const ui.Color(0xD8000000), // Black background with slight opacity
                  borderRadius: BorderRadius.zero, // Zero corner radius
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981), // Match modern live green
                        shape: BoxShape.rectangle, // Matching square dot
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Live Buses: ${_activeBuses.length}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.back,
                  color: AppColors.primaryAccent,
                  size: 20.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  "Back",
                  style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          ),
          Text(
            "Delhi Metro Map",
            style: TextStyle(
              color: AppColors.primaryText,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(width: 40.w), // Placeholder to balance back button width
        ],
      ),
    );
  }
}
