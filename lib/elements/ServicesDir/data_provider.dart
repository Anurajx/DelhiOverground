import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DataProvider extends ChangeNotifier {
  Map<String, List<dynamic>> _coreNearestStationsDict = {};
  Map<String, List<dynamic>> get coreNearestStationsDict =>
      _coreNearestStationsDict;
  void updateCoreNearestStationsDict(Map<String, List<dynamic>> data) {
    _coreNearestStationsDict = data;
    notifyListeners();
  }

  bool? _isLocationEnabled;
  bool? get isLocationEnabled => _isLocationEnabled;

  void setLocationEnabled(bool? enabled) {
    _isLocationEnabled = enabled;
    notifyListeners();
  }



  List<Map<String, String>> _busSearchHistory = [];
  List<Map<String, String>> get busSearchHistory => _busSearchHistory;

  Future<void> loadBusSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('busSearchHistory');
    if (saved != null) {
      try {
        final List<dynamic> decoded = jsonDecode(saved);
        _busSearchHistory =
            decoded.map((e) => Map<String, String>.from(e as Map)).toList();
        notifyListeners();
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> addBusToHistory(
    String routeId,
    String routeLongName,
    String headsign,
  ) async {
    _busSearchHistory.removeWhere(
      (item) => item['route_long_name'] == routeLongName,
    );
    _busSearchHistory.insert(0, {
      'route_id': routeId,
      'route_long_name': routeLongName,
      'headsign': headsign,
    });
    if (_busSearchHistory.length > 5) {
      _busSearchHistory = _busSearchHistory.sublist(0, 5);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('busSearchHistory', jsonEncode(_busSearchHistory));
    notifyListeners();
  }

  Future<void> clearBusSearchHistory() async {
    _busSearchHistory = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('busSearchHistory');
    notifyListeners();
  }

  List<Map<String, String>> _journeySearchHistory = [];
  List<Map<String, String>> get journeySearchHistory => _journeySearchHistory;

  Future<void> loadJourneySearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('journeySearchHistory');
    if (saved != null) {
      try {
        final List<dynamic> decoded = jsonDecode(saved);
        _journeySearchHistory =
            decoded.map((e) => Map<String, String>.from(e as Map)).toList();
        notifyListeners();
      } catch (e) {
        // ignore
      }
    }
  }

  Future<void> addJourneyToHistory({
    required String srcName,
    required String srcLat,
    required String srcLon,
    required String srcType,
    required String dstName,
    required String dstLat,
    required String dstLon,
    required String dstType,
    required String mode,
    required String time,
    String? routesJson,
  }) async {
    _journeySearchHistory.removeWhere(
      (item) => item['src_name'] == srcName && item['dst_name'] == dstName && item['mode'] == mode,
    );
    final newItem = {
      'src_name': srcName,
      'src_lat': srcLat,
      'src_lon': srcLon,
      'src_type': srcType,
      'dst_name': dstName,
      'dst_lat': dstLat,
      'dst_lon': dstLon,
      'dst_type': dstType,
      'mode': mode,
      'time': time,
      if (routesJson != null) 'routes_json': routesJson,
    };
    _journeySearchHistory.insert(0, newItem);
    if (_journeySearchHistory.length > 5) {
      _journeySearchHistory = _journeySearchHistory.sublist(0, 5);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('journeySearchHistory', jsonEncode(_journeySearchHistory));
    notifyListeners();
  }

  Future<void> clearJourneySearchHistory() async {
    _journeySearchHistory = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('journeySearchHistory');
    notifyListeners();
  }
}

