import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// -------------------- MODELS --------------------

class JourneyStop {
  final int id;
  final double lat;
  final double lon;
  final String name;
  final String code;

  JourneyStop({
    required this.id,
    required this.lat,
    required this.lon,
    required this.name,
    required this.code,
  });

  factory JourneyStop.fromJson(Map<String, dynamic> json) {
    return JourneyStop(
      id: json['id'] is num ? (json['id'] as num).toInt() : -1,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }
}

class JourneyLeg {
  final String route;
  final List<String> routes;
  final String type;
  final String shortName;
  final String longName;
  final String agency;
  final String vehicleId;
  final String occupancy;
  final String departureTime;
  final String endingTime;
  final String color;
  final String description;
  final int tripTime;
  final double fare;
  final List<JourneyStop> stops;
  final String polyline;
  final double frequency;
  final double distance;

  JourneyLeg({
    required this.route,
    required this.routes,
    required this.type,
    required this.shortName,
    required this.longName,
    required this.agency,
    required this.vehicleId,
    required this.occupancy,
    required this.departureTime,
    required this.endingTime,
    required this.color,
    required this.description,
    required this.tripTime,
    required this.fare,
    required this.stops,
    required this.polyline,
    required this.frequency,
    required this.distance,
  });

  factory JourneyLeg.fromJson(Map<String, dynamic> json) {
    final List<dynamic> routesList = json['routes'] ?? [];
    final List<dynamic> stopsList = json['stops'] ?? [];
    return JourneyLeg(
      route: json['route']?.toString() ?? '',
      routes: routesList.map((e) => e.toString()).toList(),
      type: json['type']?.toString() ?? 'walk',
      shortName: json['short_name']?.toString() ?? '',
      longName: json['long_name']?.toString() ?? '',
      agency: json['agency']?.toString() ?? '',
      vehicleId: json['vehicle_id']?.toString() ?? '',
      occupancy: json['occupancy']?.toString() ?? '',
      departureTime: json['departure_time']?.toString() ?? '',
      endingTime: json['ending_time']?.toString() ?? '',
      color: json['color']?.toString() ?? '#F8CA35',
      description: json['description']?.toString() ?? '',
      tripTime: json['trip_time'] is num ? (json['trip_time'] as num).toInt() : 0,
      fare: (json['fare'] as num?)?.toDouble() ?? 0.0,
      stops: stopsList.map((e) => JourneyStop.fromJson(e)).toList(),
      polyline: json['polyline']?.toString() ?? '',
      frequency: (json['frequency'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class JourneyRoute {
  final String fareUnit;
  final double tripTime;
  final double totalFare;
  final String responseType;
  final String reachBy;
  final String timeUnit;
  final String requestTime;
  final String createdAt;
  final String routeDescription;
  final String totalFareRange;
  final List<JourneyLeg> legs;

  JourneyRoute({
    required this.fareUnit,
    required this.tripTime,
    required this.totalFare,
    required this.responseType,
    required this.reachBy,
    required this.timeUnit,
    required this.requestTime,
    required this.createdAt,
    required this.routeDescription,
    required this.totalFareRange,
    required this.legs,
  });

  factory JourneyRoute.fromJson(Map<String, dynamic> json) {
    List<JourneyLeg> parsedLegs = [];
    if (json['directions'] != null && json['directions']['routes'] != null) {
      final List<dynamic> routesList = json['directions']['routes'];
      parsedLegs = routesList.map((e) => JourneyLeg.fromJson(e)).toList();
    }
    return JourneyRoute(
      fareUnit: json['fare_unit']?.toString() ?? '₹',
      tripTime: (json['trip_time'] as num?)?.toDouble() ?? 0.0,
      totalFare: (json['total_fare'] as num?)?.toDouble() ?? 0.0,
      responseType: json['response_type']?.toString() ?? 'static',
      reachBy: json['reach_by']?.toString() ?? '',
      timeUnit: json['time_unit']?.toString() ?? 'min',
      requestTime: json['request_time']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      routeDescription: json['route_description']?.toString() ?? '',
      totalFareRange: json['total_fare_range']?.toString() ?? '',
      legs: parsedLegs,
    );
  }
}

// -------------------- SERVICE CLASS --------------------

class JourneyPlannerService {
  static const String _baseUrl = 'https://dts-backend.transportstack.in';
  static const String _apiKey = 'hsrNV2fU3I9O774q02X1BgGOf8T3f7vlbzdFjXSRB6Y=';

  /// Fetch multi-modal journey recommendations.
  /// Strictly construct URL query parameters by manual string building to keep
  /// raw brackets %5B and %5D as required by the Delhi Transport Stack backend.
  static Future<List<JourneyRoute>> planJourney({
    required double srcLat,
    required double srcLon,
    required String srcType,
    required double dstLat,
    required double dstLon,
    required String dstType,
    required String mode,
    required String time,
  }) async {
    final srcEncoded = '%5B$srcLat,$srcLon%5D';
    final dstEncoded = '%5B$dstLat,$dstLon%5D';
    final srcTypeEncoded = Uri.encodeComponent(srcType);
    final dstTypeEncoded = Uri.encodeComponent(dstType);
    final modeEncoded = Uri.encodeComponent(mode);
    final timeEncoded = Uri.encodeComponent(time);

    final requestUrl = '$_baseUrl/api/serviceset/journey-planner/multi_modal'
        '?src=$srcEncoded'
        '&src_type=$srcTypeEncoded'
        '&dst=$dstEncoded'
        '&dst_type=$dstTypeEncoded'
        '&mode=$modeEncoded'
        '&time=$timeEncoded';

    debugPrint('Journey Planner API request: $requestUrl');


    try {
      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'x-api-key': _apiKey,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['message'] == 'Success') {
          final List<dynamic> dataList = decoded['data'] ?? [];
          return dataList.map((item) => JourneyRoute.fromJson(item)).toList();
        } else {
          final errorMsg = decoded is Map<String, dynamic> 
              ? (decoded['description'] ?? decoded['message'] ?? 'Failed to plan route') 
              : 'Invalid response format';
          throw Exception(errorMsg);
        }
      } else if (response.statusCode == 504) {
        throw Exception('Server Gateway Timeout (504). The route calculation took too long. Try selecting "Multi-modal" or different stops.');
      } else {
        throw Exception('Server returned status code: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Connection timed out. The server is taking too long to respond. Please try again or select "Multi-modal" mode.');
    } on SocketException {
      throw Exception('Network error. Please check your internet connection.');
    } catch (e) {
      if (e.toString().contains('504')) {
        throw Exception('Server Gateway Timeout. The route calculation took too long. Try selecting "Multi-modal" or different stops.');
      }
      rethrow;
    }
  }

  /// Retrieve stops for a particular transportation mode.
  static Future<List<dynamic>> getStops({
    required String mode,
  }) async {
    final modeEncoded = Uri.encodeComponent(mode);
    final requestUrl = '$_baseUrl/api/serviceset/journey-planner/get_stops?mode=$modeEncoded';

    try {
      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'x-api-key': _apiKey,
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          return decoded['data'] as List<dynamic>;
        }
        return [];
      } else {
        throw Exception('Failed to get stops: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Connection timed out while fetching transit stops. Please try again.');
    } on SocketException {
      throw Exception('Network error. Please check your internet connection.');
    }
  }
}
