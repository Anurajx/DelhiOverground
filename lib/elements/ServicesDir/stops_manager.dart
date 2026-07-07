import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:metroapp/elements/ServicesDir/env_service.dart';
import 'package:metroapp/elements/ServicesDir/analytics_service.dart';

class StopsManager {
  static List<dynamic> _stations = [];
  static final Map<int, String> _stopNames = {};
  static Map<String, String> _idToDirection = {};
  static Map<String, List<int>> _nameToIds = {};

  static List<dynamic> getStations() => _stations;

  static String? getStopNameById(int id) {
    return _stopNames[id];
  }

  static String _cleanName(String name) {
    String val = name;
    // Decode HTML entities
    val = val.replaceAll('&amp;', '&');
    val = val.replaceAll('&#34;', '"');
    val = val.replaceAll('&quot;', '"');
    val = val.replaceAll('&#39;', "'");
    val = val.replaceAll('&apos;', "'");
    // Standardize spaces
    val = val.replaceAll(RegExp(r'\s+'), ' ').trim();
    return val;
  }

  static String getDirectionForId(int id, String stopName) {
    // 1. Try direct ID lookup
    final dir = _idToDirection[id.toString()];
    if (dir != null && dir.isNotEmpty) {
      return dir;
    }

    // 2. Fallback: look up other IDs with the same clean stop name
    final cleanedName = _cleanName(stopName);
    final groupIds = _nameToIds[cleanedName];
    if (groupIds != null) {
      for (final otherId in groupIds) {
        final otherDir = _idToDirection[otherId.toString()];
        if (otherDir != null && otherDir.isNotEmpty) {
          return otherDir;
        }
      }
    }

    // 3. Last resort fallback (avoid literal hardcoded placeholders)
    return 'To $cleanedName';
  }

