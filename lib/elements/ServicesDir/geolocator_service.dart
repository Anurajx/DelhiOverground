import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:metroapp/elements/ServicesDir/data_provider.dart';

/// Call this from a widget’s `initState` using
/// WidgetsBinding.instance.addPostFrameCallback((_) => initialize(context));
Future<void> initialize(BuildContext context) async {
  //THIS IS STILL THE FUNCTION THAT WAS MADE FOR LIST AND HAS NOT BEEN UPDATED FOR MAP FOR NOW
  try {
    // 1️⃣ Get user location once
    final Position userPosition = await getCurrentLocation();
    final double userLat = userPosition.latitude;
    final double userLon = userPosition.longitude;

    // 2️⃣ Load station JSON
    List<dynamic> originalStations = await loadStationsFromJson();

    // (Optional) skip CSV header row
    // if (originalStations.isNotEmpty &&
    //     originalStations.first[0].toString().toLowerCase().contains(
    //       'station',
    //     )) {
    //   originalStations = originalStations.skip(1).toList();
    // }

    if (originalStations.length < 2) {
      print('⚠️ CSV has less than 2 stations; aborting update');
      return;
    }

    // 3️⃣ Sort by distance
    originalStations.sort((a, b) {
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

    final nearest = originalStations[0];
    final nextNearest = originalStations[1];

    // 4️⃣ Push into Provider
    if (context.mounted) {
      context.read<DataProvider>().updateCoreNearestStationsDict({
        'UserLocation': [userPosition],
        'Near': [nearest],
        'NearEnough': [nextNearest],
      });
    }

    print('🚀 Provider updated with nearest stations');
  } catch (e, st) {
    print('⚠️ initialize() failed: $e\n$st');
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

Future<List> loadStationsFromJson() async {
  try {
    final jsonRawData = await rootBundle.loadString(
      "assets/Map/stationsjson.json",
    );
    final List<dynamic> jsonList = jsonDecode(jsonRawData);
    return jsonList;
  } catch (e) {
    return [];
  }
}
