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

    // Load reconciled stops and build Set of mapped static stop IDs
    List<dynamic> reconciledJson = [];
    try {
      final reconciledStr = await rootBundle.loadString('assets/reconciled_stops.json');
      reconciledJson = jsonDecode(reconciledStr);
    } catch (e) {
      print('⚠️ Failed to load assets/reconciled_stops.json: $e');
    }

    final Set<String> mappedStopIds = {};
    for (final item in reconciledJson) {
      final staticId = item['static_stop_id']?.toString();
      final rtId = item['realtime_stop_id'];
      if (staticId != null && rtId != null) {
        mappedStopIds.add(staticId);
      }
    }

    // Filter stations that have at least one mapped static stop ID
    final List<dynamic> filteredStations = [];
    for (final station in originalStations) {
      final String code = station["StationCode"]?.toString() ?? "";
      final stopIds = code.split(',').map((id) => id.trim()).toList();
      bool hasRealtime = false;
      for (final stopId in stopIds) {
        if (mappedStopIds.contains(stopId)) {
          hasRealtime = true;
          break;
        }
      }
      if (hasRealtime) {
        filteredStations.add(station);
      }
    }

    final List<dynamic> targetStations = filteredStations.length >= 2 ? filteredStations : originalStations;

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
