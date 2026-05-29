import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../search.dart';
import 'package:metroapp/main.dart';
import 'package:metroapp/elements/bus_info.dart';
import 'package:http/http.dart' as http;

// -------------------- MODEL --------------------
class ScheduleInfo {
  final String destination;
  final String lineId;
  final Color lineColor;
  final String frequencyText; // Formatted departure time e.g. "14:35"
  final int minutesLeft;
  final String relativeText;
  final String routeId;
  final String routeLongName;

  ScheduleInfo({
    required this.destination,
    required this.lineId,
    required this.lineColor,
    required this.frequencyText,
    required this.minutesLeft,
    required this.relativeText,
    required this.routeId,
    required this.routeLongName,
  });
}

// -------------------- DATABASE ACCESS --------------------
// Reused from BusDatabaseHelper in search.dart

int _getMinutesFromTimeStr(String timeStr) {
  try {
    final parts = timeStr.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  } catch (e) {
    return 0;
  }
}

String formatTime12h(String timeStr) {
  try {
    final parts = timeStr.split(':');
    int hr = int.parse(parts[0]);
    int min = int.parse(parts[1]);
    String period = "AM";
    if (hr >= 12) {
      period = "PM";
      if (hr > 12) hr -= 12;
    }
    if (hr == 0) hr = 12;
    final minStr = min.toString().padLeft(2, '0');
    return "$hr:$minStr $period";
  } catch (e) {
    return timeStr;
  }
}

// -------------------- FETCHING --------------------
Future<List<ScheduleInfo>> getScheduleForStation(String stationCode) async {
  final db = await BusDatabaseHelper.getDatabase();

  final now = DateTime.now();
  final currentTimeStr =
      "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
  final currentMinutes = now.hour * 60 + now.minute;

  final stopIds = stationCode.split(',').map((id) => id.trim()).toList();
  final placeholders = List.filled(stopIds.length, '?').join(',');

  // Query upcoming departures
  var results = await db.rawQuery(
    '''
    SELECT 
      t.trip_id,
      r.route_id,
      r.route_long_name,
      t.trip_headsign,
      st.departure_time,
      (SELECT s2.stop_name 
       FROM stop_times st2 
       JOIN stops s2 ON st2.stop_id = s2.stop_id 
       WHERE st2.trip_id = t.trip_id 
       ORDER BY st2.stop_sequence DESC 
       LIMIT 1) as destination_name
    FROM stop_times st
    JOIN trips t ON st.trip_id = t.trip_id
    JOIN routes r ON t.route_id = r.route_id
    WHERE st.stop_id IN ($placeholders) AND st.departure_time >= ?
    ORDER BY st.departure_time ASC
    LIMIT 15
  ''',
    [...stopIds, currentTimeStr],
  );

  // Fallback: If no more departures today, display early morning departures
  if (results.isEmpty) {
    results = await db.rawQuery('''
      SELECT 
        t.trip_id,
        r.route_id,
        r.route_long_name,
        t.trip_headsign,
        st.departure_time,
        (SELECT s2.stop_name 
         FROM stop_times st2 
         JOIN stops s2 ON st2.stop_id = s2.stop_id 
         WHERE st2.trip_id = t.trip_id 
         ORDER BY st2.stop_sequence DESC 
         LIMIT 1) as destination_name
      FROM stop_times st
      JOIN trips t ON st.trip_id = t.trip_id
      JOIN routes r ON t.route_id = r.route_id
      WHERE st.stop_id IN ($placeholders)
      ORDER BY st.departure_time ASC
      LIMIT 15
    ''', stopIds);
  }

  final List<ScheduleInfo> schedules = [];

  for (final row in results) {
    final routeId = row["route_id"] as String? ?? "";
    final routeName = row["route_long_name"] as String;
    final headsign = row["trip_headsign"] as String;
    final departureTime = row["departure_time"] as String;
    final destinationName = row["destination_name"] as String? ?? "";

    final depMinutes = _getMinutesFromTimeStr(departureTime);
    int diff = depMinutes - currentMinutes;
    if (diff < 0) {
      diff += 24 * 60; // Next day
    }

    String relativeText;
    if (diff == 0) {
      relativeText = "Now";
    } else if (diff < 60) {
      relativeText = "In $diff mins";
    } else {
      int hrs = diff ~/ 60;
      int mins = diff % 60;
      relativeText = "In $hrs hr $mins mins";
    }

    schedules.add(
      ScheduleInfo(
        destination:
            destinationName.isNotEmpty
                ? destinationName
                : (headsign.isNotEmpty ? headsign : "Terminal"),
        lineId: "Route $routeName",
        lineColor: AppColors.primaryAccent,
        frequencyText: formatTime12h(departureTime),
        minutesLeft: diff,
        relativeText: relativeText,
        routeId: routeId,
        routeLongName: routeName,
      ),
    );
  }

  return schedules;
}

