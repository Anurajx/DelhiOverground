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
}
