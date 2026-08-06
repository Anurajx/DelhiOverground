import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../search.dart';
import 'package:metroapp/main.dart';
import 'package:http/http.dart' as http;
import 'package:metroapp/elements/ServicesDir/stops_manager.dart';
import 'package:metroapp/elements/ServicesDir/analytics_service.dart';

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
  return [];
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
    final etaDivMatches = RegExp(
      r'<div\s+class="eta">([\s\S]*?)<\/div>',
      caseSensitive: false,
    ).allMatches(colcardHtml);

    for (final etaDivMatch in etaDivMatches) {
      final etaInnerHtml = etaDivMatch.group(1) ?? "";
      // Strip comments to avoid matching commented-out spans
      final cleanEtaHtml = etaInnerHtml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

      final spanMatch = RegExp(
        r'<span[^>]*>\s*:?(\w+)\s*<\/span>',
        caseSensitive: false,
      ).firstMatch(cleanEtaHtml);

      if (spanMatch != null) {
        final val = spanMatch.group(1)?.trim() ?? "";
        final int minutesLeft;
        if (val.toLowerCase() == "coming") {
          minutesLeft = 0;
        } else {
          minutesLeft = int.tryParse(val) ?? 0;
        }

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

        // Extract bus color from image tag
        final imgMatch = RegExp(
          r'src="[^"]*?/images/([^"]+)_bus\.png"',
          caseSensitive: false,
        ).firstMatch(etaInnerHtml);
        final colorName = imgMatch?.group(1)?.toLowerCase() ?? "";
        
        Color parsedColor;
        switch (colorName) {
          case 'red':
            parsedColor = const Color(0xFFEF5350);
            break;
          case 'green':
            parsedColor = const Color(0xFF4CAF50);
            break;
          case 'orange':
            parsedColor = const Color(0xFFFF9800);
            break;
          case 'blue':
          case 'light_blue':
            parsedColor = const Color(0xFF00B0FF);
            break;
          default:
            parsedColor = AppColors.primaryAccent;
        }

        results.add(
          ScheduleInfo(
            destination: terminal,
            lineId: "Route $routeName",
            lineColor: parsedColor,
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

  final Set<int> realtimeStopIds = {};
  for (final stopId in stopIds) {
    final parsed = int.tryParse(stopId);
    if (parsed != null) {
      realtimeStopIds.add(parsed);
    }
  }

  if (realtimeStopIds.isEmpty) {
    throw Exception("No real-time stop mapping found");
  }

  final List<ScheduleInfo> allSchedules = [];
  
  // 2. Fetch and parse for each realtime stop ID
  for (final rtId in realtimeStopIds) {
    final url = 'https://pis.delhitransport.in/get_buses_arriving_at_stop?stopid=$rtId';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final html = response.body;
        final schedules = parseRealtimeHtml(html);
        allSchedules.addAll(schedules);
      } else {
        PostHogService.trackApiError(url, 'Failed to fetch real-time data from server', response.statusCode);
        throw Exception("Failed to fetch real-time data from server (Status: ${response.statusCode})");
      }
    } catch (e) {
      PostHogService.trackApiError(url, e.toString());
      rethrow;
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
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      PostHogService.trackApiError(url, 'Failed to fetch real-time data from server', response.statusCode);
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
  } catch (e) {
    PostHogService.trackApiError(url, e.toString());
    rethrow;
  }
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
  bool isRealtime = true;

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
      
      final List<Map<String, dynamic>> options = [];
      final Set<int> seenIds = {};

      for (final stopId in stopIds) {
        final parsed = int.tryParse(stopId);
        if (parsed != null && !seenIds.contains(parsed)) {
          seenIds.add(parsed);
          final String name = StopsManager.getStopNameById(parsed) ?? 'Stop';
          final direction = StopsManager.getDirectionForId(parsed, name);
          options.add({
            'realtime_stop_id': parsed,
            'direction': direction,
          });
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
      final stopIds = widget.stationCode.split(',').map((id) => id.trim()).toList();
      final parsedCode = stopIds.isNotEmpty ? int.tryParse(stopIds.first) : null;
      if (parsedCode != null) {
        stationName = StopsManager.getStopNameById(parsedCode) ?? 'the selected station';
      } else {
        stationName = 'the selected station';
      }

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
        final errorStr = e.toString();
        if (isRealtime && errorStr.contains("No real-time stop mapping found")) {
          // Show the alert
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.black,
              insetPadding: EdgeInsets.symmetric(horizontal: 40.w),
              shape: const Border(), // sharp-cornered design
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(
                    color: AppColors.inputBorder,
                    width: 0.8,
                  ),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "REALTIME UNAVAILABLE",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13.sp,
                        fontFamily: 'Poppins',
                        letterSpacing: 1.5,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      "Realtime tracking is unavailable for this stop.",
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w400,
                        fontSize: 12.sp,
                        fontFamily: 'Poppins',
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                              color: AppColors.primaryAccent.withValues(alpha: 0.6),
                              width: 1.2,
                            ),
                          ),
                          child: Text(
                            "OK",
                            style: TextStyle(
                              color: AppColors.primaryAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.sp,
                              fontFamily: 'Poppins',
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          setState(() {
            hasError = true;
            errorMessage = "Real-time departures are unavailable for this stop.";
            isLoading = false;
          });
          return;
        }

        setState(() {
          hasError = true;
          errorMessage = errorStr.replaceFirst("Exception: ", "");
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
    return Container(
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
                padding: EdgeInsets.zero,
                decoration: const BoxDecoration(color: Colors.transparent),
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 10.0),
                      child: Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: const BoxDecoration(
                          color: Colors.black,
                          border: Border(
                            left: BorderSide(
                              color: AppColors.divider,
                              width: 0.8,
                            ),
                            bottom: BorderSide(
                              color: AppColors.divider,
                              width: 0.8,
                            ),
                            right: BorderSide(
                              color: AppColors.divider,
                              width: 0.8,
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.w,
                              height: 24.h,
                              color: schedule.lineColor,
                            ),
                            SizedBox(width: 8.w),
                            Icon(
                              CupertinoIcons.bus,
                              color: Colors.white,
                              size: 13.sp,
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              schedule.routeLongName.isNotEmpty
                                  ? schedule.routeLongName
                                  : schedule.lineId,
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: 8.w),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10.0),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 10.0),
                      child: _buildDestinationText(
                        "To ${schedule.destination}",
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontWeight: FontWeight.w400,
                          fontSize: 12.sp,
                          fontFamily: 'Poppins',
                        ),
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
            padding: EdgeInsets.zero,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 4.0,
                  ),
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    border: Border(
                      top: BorderSide(
                        color: AppColors.divider,
                        width: 0.8,
                      ),
                      left: BorderSide(
                        color: AppColors.divider,
                        width: 0.8,
                      ),
                      bottom: BorderSide(
                        color: AppColors.divider,
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      schedule.frequencyText,
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.sp,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minHeight: 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10.0,
                    vertical: 4.0,
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    if (hasError) {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: Image.asset(
                'assets/Image/dtcaccident.png',
                height: 100.h,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "please check your internet connection and try again :(",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryAccent,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      );
    }

    if (schedules.isEmpty) {
      final String message = isRealtime ? "no upcoming bus for this direction at stop" : "no buses scheduled";
      return Container(
        padding: EdgeInsets.symmetric(vertical: 40.h, horizontal: 24.w),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: Image.asset(
                'assets/Image/dtcaccident.png',
                height: 100.h,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "$message :(",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.primaryAccent,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
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
      margin: EdgeInsets.only(bottom: 6.h),
      child: Text(
        "Realtime Departures",
        style: TextStyle(
          color: AppColors.secondaryText,
          fontSize: 16.sp,
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDirectionSelector() {
    final Map<int, Widget> children = {};
    for (var opt in realtimeOptions) {
      final rtId = opt['realtime_stop_id'] as int;
      final direction = (opt['direction'] as String).replaceAll(RegExp(r'\b[Tt]owards\b'), 'To');
      final isSelected = rtId == selectedRealtimeStopId;

      children[rtId] = Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 4.w),
        child: Text(
          direction,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.secondaryText,
            fontSize: 10.sp,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontFamily: 'Poppins',
            letterSpacing: 0.2,
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(
              "Select Directions",
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
                letterSpacing: 0.5,
              ),
            ),
          ),
          CupertinoSlidingSegmentedControl<int>(
            groupValue: selectedRealtimeStopId,
            backgroundColor: AppColors.surface,
            thumbColor: AppColors.inputBackground,
            children: children,
            onValueChanged: (int? newValue) {
              if (newValue != null && selectedRealtimeStopId != newValue) {
                setState(() {
                  selectedRealtimeStopId = newValue;
                });
                _loadData();
              }
            },
          ),
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
