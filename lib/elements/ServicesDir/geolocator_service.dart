import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:metroapp/elements/ServicesDir/data_provider.dart';
import 'package:metroapp/elements/ServicesDir/stops_manager.dart';

/// Call this from a widget’s `initState` using
/// WidgetsBinding.instance.addPostFrameCallback((_) => initialize(context));
Future<void> initialize(BuildContext context) async {
  try {
    // 1️⃣ Get user location once
    final Position userPosition = await getCurrentLocation();
    final double userLat = userPosition.latitude;
    final double userLon = userPosition.longitude;

    // 2️⃣ Load stations from dynamic StopsManager
    final List<dynamic> targetStations = List.from(StopsManager.getStations());

    if (targetStations.length < 2) {
      print('⚠️ Target stations list has less than 2 stations; aborting update');
      return;
    }

    // 3️⃣ Sort by distance
    targetStations.sort((a, b) {
      final distA = Geolocator.distanceBetween(
        userLat,
        userLon,
        double.parse(a["Latitude"].toString()),
        double.parse(a["Longitude"].toString()),
      );
      final distB = Geolocator.distanceBetween(
        userLat,
        userLon,
        double.parse(b["Latitude"].toString()),
        double.parse(b["Longitude"].toString()),
      );
      return distA.compareTo(distB);
    });

    final nearest = targetStations[0];
    final nextNearest = targetStations[1];

    // 4️⃣ Push into Provider
    if (context.mounted) {
      context.read<DataProvider>().updateCoreNearestStationsDict({
        'UserLocation': [userPosition],
        'Near': [nearest],
        'NearEnough': [nextNearest],
      });
      context.read<DataProvider>().setLocationEnabled(true);
    }

    print('🚀 Provider updated with nearest stations');
  } catch (e, st) {
    print('⚠️ initialize() failed: $e\n$st');
    if (context.mounted) {
      context.read<DataProvider>().setLocationEnabled(false);
    }
  }
}

/// ----- helpers -----------------------------------------------------------

Future<Position> getCurrentLocation() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception('Location services disabled.');
    //throw Exception('Location services disabled.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    throw Exception('Location permission denied.');
  }

  return Geolocator.getCurrentPosition();
}