  static Future<void> init() async {
    // 0. Load directions map
    try {
      final mapStr = await rootBundle.loadString('assets/stop_directions_map.json');
      final decoded = jsonDecode(mapStr) as Map<String, dynamic>;
      
      final rawDirs = decoded['directions'] as Map<String, dynamic>? ?? {};
      _idToDirection = rawDirs.map((key, value) => MapEntry(key, value.toString()));

      final rawNames = decoded['names'] as Map<String, dynamic>? ?? {};
      _nameToIds = rawNames.map((key, value) {
        final list = value as List<dynamic>? ?? [];
        return MapEntry(
          key,
          list.map((e) => int.parse(e.toString())).toList(),
        );
      });
    } catch (e) {
      debugPrint("Error loading stop directions map: $e");
    }

    // 1. Load cached or fallback data first
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final localFile = File('${docDir.path}/stops_data.json');
      
      String jsonStr;
      if (await localFile.exists()) {
        jsonStr = await localFile.readAsString();
      } else {
        jsonStr = await rootBundle.loadString('assets/stops_backup.json');
      }

      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic> && decoded['data'] != null) {
        _parseAndSetup(decoded['data'] as List<dynamic>);
      }
    } catch (e) {
      debugPrint("Error loading initial stops data: $e");
    }

    // 2. Trigger automatic background refresh check
    unawaited(_autoRefreshCheck());
  }

  static void _parseAndSetup(List<dynamic> rawStops) {
    _stopNames.clear();
    
    // Group raw stops by cleaned name
    final Map<String, List<dynamic>> groupedRawStops = {};
    for (final stop in rawStops) {
      final id = stop['id'];
      final name = stop['name']?.toString() ?? '';
      final cleanedName = _cleanName(name);
      
      int? parsedId;
      if (id is int) {
        parsedId = id;
      } else if (id != null) {
        parsedId = int.tryParse(id.toString());
      }
      
      if (parsedId != null) {
        _stopNames[parsedId] = cleanedName;
      }

      if (!groupedRawStops.containsKey(cleanedName)) {
        groupedRawStops[cleanedName] = [];
      }
      groupedRawStops[cleanedName]!.add(stop);
    }

    final List<dynamic> tempStations = [];

    // For each unique name, create a station entry merging all its directions
    groupedRawStops.forEach((cleanedName, list) {
      final List<String> stopIds = [];
      
      // Add IDs from API stops matching this name
      for (final stop in list) {
        final idStr = stop['id']?.toString();
        if (idStr != null && idStr.isNotEmpty && !stopIds.contains(idStr)) {
          stopIds.add(idStr);
        }
      }

      // Merge IDs from the pre-parsed stop_directions_map for this name (if available)
      final dirs = _nameToIds[cleanedName];
      if (dirs != null) {
        for (final id in dirs) {
          final idStr = id.toString();
          if (!stopIds.contains(idStr)) {
            stopIds.add(idStr);
          }
        }
      }

      final stationCode = stopIds.join(',');

      // Use the coordinates of the first stop in the list
      final double lat = (list.first['lat'] as num?)?.toDouble() ?? 0.0;
      final double lng = (list.first['lng'] as num?)?.toDouble() ?? 0.0;

      tempStations.add({
        "StationCode": stationCode,
        "Name": cleanedName,
        "Hindi": cleanedName,
        "Line": "",
        "Latitude": lat.toString(),
        "Longitude": lng.toString(),
      });
    });

    // Back-populate _stopNames for all merged IDs from _nameToIds
    _nameToIds.forEach((name, ids) {
      for (final id in ids) {
        if (!_stopNames.containsKey(id)) {
          _stopNames[id] = name;
        }
      }
    });

    _stations = tempStations;
  }

  static Future<void> _autoRefreshCheck() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetch = prefs.getInt('last_stops_fetch_timestamp') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      // 14 days in milliseconds
      const refreshThreshold = 14 * 24 * 60 * 60 * 1000;
      
      if (now - lastFetch > 1000 * 60 * 60 * 24 * 7) {
        debugPrint("[StopsManager] Cache expired. Auto refreshing stops from API...");
        final requestUrl = 'https://dts-backend.transportstack.in/api/serviceset/journey-planner/get_stops?mode=bus';
        try {
          final response = await http.get(
            Uri.parse(requestUrl),
            headers: {
              'x-api-key': Env.get('DTS_API_KEY', defaultValue: 'hsrNV2fU3I9O774q02X1BgGOf8T3f7vlbzdFjXSRB6Y='),
            },
          ).timeout(const Duration(seconds: 45));

          if (response.statusCode == 200) {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic> && decoded['data'] != null) {
              final docDir = await getApplicationDocumentsDirectory();
              final localFile = File('${docDir.path}/stops_data.json');
              await localFile.writeAsString(response.body);
              await prefs.setInt('last_stops_fetch_timestamp', now);
              
              _parseAndSetup(decoded['data'] as List<dynamic>);
              debugPrint("[StopsManager] Successfully updated stops cache. Total stops: ${_stopNames.length}");
            } else {
              PostHogService.trackApiError(requestUrl, 'Invalid response body format');
            }
          } else {
            PostHogService.trackApiError(requestUrl, 'Failed to fetch stops', response.statusCode);
            debugPrint("[StopsManager] Failed to fetch stops. HTTP status: ${response.statusCode}");
          }
        } catch (e) {
          PostHogService.trackApiError(requestUrl, e.toString());
          debugPrint("[StopsManager] Error during auto refresh http call: $e");
        }
      } else {
        debugPrint("[StopsManager] Cache is fresh (last updated ${(now - lastFetch) / (1000 * 60 * 60 * 24)} days ago).");
      }
    } catch (e) {
      debugPrint("[StopsManager] Error during auto refresh: $e");
    }
  }

  static Future<bool> forceRefresh() async {
    final requestUrl = 'https://dts-backend.transportstack.in/api/serviceset/journey-planner/get_stops?mode=bus';
    try {
      debugPrint("[StopsManager] Manually refreshing stops from API...");
      final response = await http.get(
        Uri.parse(requestUrl),
        headers: {
          'x-api-key': Env.get('DTS_API_KEY', defaultValue: 'hsrNV2fU3I9O774q02X1BgGOf8T3f7vlbzdFjXSRB6Y='),
        },
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['data'] != null) {
          final docDir = await getApplicationDocumentsDirectory();
          final localFile = File('${docDir.path}/stops_data.json');
          await localFile.writeAsString(response.body);
          
          final prefs = await SharedPreferences.getInstance();
          final now = DateTime.now().millisecondsSinceEpoch;
          await prefs.setInt('last_stops_fetch_timestamp', now);
          
          _parseAndSetup(decoded['data'] as List<dynamic>);
          debugPrint("[StopsManager] Manually updated stops cache. Total stops: ${_stopNames.length}");
          return true;
        } else {
          PostHogService.trackApiError(requestUrl, 'Invalid response body format');
        }
      } else {
        PostHogService.trackApiError(requestUrl, 'Manual refresh failed', response.statusCode);
      }
      return false;
    } catch (e) {
      PostHogService.trackApiError(requestUrl, e.toString());
      debugPrint("[StopsManager] Error during manual force refresh: $e");
      return false;
    }
  }

  static Future<String> getLastFetchTimeString() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetch = prefs.getInt('last_stops_fetch_timestamp');
      if (lastFetch == null || lastFetch == 0) {
        return "Never";
      }
      final date = DateTime.fromMillisecondsSinceEpoch(lastFetch);
      const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
      final monthStr = months[date.month - 1];
      final dayStr = date.day.toString();
      final yearStr = date.year.toString();
      final isPm = date.hour >= 12;
      final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
      final minuteStr = date.minute.toString().padLeft(2, '0');
      final periodStr = isPm ? "PM" : "AM";
      return "$dayStr $monthStr $yearStr, $hour12:$minuteStr $periodStr";
    } catch (e) {
      return "Unknown";
    }
  }
}