Future<String> getRouteIdForRouteLongName(String routeLongName) async {
  try {
    final db = await BusDatabaseHelper.getDatabase();
    final results = await db.rawQuery(
      'SELECT route_id FROM routes WHERE route_long_name = ? LIMIT 1',
      [routeLongName],
    );
    if (results.isNotEmpty) {
      return results.first['route_id'] as String? ?? "";
    }
  } catch (e) {
    debugPrint("Error looking up route_id for $routeLongName: $e");
  }
  return "";
}

List<ScheduleInfo> parseRealtimeHtml(String html) {
  final List<ScheduleInfo> results = [];
  
  // Split by the schedule section to only parse the live/upcoming departures
  String liveSection = html;
  final scheduleIndex = html.toLowerCase().indexOf('class="schedule"');
  if (scheduleIndex != -1) {
    liveSection = html.substring(0, scheduleIndex);
  }

  // Find all colcard blocks in the live section
  final colcardMatches = RegExp(
    r'<div\s+class="colcard">([\s\S]*?)(?=<div\s+class="colcard">|<div\s+class="headernames">|<div\s+class="logos">|<\/body>|<\/html>)',
    caseSensitive: false,
  ).allMatches(liveSection);

  final now = DateTime.now();

  for (final match in colcardMatches) {
    final colcardHtml = match.group(1) ?? "";

    // 1. Extract route name
    final routeMatch = RegExp(
      r'class="route_info"[^>]*>\s*([^<]+?)\s*<br>',
      caseSensitive: false,
    ).firstMatch(colcardHtml);
    final routeName = routeMatch?.group(1)?.trim() ?? "";
    if (routeName.isEmpty) continue;

    // 2. Extract terminal/destination
    final terminalMatch = RegExp(
      r'class="terminal"[^>]*>\s*([^<]+?)\s*<\/span>',
      caseSensitive: false,
    ).firstMatch(colcardHtml);
    final terminal = terminalMatch?.group(1)?.trim() ?? "Terminal";

    // 3. Extract all ETAs
    final etaMatches = RegExp(
      r'class="eta"[\s\S]*?<span>\s*:?(\d+)\s*<\/span>',
      caseSensitive: false,
    ).allMatches(colcardHtml);

    for (final etaMatch in etaMatches) {
      final etaStr = etaMatch.group(1);
      if (etaStr != null) {
        final minutesLeft = int.tryParse(etaStr) ?? 0;

        // Calculate absolute time
        final arrivalTime = now.add(Duration(minutes: minutesLeft));
        final amPm = arrivalTime.hour >= 12 ? "PM" : "AM";
        int hour = arrivalTime.hour % 12;
        if (hour == 0) hour = 12;
        final minuteStr = arrivalTime.minute.toString().padLeft(2, '0');
        final frequencyText = "$hour:$minuteStr $amPm";

        String relativeText;
        if (minutesLeft == 0) {
          relativeText = "Now";
        } else {
          relativeText = "In $minutesLeft mins";
        }

        results.add(
          ScheduleInfo(
            destination: terminal,
            lineId: "Route $routeName",
            lineColor: AppColors.primaryAccent,
            frequencyText: frequencyText,
            minutesLeft: minutesLeft,
            relativeText: relativeText,
            routeId: "", // Will be resolved from Database later
            routeLongName: routeName,
          ),
        );
      }
    }
  }

  return results;
}

