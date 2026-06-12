import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:metroapp/elements/ServicesDir/data_provider.dart';
import 'package:metroapp/elements/ServicesDir/journey_planner_service.dart';
import 'package:metroapp/elements/ServicesDir/geolocator_service.dart' as geo_service;
import 'package:metroapp/main.dart';
import 'package:metroapp/elements/journey_details.dart';


class JourneyPlannerScreen extends StatefulWidget {
  final Map<String, String>? initialParams;
  const JourneyPlannerScreen({super.key, this.initialParams});

  @override
  State<JourneyPlannerScreen> createState() => _JourneyPlannerScreenState();
}

class _JourneyPlannerScreenState extends State<JourneyPlannerScreen> {
  // Search parameters
  String _srcName = '';
  double? _srcLat;
  double? _srcLon;
  String _srcType = 'place'; // 'place' or 'bus' or 'metro'

  String _dstName = '';
  double? _dstLat;
  double? _dstLon;
  String _dstType = 'place';

  String _selectedMode = 'bus'; // only bus
  TimeOfDay _selectedTime = TimeOfDay.now();

  bool _isLoading = false;
  String? _errorMessage;
  String? _errorSubtitle;
  List<JourneyRoute> _routes = [];

  List<dynamic> _allStops = [];

  @override
  void initState() {
    super.initState();
    _loadStops();
    if (widget.initialParams != null) {
      _applyInitialParams(widget.initialParams!);
    } else {
      // Default source to Current Location if permission is enabled
      _useCurrentLocation();
    }
  }

