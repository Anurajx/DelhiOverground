import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:metroapp/main.dart';

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
  String _agencyId = 'DTC';

  @override
  void initState() {
    super.initState();
    _loadDirections();
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

      // Resolve unique routeId
      String currentRouteId = widget.routeId;
      if (currentRouteId.isEmpty && routeResults.isNotEmpty) {
        final rResults = await db.rawQuery(
          '''
          SELECT route_id FROM routes WHERE route_long_name = ? LIMIT 1
        ''',
          [widget.routeLongName],
        );
        if (rResults.isNotEmpty) {
          currentRouteId = rResults.first['route_id'] as String;
        }
      }

      // Query all stops serving this specific route ID
      final stopsResults = await db.rawQuery(
        '''
        SELECT stop_id, stop_name, stop_lat, stop_lon, routes_list
        FROM stops
        WHERE routes_list LIKE ?
      ''',
        ['%$currentRouteId#%'],
      );

      // Parse and filter stops for this specific route ID
      final List<Map<String, dynamic>> parsedStops = [];
      for (final row in stopsResults) {
        final routesListStr = row['routes_list'] as String? ?? '';
        final tokens = routesListStr.split('-');
        for (final token in tokens) {
          final hashParts = token.split('#');
          if (hashParts.length == 2 && hashParts[0] == currentRouteId) {
            final colonParts = hashParts[1].split(':');
            if (colonParts.length == 2) {
              final seq = int.tryParse(colonParts[1]) ?? 0;
              parsedStops.add({
                'stop_id': row['stop_id'],
                'stop_name': row['stop_name'],
                'stop_lat': row['stop_lat'],
                'stop_lon': row['stop_lon'],
                'routes_list': routesListStr,
                'sequence': seq,
              });
              break;
            }
          }
        }
      }

      // Sort stops by sequence number
      parsedStops.sort((a, b) => (a['sequence'] as int).compareTo(b['sequence'] as int));

      List<Map<String, dynamic>> directionsList = [];
      if (parsedStops.isNotEmpty) {
        final startStop = parsedStops.first['stop_name'] as String;
        final endStop = parsedStops.last['stop_name'] as String;

        directionsList.add({
          'route_id': currentRouteId,
          'direction_id': 0,
          'trip_id': 'rep_trip',
          'stop_count': parsedStops.length,
          'start_stop': startStop,
          'end_stop': endStop,
          'trip_headsign': '$startStop ➔ $endStop',
          'first_bus': '--',
          'last_bus': '--',
          'total_trips': 0,
        });
      }

      if (mounted) {
        setState(() {
          _directions = directionsList;
          _isLoadingDirections = false;
          if (_directions.isNotEmpty) {
            _selectedDirection = _directions.first;
            _stops = parsedStops;
          }
          _isLoadingStops = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading directions: $e");
      if (mounted) {
        setState(() {
          _isLoadingDirections = false;
          _isLoadingStops = false;
        });
      }
    }
  }

  Future<void> _loadStopsForTrip(String tripId) async {
    // No database query needed as stops are pre-loaded and sorted
    setState(() {
      _isLoadingStops = false;
    });
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



  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 12.h, bottom: 4.h),
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
          Padding(
            padding: EdgeInsets.symmetric(vertical: 22.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Route ${widget.routeLongName}",
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      if (!_isLoadingDirections && _directions.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _directions.map((dir) {
                            final index = _directions.indexOf(dir);
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
                                color: Colors.transparent,
                                padding: EdgeInsets.symmetric(vertical: 2.h),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  dir['trip_headsign'] ?? "Option ${index + 1}",
                                  style: TextStyle(
                                    color: isSelected
                                        ? AppColors.secondaryText
                                        : AppColors.tertiaryText,
                                    fontSize: 12.sp,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                SizedBox(
                  width: 32.w,
                  child: Center(
                    child: _agencyId == 'DTC'
                        ? Image.asset(
                            'assets/Image/dtc.png',
                            height: 14.h,
                            fit: BoxFit.contain,
                        )
                        : Container(
                            width: 30.w,
                            height: 13.h,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.orange,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.zero,
                            ),
                            child: Text(
                              "DIMTS",
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 5.5,
                                fontWeight: FontWeight.w800,
                                fontFamily: 'Poppins',
                              ),
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
        // Split stop name by '/'
        String mainName = stopName;
        String? subName;
        if (stopName.contains('/')) {
          final parts = stopName.split('/');
          mainName = parts[0].trim();
          subName = parts[1].trim();
        }



        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline connector and dot
            Column(
              children: [
                Container(
                  width: 14.w,
                  height: 14.w,
                  margin: EdgeInsets.only(top: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryText,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                ),
                if (index < _stops.length - 1)
                  Container(
                    width: 2.w,
                    height: 36.h, // Adjusted height to accommodate space saved by removing details
                    color: AppColors.secondaryText.withValues(alpha: 0.5),
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
                      color: AppColors.secondaryText,
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

                  SizedBox(height: 12.h),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
