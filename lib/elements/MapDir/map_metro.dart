import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:metroapp/main.dart';
import 'package:metroapp/elements/StationDir/stop_info.dart';

class MapMetroScreen extends StatefulWidget {
  const MapMetroScreen({super.key});

  @override
  State<MapMetroScreen> createState() => _MapMetroScreenState();
}

class _MapMetroScreenState extends State<MapMetroScreen> {
  GoogleMapController? _mapController;
  final LatLng _center = const LatLng(28.6139, 77.2090); // Delhi center
  Set<Marker> _markers = {};
  String? _mapStyle;
  Position? _currentPosition;

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    _loadStopMarkers();
    _determinePosition();
  }

  Future<void> _loadMapStyle() async {
    try {
      final style = await rootBundle.loadString('assets/Map/map_style.json');
      setState(() {
        _mapStyle = style;
      });
    } catch (e) {
      debugPrint("Error loading map style: $e");
    }
  }

  Future<void> _loadStopMarkers() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/Map/stationsjson.json');
      final List<dynamic> stops = jsonDecode(jsonStr);

      final Set<Marker> newMarkers = stops.map<Marker>((stop) {
        final double lat = double.parse(stop['Latitude']?.toString() ?? '0.0');
        final double lon = double.parse(stop['Longitude']?.toString() ?? '0.0');
        final String name = stop['Name'] ?? 'Stop';
        final String code = stop['StationCode'] ?? '';
        final String line = stop['Line'] ?? '';

        return Marker(
          markerId: MarkerId(code),
          position: LatLng(lat, lon),
          infoWindow: InfoWindow(
            title: name,
            snippet: "Routes: $line",
            onTap: () {
              Navigator.push(
                context,
                CupertinoPageRoute(
                  builder: (context) => StopInfoScreen(
                    stationDict: stop,
                  ),
                ),
              );
            },
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
      }).toSet();

      setState(() {
        _markers = newMarkers;
      });
    } catch (e) {
      debugPrint("Error loading stop markers: $e");
    }
  }

  Future<void> _determinePosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });

      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14.5,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error determining geolocation: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _center,
                zoom: 11.5,
              ),
              onMapCreated: (controller) {
                _mapController = controller;
                if (_mapStyle != null) {
                  _mapController!.setMapStyle(_mapStyle);
                }
                if (_currentPosition != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(
                      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                      14.5,
                    ),
                  );
                }
              },
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
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
      color: Colors.black.withOpacity(0.7),
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              children: [
                Icon(CupertinoIcons.back, color: AppColors.primaryAccent),
                SizedBox(width: 4.w),
                Text(
                  "Done",
                  style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Poppins',
                    fontSize: 18.sp,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            "DTC Bus Stops  ",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
