import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../search.dart';
import 'package:metroapp/main.dart';

// -------------------- LINE COLORS --------------------
Color getColorFromRouteName(String routeName) {
  if (routeName.isEmpty) return const Color.fromARGB(226, 255, 255, 255);
  int hash = 0;
  for (int i = 0; i < routeName.length; i++) {
    hash = routeName.codeUnitAt(i) + ((hash << 5) - hash);
  }
  double hue = (hash.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.35, 0.7).toColor();
}

// -------------------- MODEL --------------------
class ScheduleInfo {
  final String destination;
  final String lineId;
  final Color lineColor;
  final String frequencyText; // Formatted departure time e.g. "14:35"
  final int minutesLeft;
  final String relativeText;

  ScheduleInfo({
    required this.destination,
    required this.lineId,
    required this.lineColor,
    required this.frequencyText,
    required this.minutesLeft,
    required this.relativeText,
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
        lineColor: getColorFromRouteName(routeName),
        frequencyText: formatTime12h(departureTime),
        minutesLeft: diff,
        relativeText: relativeText,
      ),
    );
  }

  return schedules;
}

// -------------------- UI WIDGET --------------------
class ScheduleWidget extends StatefulWidget {
  final String stationCode;
  const ScheduleWidget({super.key, required this.stationCode});

  @override
  State<ScheduleWidget> createState() => _ScheduleWidgetState();
}

class _ScheduleWidgetState extends State<ScheduleWidget> {
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = "";
  List<ScheduleInfo> schedules = [];
  String stationName = "";

  @override
  void initState() {
    super.initState();
    _loadData();
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

      final scheduleList = await getScheduleForStation(widget.stationCode);

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

  Widget _buildDestinationText(String destination) {
    final style = TextStyle(
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
          Text(parts[0], style: style),
          Text("till ${parts[1]}", style: style),
        ],
      );
    } else {
      return Text(destination, style: style);
    }
  }

  Widget _buildScheduleBlock(ScheduleInfo schedule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      decoration: BoxDecoration(
        //color: AppColors.surface,
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(15.0, 10.0, 10.0, 10.0),
                decoration: const BoxDecoration(color: Colors.transparent),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDestinationText("To ${schedule.destination}"),
                    const SizedBox(height: 4.0),
                    Text(
                      schedule.lineId,
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
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                child: Container(color: schedule.lineColor, width: 5.0),
              ),
            ],
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            padding: const EdgeInsets.all(10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Departure Time",
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w500,
                    fontSize: 15.sp,
                    fontFamily: 'Poppins',
                  ),
                ),
                Row(
                  children: [
                    Text(
                      schedule.frequencyText,
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 15.sp,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.zero,
                        border: Border.all(
                          color:
                              schedule.minutesLeft <= 15
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent,
                          width: 1,
                        ),
                      ),
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
                  ],
                ),
              ],
            ),
          ),
        ],
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
      margin: EdgeInsets.only(bottom: 3.h),
      child: Row(
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CupertinoActivityIndicator(radius: 20));
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [_buildHeader(), _buildScheduleList()],
      ),
    );
  }
}