Future<List<ScheduleInfo>> getRealtimeScheduleForStation(String stationCode) async {
  final stopIds = stationCode.split(',').map((id) => id.trim()).toList();
  
  if (stopIds.length > 1) {
    // ignore: avoid_print
    print("MERGED RECORD STATIC ON");
  }

  // 1. Load and parse reconciled stops
  final reconciledStr = await rootBundle.loadString('assets/reconciled_stops.json');
  final List<dynamic> reconciledJson = jsonDecode(reconciledStr);
  
  final Set<int> realtimeStopIds = {};
  for (final stopId in stopIds) {
    for (final item in reconciledJson) {
      if (item['static_stop_id']?.toString() == stopId) {
        final rtId = item['realtime_stop_id'];
        if (rtId != null) {
          if (rtId is int) {
            realtimeStopIds.add(rtId);
          } else {
            final parsed = int.tryParse(rtId.toString());
            if (parsed != null) {
              realtimeStopIds.add(parsed);
            }
          }
        }
      }
    }
  }

  if (realtimeStopIds.isEmpty) {
    throw Exception("No real-time stop mapping found");
  }

  final List<ScheduleInfo> allSchedules = [];
  
  // 2. Fetch and parse for each realtime stop ID
  for (final rtId in realtimeStopIds) {
    final url = 'https://pis.delhitransport.in/get_buses_arriving_at_stop?stopid=$rtId';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final html = response.body;
      final schedules = parseRealtimeHtml(html);
      allSchedules.addAll(schedules);
    } else {
      throw Exception("Failed to fetch real-time data from server (Status: ${response.statusCode})");
    }
  }

  // 3. Resolve route_ids from Database
  for (int i = 0; i < allSchedules.length; i++) {
    final sched = allSchedules[i];
    final routeId = await getRouteIdForRouteLongName(sched.routeLongName);
    if (routeId.isNotEmpty) {
      allSchedules[i] = ScheduleInfo(
        destination: sched.destination,
        lineId: sched.lineId,
        lineColor: sched.lineColor,
        frequencyText: sched.frequencyText,
        minutesLeft: sched.minutesLeft,
        relativeText: sched.relativeText,
        routeId: routeId,
        routeLongName: sched.routeLongName,
      );
    }
  }

  // 4. Sort schedules by minutesLeft ascending
  allSchedules.sort((a, b) => a.minutesLeft.compareTo(b.minutesLeft));

  return allSchedules;
}

Future<List<ScheduleInfo>> getRealtimeScheduleForStopId(int rtId) async {
  final url = 'https://pis.delhitransport.in/get_buses_arriving_at_stop?stopid=$rtId';
  final response = await http.get(Uri.parse(url));
  if (response.statusCode != 200) {
    throw Exception("Failed to fetch real-time data from server (Status: ${response.statusCode})");
  }

  final html = response.body;
  final schedules = parseRealtimeHtml(html);

  // Resolve route_ids from Database
  for (int i = 0; i < schedules.length; i++) {
    final sched = schedules[i];
    final routeId = await getRouteIdForRouteLongName(sched.routeLongName);
    if (routeId.isNotEmpty) {
      schedules[i] = ScheduleInfo(
        destination: sched.destination,
        lineId: sched.lineId,
        lineColor: sched.lineColor,
        frequencyText: sched.frequencyText,
        minutesLeft: sched.minutesLeft,
        relativeText: sched.relativeText,
        routeId: routeId,
        routeLongName: sched.routeLongName,
      );
    }
  }

  schedules.sort((a, b) => a.minutesLeft.compareTo(b.minutesLeft));
  return schedules;
}

// -------------------- UI WIDGET --------------------
class ScheduleWidget extends StatefulWidget {
  final String stationCode;
  final DateTime? refreshTrigger;
  const ScheduleWidget({super.key, required this.stationCode, this.refreshTrigger});

  @override
  State<ScheduleWidget> createState() => _ScheduleWidgetState();
}

class _ScheduleWidgetState extends State<ScheduleWidget> {
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = "";
  List<ScheduleInfo> schedules = [];
  String stationName = "";
  bool isRealtime = false;