  void _applyInitialParams(Map<String, String> params) {
    setState(() {
      _srcName = params['src_name'] ?? '';
      _srcLat = double.tryParse(params['src_lat'] ?? '');
      _srcLon = double.tryParse(params['src_lon'] ?? '');
      _srcType = 'place';

      _dstName = params['dst_name'] ?? '';
      _dstLat = double.tryParse(params['dst_lat'] ?? '');
      _dstLon = double.tryParse(params['dst_lon'] ?? '');
      _dstType = 'place';


      _selectedMode = 'bus';

      final timeStr = params['time'] ?? '';
      if (timeStr.isNotEmpty) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          final hr = int.tryParse(parts[0]) ?? TimeOfDay.now().hour;
          final min = int.tryParse(parts[1]) ?? TimeOfDay.now().minute;
          _selectedTime = TimeOfDay(hour: hr, minute: min);
        }
      }
    });

    // Automatically trigger search
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _planJourney();
    });
  }

  Future<void> _loadStops() async {
    try {
      final stops = await geo_service.loadStationsFromJson();
      if (mounted) {
        setState(() {
          _allStops = stops;
        });

        // Automatically open the destination selector bottom sheet (which auto-focuses the keyboard)
        if (widget.initialParams == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openStopSelector(false);
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading stops in planner: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _srcName = 'Loading current location...';
    });
    try {
      final position = await geo_service.getCurrentLocation();
      final lat = position.latitude;
      final lon = position.longitude;

      if (lat >= 28.0 && lat <= 29.2 && lon >= 76.5 && lon <= 77.8) {
        if (mounted) {
          setState(() {
            _srcName = 'My Location';
            _srcLat = lat;
            _srcLon = lon;
            _srcType = 'place';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _srcName = '';
            _srcLat = null;
            _srcLon = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location is outside Delhi NCR. Please select a starting stop manually.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp),
              ),
              backgroundColor: AppColors.destructive,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _srcName = '';
          _srcLat = null;
          _srcLon = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Could not get current location. Please select manually.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13.sp),
            ),
            backgroundColor: AppColors.destructive,
          ),
        );
      }
    }
  }


  void _swapLocations() {
    setState(() {
      final tempName = _srcName;
      final tempLat = _srcLat;
      final tempLon = _srcLon;
      final tempType = _srcType;

      _srcName = _dstName;
      _srcLat = _dstLat;
      _srcLon = _dstLon;
      _srcType = _dstType;

      _dstName = tempName;
      _dstLat = tempLat;
      _dstLon = tempLon;
      _dstType = tempType;
    });
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryAccent,
              onPrimary: Colors.white,
              surface: AppColors.background,
              onSurface: AppColors.primaryText,
            ),
          ),
          child: child!,
        );

      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hr = tod.hour.toString().padLeft(2, '0');
    final min = tod.minute.toString().padLeft(2, '0');
    return '$hr:$min:00';
  }

  Future<void> _planJourney() async {
    if (_srcLat == null || _srcLon == null || _dstLat == null || _dstLon == null) {
      setState(() {
        _errorMessage = 'Please select both start and end locations.';
      });
      return;
    }

    if (_srcLat == 0.0 || _srcLon == 0.0 || _dstLat == 0.0 || _dstLon == 0.0) {
      setState(() {
        _errorMessage = 'Invalid coordinates. Please select locations again.';
      });
      return;
    }

    if (_srcLat! < 28.0 || _srcLat! > 29.2 || _srcLon! < 76.5 || _srcLon! > 77.8 ||
        _dstLat! < 28.0 || _dstLat! > 29.2 || _dstLon! < 76.5 || _dstLon! > 77.8) {
      setState(() {
        _errorMessage = 'Journey planner is only available within Delhi NCR. Please select locations within the service area.';
      });
      return;
    }


    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _errorSubtitle = null;
      _routes = [];
    });

    final timeStr = _formatTimeOfDay(_selectedTime);

    try {
      final result = await JourneyPlannerService.planJourney(
        srcLat: _srcLat!,
        srcLon: _srcLon!,
        srcType: _srcType,
        dstLat: _dstLat!,
        dstLon: _dstLon!,
        dstType: _dstType,
        mode: _selectedMode,
        time: timeStr,
      );

      if (mounted) {
        setState(() {
          _routes = result;
          _isLoading = false;
        });

        // Save to search history provider
        Provider.of<DataProvider>(context, listen: false).addJourneyToHistory(
          srcName: _srcName,
          srcLat: _srcLat!.toString(),
          srcLon: _srcLon!.toString(),
          srcType: _srcType,
          dstName: _dstName,
          dstLat: _dstLat!.toString(),
          dstLon: _dstLon!.toString(),
          dstType: _dstType,
          mode: _selectedMode,
          time: timeStr,
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final RegExp codeRegExp = RegExp(r'\b\d{3}\b');
        final match = codeRegExp.firstMatch(errStr);
        final errCode = match != null ? match.group(0) : '500';

        setState(() {
          _errorMessage = 'We are experiencing difficulty fetching route. Please try again later.';
          _errorSubtitle = errCode;
          _isLoading = false;
        });
      }
    }
  }

  void _openStopSelector(bool isSource) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StopSelectorModal(
          allStops: _allStops,
          allowCurrentLocation: isSource,
          onSelect: (name, lat, lon, type) {
            if (name == "My Location") {
              _useCurrentLocation();
            } else {
              setState(() {
                if (isSource) {
                  _srcName = name;
                  _srcLat = lat;
                  _srcLon = lon;
                  _srcType = 'place';
                } else {
                  _dstName = name;
                  _dstLat = lat;
                  _dstLon = lon;
                  _dstType = 'place';
                }
              });
            }
          },


        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Column(
                children: [
                  _buildInputsCard(),
                  SizedBox(height: 12.h),
                  _buildTimeAndSearchButton(),
                  SizedBox(height: 16.h),
                ],
              ),
            ),
            Expanded(
              child: _buildResultsSection(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Row(
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
          SizedBox(width: 20.w),
          Text(
            "Plan Journey",
            style: TextStyle(
              color: AppColors.primaryText,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w700,
              fontSize: 18.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputsCard() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left part: Integrated timeline dots and flip icon
            SizedBox(
              width: 44.h, // Match the width of the clock button exactly for vertical alignment
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // From circle dot (aligned with source input center)
                  Container(
                    margin: EdgeInsets.only(top: 17.h),
                    width: 8.w,
                    height: 8.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  // Flip Swap trigger in the middle
                  GestureDetector(
                    onTap: _swapLocations,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 6.w),
                      color: Colors.transparent,
                      child: Icon(
                        CupertinoIcons.arrow_up_down,
                        color: AppColors.primaryAccent,
                        size: 16.sp,
                      ),
                    ),
                  ),
                  // To square dot (aligned with destination input center)
                  Container(
                    margin: EdgeInsets.only(bottom: 17.h),
                    width: 8.w,
                    height: 8.w,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.rectangle,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 10.w), // Space between icons column and input fields (matching row below)
            // Right part: The two input fields Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => _openStopSelector(true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
                      decoration: BoxDecoration(
                        color: AppColors.foreground,
                        border: Border.all(color: AppColors.inputBorder, width: 0.8),
                      ),
                      width: double.infinity,
                      height: 42.h,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _srcName.isNotEmpty ? _srcName : 'Choose starting point...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _srcName.isNotEmpty
                                    ? AppColors.primaryText
                                    : AppColors.tertiaryText,
                                fontFamily: 'Poppins',
                                fontSize: 13.sp,
                                fontWeight: _srcName.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Prevent bottom sheet trigger
                              _useCurrentLocation();
                            },
                            child: Icon(
                              CupertinoIcons.location,
                              color: AppColors.primaryAccent,
                              size: 16.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  GestureDetector(
                    onTap: () => _openStopSelector(false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
                      decoration: BoxDecoration(
                        color: AppColors.foreground,
                        border: Border.all(color: AppColors.inputBorder, width: 0.8),
                      ),
                      width: double.infinity,
                      height: 42.h,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _dstName.isNotEmpty ? _dstName : 'Choose destination...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _dstName.isNotEmpty
                              ? AppColors.primaryText
                              : AppColors.tertiaryText,
                          fontFamily: 'Poppins',
                          fontSize: 13.sp,
                          fontWeight: _dstName.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
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



  Widget _buildTimeAndSearchButton() {
    return Row(
      children: [
        GestureDetector(
          onTap: _selectTime,
          child: Container(
            width: 44.h,
            height: 44.h,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(
                color: const Color.fromARGB(58, 58, 58, 58),
                width: 0.8,
              ),
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Color.fromARGB(18, 0, 229, 255),
                  Color.fromARGB(14, 41, 121, 255),
                  Color.fromARGB(10, 213, 0, 249),
                  Color.fromARGB(8, 255, 109, 0),
                  Color.fromARGB(2, 255, 109, 0),
                ],
                stops: [0.0, 0.25, 0.55, 0.8, 1.0],
              ),
            ),
            child: Icon(
              CupertinoIcons.time,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: GestureDetector(
            onTap: _planJourney,
            child: Container(
              height: 44.h,
              decoration: const BoxDecoration(
                color: AppColors.whiteAccent,
              ),
              child: Center(
                child: Text(
                  "Plan Journey",
                  style: TextStyle(
                    color: Colors.black,
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.h),
          child: const CupertinoActivityIndicator(color: Colors.white, radius: 14),
        ),
      );
    }

    if (_errorMessage != null) {
      return SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        child: Container(
          padding: EdgeInsets.all(16.h),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: AppColors.destructive.withValues(alpha: 0.25), width: 0.8),
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.exclamationmark_circle, color: AppColors.destructive, size: 24.sp),
                  SizedBox(height: 8.h),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.destructive,
                      fontFamily: 'Poppins',
                      fontSize: 13.sp,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  GestureDetector(
                    onTap: _planJourney,
                    child: Container(
                      height: 38.h,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: const BoxDecoration(
                        color: AppColors.whiteAccent,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(CupertinoIcons.refresh, size: 14.sp, color: Colors.black),
                          SizedBox(width: 8.w),
                          Text(
                            "Retry Search",
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_errorSubtitle != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Text(
                    _errorSubtitle!,
                    style: TextStyle(
                      color: AppColors.destructive.withValues(alpha: 0.4),
                      fontFamily: 'Poppins',
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (_routes.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w),
          child: Text(
            "Select start and destination to find optimal routes.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.tertiaryText,
              fontFamily: 'Poppins',
              fontSize: 13.sp,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 20.h),
      itemCount: _routes.length + 1,
      separatorBuilder: (context, index) {
        if (index == 0) return const SizedBox.shrink();
        return SizedBox(height: 10.h);
      },
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Text(
              "Recommended Routes",
              style: TextStyle(
                color: AppColors.secondaryText,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 14.sp,
              ),
            ),
          );
        }
        return RouteCard(
          route: _routes[index - 1],
          srcName: _srcName,
          dstName: _dstName,
        );
      },
    );
  }
}

// -------------------- ROUTE CARD COMPONENT --------------------

class RouteCard extends StatelessWidget {
  final JourneyRoute route;
  final String srcName;
  final String dstName;

  const RouteCard({
    super.key,
    required this.route,
    required this.srcName,
    required this.dstName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: const Color.fromARGB(58, 58, 58, 58),
          width: 0.8,
        ),
        gradient: const LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [
            Color.fromARGB(18, 0, 229, 255),
            Color.fromARGB(14, 41, 121, 255),
            Color.fromARGB(10, 213, 0, 249),
            Color.fromARGB(8, 255, 109, 0),
            Color.fromARGB(2, 255, 109, 0),
          ],
          stops: [0.0, 0.25, 0.55, 0.8, 1.0],
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JourneyDetailsScreen(
                route: route,
                srcName: srcName,
                dstName: dstName,
              ),
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.clock_solid, color: Colors.white, size: 14.sp),
                      SizedBox(width: 4.w),
                      Text(
                        "${route.tripTime.toInt()} min",
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Reach by: ${route.reachBy}",
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              // Render badges for the legs
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6.w,
                runSpacing: 4.h,
                children: _buildLegBadges(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLegBadges() {
    final List<Widget> widgets = [];
    final legs = route.legs;

    for (int i = 0; i < legs.length; i++) {
      final leg = legs[i];
      final isWalk = leg.type.toLowerCase() == 'walk';
      final colorStr = leg.color.replaceAll('#', '0xFF');
      final badgeColor = Color(int.tryParse(colorStr) ?? 0xFFF8CA35);

      if (isWalk) {
        widgets.add(
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: AppColors.divider, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.directions_walk,
                  color: AppColors.secondaryText,
                  size: 11.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  "${leg.tripTime}m",
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w600,
                    fontSize: 10.sp,
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        widgets.add(
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: AppColors.divider, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 4.w,
                  height: 18.h,
                  color: badgeColor,
                ),
                SizedBox(width: 6.w),
                Icon(
                  CupertinoIcons.bus,
                  color: Colors.white,
                  size: 11.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  leg.routes.isNotEmpty ? leg.routes.first : leg.type.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w700,
                    fontSize: 10.sp,
                  ),
                ),
                SizedBox(width: 6.w),
              ],
            ),
          ),
        );
      }

      if (i < legs.length - 1) {
        widgets.add(
          Icon(CupertinoIcons.chevron_right, color: AppColors.tertiaryText, size: 10.sp),
        );
      }
    }

    return widgets;
  }
}

// -------------------- STOP SELECTOR MODAL --------------------

class StopSelectorModal extends StatefulWidget {
  final List<dynamic> allStops;
  final bool allowCurrentLocation;
  final Function(String name, double lat, double lon, String type) onSelect;

  const StopSelectorModal({
    super.key,
    required this.allStops,
    required this.allowCurrentLocation,
    required this.onSelect,
  });

  @override
  State<StopSelectorModal> createState() => _StopSelectorModalState();
}

class _StopSelectorModalState extends State<StopSelectorModal> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _filteredStops = [];

  @override
  void initState() {
    super.initState();
    _filteredStops = widget.allStops;
  }

  void _filterStops(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _filteredStops = widget.allStops;
      });
      return;
    }

    setState(() {
      _filteredStops = widget.allStops.where((stop) {
        final name = (stop['Name']?.toString() ?? '').toLowerCase();
        final hindi = (stop['Hindi']?.toString() ?? '').toLowerCase();
        return name.contains(q) || hindi.contains(q);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      padding: EdgeInsets.only(
        top: 10.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10.h,
      ),
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 12.h),
          // Search Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14.w),
            child: Container(
              height: 44.h,
              decoration: BoxDecoration(
                color: AppColors.foreground,
                border: Border.all(color: AppColors.inputBorder, width: 0.8),
              ),
              child: Row(
                children: [
                  SizedBox(width: 10.w),
                  Icon(CupertinoIcons.search, color: AppColors.secondaryText, size: 18.sp),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _filterStops,
                      autofocus: true,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 14.sp,
                      ),
                      decoration: const InputDecoration.collapsed(
                        hintText: "Search bus or metro station...",
                        hintStyle: TextStyle(
                          color: AppColors.tertiaryText,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _filterStops('');
                      },
                      child: Padding(
                        padding: EdgeInsets.all(8.h),
                        child: Icon(CupertinoIcons.clear_thick, color: Colors.white, size: 14.sp),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 8.h),
          // List
          Expanded(
            child: ListView.separated(
              itemCount: _filteredStops.length + (widget.allowCurrentLocation ? 1 : 0),
              separatorBuilder: (context, index) => const Divider(color: AppColors.divider, height: 1),
              itemBuilder: (context, index) {
                if (widget.allowCurrentLocation && index == 0) {
                  return ListTile(
                    leading: Icon(CupertinoIcons.location, color: AppColors.primaryAccent, size: 20.sp),
                    title: Text(
                      "Current Location",
                      style: TextStyle(
                        color: AppColors.primaryAccent,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 13.sp,
                      ),
                    ),
                    onTap: () {
                      widget.onSelect("My Location", 0.0, 0.0, 'place');
                      Navigator.pop(context);
                    },
                  );
                }

                final stopIndex = widget.allowCurrentLocation ? index - 1 : index;
                final stop = _filteredStops[stopIndex];
                final name = stop['Name']?.toString() ?? 'Unknown Stop';
                final hindi = stop['Hindi']?.toString() ?? '';
                final lat = double.tryParse(stop['Latitude']?.toString() ?? '') ?? 0.0;
                final lon = double.tryParse(stop['Longitude']?.toString() ?? '') ?? 0.0;

                // Infer stop type based on Line
                final line = stop['Line']?.toString() ?? '';
                final type = line.isNotEmpty && line.toLowerCase().contains('metro') ? 'metro' : 'bus';

                return ListTile(
                  title: Text(
                    name,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                      fontSize: 13.sp,
                    ),
                  ),
                  subtitle: hindi.isNotEmpty
                      ? Text(
                          hindi,
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontFamily: 'Poppins',
                            fontSize: 11.sp,
                          ),
                        )
                      : null,
                  onTap: () {
                    widget.onSelect(name, lat, lon, type);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
