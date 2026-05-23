import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:metroapp/main.dart';
import 'StationDir/stop_info.dart';
import 'search.dart'; // To reuse BusDatabaseHelper

class BusInfoScreen extends StatefulWidget {
  final String routeId;
  final String routeLongName;

  const BusInfoScreen({
    super.key,

    required this.routeId,
    required this.routeLongName,
  });

  @override
  State<BusInfoScreen> createState() => _BusInfoScreenState();
}

class _BusInfoScreenState extends State<BusInfoScreen> {
  List<Map<String, dynamic>> _directions = [];
  Map<String, dynamic>? _selectedDirection;
  List<Map<String, dynamic>> _stops = [];
  bool _isLoadingDirections = true;
  bool _isLoadingStops = false;
  Color _routeColor = Colors.blueAccent;
  String _agencyId = 'DTC';

  @override
  void initState() {
    super.initState();
    _routeColor = AppColors.primaryAccent;
    _loadDirections();
  }

  String _formatTime(String timeStr) {
    if (timeStr == "--" || timeStr.isEmpty) return "--";
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length < 2) return timeStr;
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);
      String period = "AM";
      if (hour >= 12) {
        period = "PM";
        if (hour > 12) hour -= 12;
      }
      if (hour == 0) hour = 12;
      final minStr = minute.toString().padLeft(2, '0');
      final hrStr = hour.toString().padLeft(2, '0');
      return "$hrStr:$minStr $period";
    } catch (e) {
      return timeStr;
    }
  }

  Future<void> _loadDirections() async {
    try {
      final db = await BusDatabaseHelper.getDatabase();

      // Query agency_id
      var routeResults = await db.rawQuery(
        '''
        SELECT agency_id FROM routes WHERE route_id = ? LIMIT 1
      ''',
        [widget.routeId],
      );
      if (routeResults.isEmpty) {
        routeResults = await db.rawQuery(
          '''
          SELECT agency_id FROM routes WHERE route_long_name = ? LIMIT 1
        ''',
          [widget.routeLongName],
        );
      }
      if (routeResults.isNotEmpty && mounted) {
        setState(() {
          _agencyId = routeResults.first['agency_id'] as String? ?? 'DTC';
        });
      }

      // Try querying by routeId first
      var dirResults = await db.rawQuery(
        '''
        SELECT DISTINCT direction_id, route_id
        FROM trips
        WHERE route_id = ?
      ''',
        [widget.routeId],
      );

      // Fallback using routeLongName
      if (dirResults.isEmpty) {
        dirResults = await db.rawQuery(
          '''
          SELECT DISTINCT t.direction_id, t.route_id
          FROM trips t
          JOIN routes r ON t.route_id = r.route_id
          WHERE r.route_long_name = ?
        ''',
          [widget.routeLongName],
        );
      }

      List<Map<String, dynamic>> directionsList = [];

      for (var row in dirResults) {
        final dirId = row['direction_id'];
        final rId = row['route_id'] as String;

        // Find representative trip
        final tripResult = await db.rawQuery(
          '''
          SELECT t.trip_id, COUNT(st.stop_id) as stop_count
          FROM trips t
          JOIN stop_times st ON t.trip_id = st.trip_id
          WHERE t.route_id = ? AND t.direction_id = ?
          GROUP BY t.trip_id
          ORDER BY stop_count DESC
          LIMIT 1
        ''',
          [rId, dirId],
        );

        if (tripResult.isEmpty) continue;

        final tripId = tripResult.first['trip_id'] as String;
        final stopCount = tripResult.first['stop_count'] as int;

        // Find start stop
        final startResult = await db.rawQuery(
          '''
          SELECT s.stop_name
          FROM stop_times st
          JOIN stops s ON st.stop_id = s.stop_id
          WHERE st.trip_id = ?
          ORDER BY st.stop_sequence ASC
          LIMIT 1
        ''',
          [tripId],
        );
        final startStop =
            startResult.isNotEmpty
                ? startResult.first['stop_name'] as String
                : "Start";

        // Find end stop
        final endResult = await db.rawQuery(
          '''
          SELECT s.stop_name
          FROM stop_times st
          JOIN stops s ON st.stop_id = s.stop_id
          WHERE st.trip_id = ?
          ORDER BY st.stop_sequence DESC
          LIMIT 1
        ''',
          [tripId],
        );
        final endStop =
            endResult.isNotEmpty
                ? endResult.first['stop_name'] as String
                : "End";

        // Query timings
        final timingsResult = await db.rawQuery(
          '''
          SELECT 
              MIN(first_st.arrival_time) as first_bus, 
              MAX(first_st.arrival_time) as last_bus, 
              COUNT(DISTINCT t.trip_id) as total_trips
          FROM trips t
          JOIN stop_times first_st ON t.trip_id = first_st.trip_id
          WHERE t.route_id = ? AND t.direction_id = ? AND first_st.stop_sequence = (
              SELECT MIN(stop_sequence) FROM stop_times WHERE trip_id = t.trip_id
          )
        ''',
          [rId, dirId],
        );

        String firstBus = "--";
        String lastBus = "--";
        int totalTrips = 0;

        if (timingsResult.isNotEmpty) {
          firstBus = timingsResult.first['first_bus'] as String? ?? "--";
          lastBus = timingsResult.first['last_bus'] as String? ?? "--";
          totalTrips = timingsResult.first['total_trips'] as int? ?? 0;
        }

        directionsList.add({
          'route_id': rId,
          'direction_id': dirId,
          'trip_id': tripId,
          'stop_count': stopCount,
          'start_stop': startStop,
          'end_stop': endStop,
          'trip_headsign': '$startStop ➔ $endStop',
          'first_bus': firstBus,
          'last_bus': lastBus,
          'total_trips': totalTrips,
        });
      }

      if (mounted) {
        setState(() {
          _directions = directionsList;
          _isLoadingDirections = false;
          if (_directions.isNotEmpty) {
            _selectedDirection = _directions.first;
            _loadStopsForTrip(_selectedDirection!['trip_id'] as String);
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading directions: $e");
      if (mounted) {
        setState(() {
          _isLoadingDirections = false;
        });
      }
    }
  }

  Future<void> _loadStopsForTrip(String tripId) async {
    setState(() {
      _isLoadingStops = true;
    });

    try {
      final db = await BusDatabaseHelper.getDatabase();
      final results = await db.rawQuery(
        '''
        SELECT s.stop_id, s.stop_name, s.stop_lat, s.stop_lon, s.routes_list
        FROM stop_times st
        JOIN stops s ON st.stop_id = s.stop_id
        WHERE st.trip_id = ?
        ORDER BY st.stop_sequence ASC
      ''',
        [tripId],
      );

      if (mounted) {
        setState(() {
          _stops = List<Map<String, dynamic>>.from(results);
          _isLoadingStops = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStops = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            if (_isLoadingDirections)
              const Expanded(
                child: Center(
                  child: CupertinoActivityIndicator(color: Colors.white),
                ),
              )
            else if (_directions.isEmpty)
              _buildEmptyState()
            else ...[
              _buildStatsCard(),
              _buildDirectionToggle(),
              Expanded(
                child:
                    _isLoadingStops
                        ? const Center(
                          child: CupertinoActivityIndicator(
                            color: Colors.white,
                          ),
                        )
                        : _buildStopsTimeline(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_selectedDirection == null) return const SizedBox.shrink();

    final firstBus = _formatTime(_selectedDirection!['first_bus'] as String);
    final lastBus = _formatTime(_selectedDirection!['last_bus'] as String);
    final totalTrips = _selectedDirection!['total_trips'] as int? ?? 0;
    final stopCount = _selectedDirection!['stop_count'] as int? ?? 0;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Color.fromARGB(38, 59, 131, 246),
        //borderRadius: BorderRadius.zero,
        //border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "ROUTE SUMMARY",
            style: TextStyle(
              color: AppColors.tertiaryText,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: CupertinoIcons.clock,
                  label: "First Bus",
                  value: firstBus,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: CupertinoIcons.clock_solid,
                  label: "Last Bus",
                  value: lastBus,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  icon: CupertinoIcons.refresh,
                  label: "Trips / Day",
                  value: "$totalTrips trips",
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  icon: CupertinoIcons.map_pin_ellipse,
                  label: "Total Stops",
                  value: "$stopCount stops",
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(5.w),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.zero,
            border: Border.all(
              color: AppColors.inputBorder.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Icon(icon, color: _routeColor, size: 14.sp),
        ),
        SizedBox(width: 8.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 10.sp,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.back,
                  color: AppColors.primaryAccent,
                  size: 20.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  "Back",
                  style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 15.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Bus Route Details",
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: Color.fromARGB(38, 59, 131, 246),
                            borderRadius:
                                BorderRadius.zero, // NeoPop Sharp Corners
                          ),
                          child: Text(
                            "Route ${widget.routeLongName}",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              SizedBox(
                width: 60.w,
                child: Center(
                  child:
                      _agencyId == 'DTC'
                          ? Image.asset(
                            'assets/Image/dtc.png',
                            height: 32.h,
                            fit: BoxFit.contain,
                          )
                          : Container(
                            width: 52.w,
                            height: 22.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.orange,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Text(
                              "DIMTS",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                                letterSpacing: 0.5,
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

  Widget _buildDirectionToggle() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "DIRECTION",
            style: TextStyle(
              color: AppColors.tertiaryText,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'Poppins',
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 8.h),
          SizedBox(
            height: 40.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _directions.length,
              separatorBuilder: (context, index) => SizedBox(width: 8.w),
              itemBuilder: (context, index) {
                final dir = _directions[index];
                final isSelected =
                    _selectedDirection?['trip_id'] == dir['trip_id'];

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedDirection = dir;
                      _loadStopsForTrip(dir['trip_id'] as String);
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.zero, // NeoPop Sharp Corners
                      border: Border.all(
                        color: isSelected ? _routeColor : AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(horizontal: 14.w),
                    alignment: Alignment.center,
                    child: Text(
                      dir['trip_headsign'] ?? "Option ${index + 1}",
                      style: TextStyle(
                        color:
                            isSelected ? _routeColor : AppColors.secondaryText,
                        fontSize: 12.sp,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.info_circle_fill,
              color: AppColors.tertiaryText,
              size: 32.sp,
            ),
            SizedBox(height: 10.h),
            Text(
              "No stop sequences found for this bus route.",
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14.sp,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopsTimeline() {
    if (_stops.isEmpty) {
      return Center(
        child: Text(
          "No stops found for this direction.",
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 14.sp,
            fontFamily: 'Poppins',
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: _stops.length,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemBuilder: (context, index) {
        final stop = _stops[index];
        final stopName = stop['stop_name'] as String? ?? "Unknown Stop";
        final routesList = stop['routes_list'] as String? ?? "";

        // Split stop name by '/'
        String mainName = stopName;
        String? subName;
        if (stopName.contains('/')) {
          final parts = stopName.split('/');
          mainName = parts[0].trim();
          subName = parts[1].trim();
        }

        final stopId = stop['stop_id']?.toString() ?? "N/A";
        final stopDetails = "Stop ID: $stopId";

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            // Navigate to existing StopInfoScreen
            final stationDict = {
              "Source": {
                "StationCode": stop['stop_id']?.toString() ?? "",
                "Name": stopName,
                "Hindi": stopName, // Hindi name fallback
                "Line": routesList,
                "Latitude": stop['stop_lat']?.toString() ?? "",
                "Longitude": stop['stop_lon']?.toString() ?? "",
              },
            };
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StopInfoScreen(stationDict: stationDict),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline connector and dot
              Column(
                children: [
                  Container(
                    width: 14.w,
                    height: 14.w,
                    decoration: BoxDecoration(
                      color: _routeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                  if (index < _stops.length - 1)
                    Container(
                      width: 2.w,
                      height:
                          48.h, // Adjusted height to accommodate sub-text and details
                      color: _routeColor.withValues(alpha: 0.5),
                    ),
                ],
              ),
              SizedBox(width: 16.w),
              // Stop Name details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mainName,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    if (subName != null) ...[
                      SizedBox(height: 2.h),
                      Text(
                        subName,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                    SizedBox(height: 4.h),
                    Text(
                      stopDetails,
                      style: TextStyle(
                        color: AppColors.tertiaryText,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    SizedBox(height: 12.h),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.right_chevron,
                color: AppColors.tertiaryText,
                size: 14.sp,
              ),
            ],
          ),
        );
      },
    );
  }
}