  List<Map<String, dynamic>> realtimeOptions = [];
  int? selectedRealtimeStopId;
  bool optionsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ScheduleWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _loadData();
    }
  }

  Future<void> _loadRealtimeOptions() async {
    if (optionsLoaded) return;
    try {
      final stopIds = widget.stationCode.split(',').map((id) => id.trim()).toList();
      final reconciledStr = await rootBundle.loadString('assets/reconciled_stops.json');
      final List<dynamic> reconciledJson = jsonDecode(reconciledStr);
      
      final List<Map<String, dynamic>> options = [];
      final Set<int> seenIds = {};

      for (final stopId in stopIds) {
        for (final item in reconciledJson) {
          if (item['static_stop_id']?.toString() == stopId) {
            final rtId = item['realtime_stop_id'];
            final rtNext = item['realtime_next_stop_name'];
            if (rtId != null) {
              final intParsed = rtId is int ? rtId : int.tryParse(rtId.toString());
              if (intParsed != null && !seenIds.contains(intParsed)) {
                seenIds.add(intParsed);
                options.add({
                  'realtime_stop_id': intParsed,
                  'direction': rtNext?.toString() ?? 'Unknown Direction',
                });
              }
            }
          }
        }
      }

      setState(() {
        realtimeOptions = options;
        if (realtimeOptions.isNotEmpty && selectedRealtimeStopId == null) {
          selectedRealtimeStopId = realtimeOptions.first['realtime_stop_id'] as int;
        }
        optionsLoaded = true;
      });
    } catch (e) {
      debugPrint("Error loading realtime options: $e");
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final stationsStr = await rootBundle.loadString(
        'assets/Map/stationsjson.json',
      );
      final stationsJson = List<Map<String, dynamic>>.from(
        jsonDecode(stationsStr),
      );

      final stationDataForName = stationsJson.firstWhere(
        (s) => s['StationCode'] == widget.stationCode,
        orElse: () => <String, dynamic>{},
      );
      stationName = stationDataForName['Name'] ?? 'the selected station';

      if (isRealtime) {
        await _loadRealtimeOptions();
      }

      final List<ScheduleInfo> scheduleList;
      if (isRealtime) {
        if (selectedRealtimeStopId != null) {
          scheduleList = await getRealtimeScheduleForStopId(selectedRealtimeStopId!);
        } else {
          throw Exception("No real-time stop mapping found");
        }
      } else {
        scheduleList = await getScheduleForStation(widget.stationCode);
      }

      if (mounted) {
        setState(() {
          schedules = scheduleList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          hasError = true;
          errorMessage = e.toString().replaceFirst("Exception: ", "");
          isLoading = false;
        });
      }
    }
  }

  Widget _buildDestinationText(String destination, {TextStyle? style}) {
    final defaultStyle =
        style ??
        TextStyle(
          color: AppColors.primaryText,
          fontWeight: FontWeight.w600,
          fontSize: 14.sp,
          fontFamily: 'Poppins',
        );
    if (destination.contains(" to ")) {
      final parts = destination.split(" to ");
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(parts[0], style: defaultStyle),
          Text("till ${parts[1]}", style: defaultStyle),
        ],
      );
    } else {
      return Text(destination, style: defaultStyle);
    }
  }

  Widget _buildScheduleBlock(ScheduleInfo schedule) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => BusInfoScreen(
                  routeId: schedule.routeId,
                  routeLongName: schedule.routeLongName,
                ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6.0),
        decoration: BoxDecoration(
          color: Colors.black, // background black
          border: Border.all(
            color: const Color.fromARGB(
              58,
              58,
              58,
              58,
            ), // AppColors.inputBorder at 0.12 opacity
            width: 0.8,
          ),
          gradient: const LinearGradient(
            begin: Alignment.centerRight,
            end: Alignment.centerLeft,
            colors: [
              Color.fromARGB(
                18,
                0,
                229,
                255,
              ), // M-series Cyan (slightly more visible)

              Color.fromARGB(14, 41, 121, 255), // M-series Royal Blue

              Color.fromARGB(10, 213, 0, 249), // M-series Pink/Purple

              Color.fromARGB(8, 255, 109, 0), // M-series Amber/Gold

              Color.fromARGB(2, 255, 109, 0), // subtle fade-out tail
            ],
            stops: [0.0, 0.25, 0.55, 0.8, 1.0],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(10.0, 10.0, 10.0, 10.0),
                  decoration: const BoxDecoration(color: Colors.transparent),
                  width: double.infinity,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        schedule.lineId,
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      _buildDestinationText(
                        "To ${schedule.destination}",
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w400,
                          fontSize: 12.sp,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Color.fromARGB(
                      31,
                      44,
                      44,
                      44,
                    ), // AppColors.divider at 0.12 opacity
                    width: 0.8,
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 10.0,
                vertical: 4.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 2.0,
                    ),
                    decoration: BoxDecoration(
                      color:
                          schedule.minutesLeft <= 15
                              ? const Color.fromARGB(77, 105, 240, 175)
                              : const Color.fromARGB(85, 255, 172, 64),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Center(
                      child: Text(
                        schedule.relativeText,
                        style: TextStyle(
                          color:
                              schedule.minutesLeft <= 15
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12.sp,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  Text(
                    schedule.frequencyText,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.sp,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    if (hasError) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48.0),
              const SizedBox(height: 16.0),
              Text(
                errorMessage,
                style: TextStyle(
                  color: AppColors.destructive,
                  fontSize: 14.sp,
                  fontFamily: 'Poppins',
                ),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16.0),
              ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (schedules.isEmpty) {
      return SizedBox(
        height: 200.0,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_bus, color: Colors.grey, size: 48.0),
              const SizedBox(height: 16.0),
              Text(
                'No upcoming buses\nfor $stationName',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.tertiaryText,
                  fontSize: 16.sp,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children:
          schedules.map((schedule) => _buildScheduleBlock(schedule)).toList(),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "UPCOMING DEPARTURES",
            style: TextStyle(
              color: AppColors.tertiaryText,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              letterSpacing: 1.0,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Realtime",
                style: TextStyle(
                  color: isRealtime ? Colors.white : AppColors.secondaryText,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () {
                  setState(() {
                    isRealtime = !isRealtime;
                    _loadData();
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  width: 44.w,
                  height: 24.h,
                  padding: EdgeInsets.symmetric(horizontal: 3.w),
                  decoration: BoxDecoration(
                    color: isRealtime
                        ? AppColors.primaryAccent.withValues(alpha: 0.15)
                        : Colors.transparent,
                    border: Border.all(
                      color: isRealtime
                          ? AppColors.primaryAccent
                          : AppColors.inputBorder,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: isRealtime ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 14.h,
                      height: 14.h,
                      decoration: BoxDecoration(
                        color: isRealtime ? AppColors.primaryAccent : AppColors.secondaryText,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDirectionSelector() {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: const Color.fromARGB(58, 58, 58, 58),
          width: 1.0,
        ),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
            child: Text(
              "SELECT DIRECTION",
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                letterSpacing: 0.5,
              ),
            ),
          ),
          ...realtimeOptions.asMap().entries.map((entry) {
            final idx = entry.key;
            final opt = entry.value;
            final rtId = opt['realtime_stop_id'] as int;
            final direction = opt['direction'] as String;
            final isSelected = rtId == selectedRealtimeStopId;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (idx > 0)
                  Container(
                    height: 1.0,
                    color: const Color.fromARGB(24, 255, 255, 255),
                  ),
                GestureDetector(
                  onTap: () {
                    if (selectedRealtimeStopId != rtId) {
                      setState(() {
                        selectedRealtimeStopId = rtId;
                      });
                      _loadData();
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                    color: isSelected ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          width: 16.w,
                          height: 16.w,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? AppColors.primaryAccent : AppColors.secondaryText,
                              width: 1.5,
                            ),
                            color: isSelected ? AppColors.primaryAccent.withValues(alpha: 0.1) : Colors.transparent,
                            borderRadius: BorderRadius.zero,
                          ),
                          child: Center(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 150),
                              child: isSelected
                                  ? Icon(
                                      Icons.check,
                                      color: AppColors.primaryAccent,
                                      size: 11.sp,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.secondaryText,
                              fontSize: 12.sp,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              fontFamily: 'Poppins',
                            ),
                            child: Text(direction),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          if (isRealtime && realtimeOptions.length > 1) _buildDirectionSelector(),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Center(child: CupertinoActivityIndicator(radius: 12)),
            )
          else
            _buildScheduleList(),
        ],
      ),
    );
  }
}
