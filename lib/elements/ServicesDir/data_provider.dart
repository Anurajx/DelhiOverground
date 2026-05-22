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

  //////////------------------------------------------------------
  Map<String, List<dynamic>> _coreTransferStationsDict = {};
  Map<String, List<dynamic>> get coreTransferStationsDict =>
      _coreTransferStationsDict;
  void updateJustData(Map<String, dynamic> newSearch) async {
    // Deep copy of previous 'just' if it exists
    //basically what this code does is that it takes the just value and takes it inside a variable prev
    //after that it check if prev is null or not and if it is not null then it takes the prev value and maps it into a list with help of deepcoyp fucntion that helps in making a deep copy ie the list
    //after which justnow is defined with the help of deep copy, where the newly inputed value is added as an argument
    //then _coreTransferStationsDict is updated with the help of justnow and justBefore
    //sharedpreference saves the data in memory for next launch
    //TODO: UPDATE THE DEEPCOPY FUNCTION RIGHT NOW IT CHECKS FOR INPUT TYPE TRY TO FIX THE TYPE
    final prev = _coreTransferStationsDict['just'];
    final justBefore =
        prev != null ? prev.map((e) => _deepCopyTransferData(e)).toList() : [];

    // Deep copy the new search to prevent reference issues
    final justNow = [_deepCopyTransferData(newSearch)];

    //TODO: apply an check if both are different only then to run

    if (jsonEncode(justNow) != jsonEncode(justBefore)) {
      print("$justNow and also $justBefore");
      _coreTransferStationsDict = {'just': justNow, 'justBefore': justBefore};
    } else {
      print("$justNow also and $justBefore");
    }
    await _saveTransferDictToPrefs(); //SAVES DATA TO MEMORY FOR RETRIVING WHEN APP RESTARTS
    notifyListeners();
  }

  Map<String, dynamic> _deepCopyTransferData(Map<String, dynamic> input) {
    final copy = <String, dynamic>{};

    input.forEach((key, value) {
      if (value is List) {
        copy[key] = List.from(value);
      } else if (value is Map) {
        copy[key] = Map<String, dynamic>.from(value);
      } else {
        copy[key] = value;
      }
    });

    return copy;
  }

  Future<void> _saveTransferDictToPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    // Convert to JSON
    final encoded = jsonEncode(_coreTransferStationsDict);
    await prefs.setString('coreTransferDict', encoded);
  }

  Future<void> loadTransferDictFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('coreTransferDict');

    if (saved != null) {
      final Map<String, dynamic> decoded = jsonDecode(saved);

      _coreTransferStationsDict = decoded.map(
        (k, v) => MapEntry(k, List<dynamic>.from(v)),
      );

      notifyListeners();
    }
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
