import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:metroapp/elements/ServicesDir/data_provider.dart';
import 'package:metroapp/elements/ServicesDir/journey_planner_service.dart';
import 'package:metroapp/elements/ServicesDir/geolocator_service.dart' as geo_service;
import 'package:metroapp/main.dart';
import 'package:metroapp/elements/journey_details.dart';
import 'package:metroapp/elements/ServicesDir/stops_manager.dart';


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
  double _turns = 0.0;

  // Controllers and Focus Nodes for inline searching
  late final TextEditingController _srcController;
  late final TextEditingController _dstController;
  late final FocusNode _srcFocusNode;
  late final FocusNode _dstFocusNode;

  bool _isFocusingSource = false;
  bool _isFocusingDestination = false;

  @override
  void initState() {
    super.initState();
    _srcController = TextEditingController(text: _srcName);
    _dstController = TextEditingController(text: _dstName);
    _srcFocusNode = FocusNode();
    _dstFocusNode = FocusNode();

    _srcFocusNode.addListener(() {
      setState(() {
        _isFocusingSource = _srcFocusNode.hasFocus;
      });
    });

    _dstFocusNode.addListener(() {
      setState(() {
        _isFocusingDestination = _dstFocusNode.hasFocus;
      });
    });

    _loadStops();

    if (widget.initialParams != null) {
      _applyInitialParams(widget.initialParams!);
    } else {
      _useCurrentLocation();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _dstFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _srcController.dispose();
    _dstController.dispose();
    _srcFocusNode.dispose();
    _dstFocusNode.dispose();
    super.dispose();
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

      _srcController.text = _srcName;
      _dstController.text = _dstName;
    });

    if (_srcLat == null || _srcLon == null) {
      _useCurrentLocation();
    } else {
      // Automatically trigger search
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _planJourney();
      });
    }
  }

  Future<void> _loadStops() async {
    try {
      final stops = StopsManager.getStations();
      if (mounted) {
        setState(() {
          _allStops = stops;
        });
      }
    } catch (e) {
      debugPrint('Error loading stops in planner: $e');
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() {
      _srcName = 'Loading current location...';
      _srcController.text = _srcName;
    });
    try {
      final position = await geo_service.getCurrentLocation();
      final lat = position.latitude;
      final lon = position.longitude;

      if (lat >= 28.0 && lat <= 29.2 && lon >= 76.5 && lon <= 77.8) {
        if (mounted) {
          setState(() {
            _srcName = 'My Location';
            _srcController.text = _srcName;
            _srcLat = lat;
            _srcLon = lon;
            _srcType = 'place';
          });
          _checkAndAutoSearch();
        }
      } else {
        if (mounted) {
          setState(() {
            _srcName = '';
            _srcController.text = '';
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
          _srcController.text = '';
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
      _turns += 0.5;
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

      _srcController.text = _srcName;
      _dstController.text = _dstName;
    });

    _checkAndAutoSearch();
  }

  void _checkAndAutoSearch() {
    if (_srcLat != null && _srcLon != null && _dstLat != null && _dstLon != null) {
      _srcFocusNode.unfocus();
      _dstFocusNode.unfocus();
      _planJourney();
    }
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
      _checkAndAutoSearch();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBackBox(context),
                  _buildScreenTitle(),
                  _buildInputsCard(),
                  SizedBox(height: 4.h),
                  Divider(
                    color: AppColors.divider,
                    thickness: 0.2,
                    height: 4.h,
                  ),
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

  Widget _buildBackBox(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Transform.translate(
          offset: Offset(-8.w, 0),
          child: BackButton(
            color: AppColors.primaryAccent,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScreenTitle() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Text(
        "Plan Journey",
        style: TextStyle(
          color: AppColors.primaryText,
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildInputsCard() {
    return Container(
      padding: EdgeInsets.zero,
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Source (departure) input + Clock button on the right
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44.h,
                      decoration: const BoxDecoration(
                        color: AppColors.whiteAccent,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 12.w),
                          Icon(
                            CupertinoIcons.circle,
                            color: Colors.black,
                            size: 16.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: TextField(
                              controller: _srcController,
                              focusNode: _srcFocusNode,
                              style: TextStyle(
                                color: Colors.black,
                                fontFamily: 'Poppins',
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Choose starting point...',
                                hintStyle: TextStyle(
                                  color: AppColors.tertiaryText,
                                  fontFamily: 'Poppins',
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 10),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _srcName = val;
                                  if (val.isEmpty) {
                                    _srcLat = null;
                                    _srcLon = null;
                                  }
                                });
                              },
                            ),
                          ),
                          if (_srcController.text.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _srcController.clear();
                                  _srcName = '';
                                  _srcLat = null;
                                  _srcLon = null;
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10.w),
                                child: Icon(
                                  CupertinoIcons.clear_thick_circled,
                                  color: AppColors.tertiaryText,
                                  size: 16.sp,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 4.w),
                  // Time Set Logo (Clock button)
                  GestureDetector(
                    onTap: _selectTime,
                    child: Container(
                      width: 44.h,
                      height: 44.h,
                      decoration: const BoxDecoration(
                        color: AppColors.whiteAccent,
                        borderRadius: BorderRadius.zero,
                      ),
                      child: Icon(
                        CupertinoIcons.time,
                        color: Colors.black,
                        size: 20.sp,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              // Row 2: Destination input (Full width)
              Container(
                height: 44.h,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.whiteAccent,
                  borderRadius: BorderRadius.zero,
                ),
                child: Row(
                  children: [
                    SizedBox(width: 12.w),
                    Icon(
                      CupertinoIcons.square,
                      color: Colors.black,
                      size: 16.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        controller: _dstController,
                        focusNode: _dstFocusNode,
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Poppins',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Choose destination...',
                          hintStyle: TextStyle(
                            color: AppColors.tertiaryText,
                            fontFamily: 'Poppins',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _dstName = val;
                            if (val.isEmpty) {
                              _dstLat = null;
                              _dstLon = null;
                            }
                          });
                        },
                      ),
                    ),
                    if (_dstController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _dstController.clear();
                            _dstName = '';
                            _dstLat = null;
                            _dstLon = null;
                          });
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10.w),
                          child: Icon(
                            CupertinoIcons.clear_thick_circled,
                            color: AppColors.tertiaryText,
                            size: 16.sp,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          // Z-Axis Centered Flip Button
          Positioned(
            left: 0,
            right: 0,
            top: 30.h, // Centered in the 4.h gap between Row 1 (44.h) and Row 2 (44.h)
            child: Center(
              child: GestureDetector(
                onTap: _swapLocations,
                child: Container(
                  width: 32.h,
                  height: 32.h,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color.fromARGB(100, 58, 58, 58),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: AnimatedRotation(
                    turns: _turns,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeInOutBack,
                    child: Icon(
                      CupertinoIcons.arrow_up_down,
                      color: Colors.white,
                      size: 14.sp,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<dynamic> _getFilteredStops(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return _allStops;
    }
    return _allStops.where((stop) {
      final name = (stop['Name']?.toString() ?? '').toLowerCase();
      final hindi = (stop['Hindi']?.toString() ?? '').toLowerCase();
      return name.contains(q) || hindi.contains(q);
    }).toList();
  }

  Widget _buildAutocompleteList(String query) {
    final filtered = _getFilteredStops(query);
    final bool isSource = _isFocusingSource;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 10.h),
      itemCount: filtered.length + (isSource ? 1 : 0),
      separatorBuilder: (context, index) => const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        if (isSource && index == 0) {
          return ListTile(
            contentPadding: EdgeInsets.zero,
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
              _useCurrentLocation();
            },
          );
        }

        final stopIndex = isSource ? index - 1 : index;
        final stop = filtered[stopIndex];
        final name = stop['Name']?.toString() ?? 'Unknown Stop';
        final hindi = stop['Hindi']?.toString() ?? '';
        final lat = double.tryParse(stop['Latitude']?.toString() ?? '') ?? 0.0;
        final lon = double.tryParse(stop['Longitude']?.toString() ?? '') ?? 0.0;

        return ListTile(
          contentPadding: EdgeInsets.zero,
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
            setState(() {
              if (isSource) {
                _srcName = name;
                _srcLat = lat;
                _srcLon = lon;
                _srcType = 'place';
                _srcController.text = name;
                if (_dstLat == null || _dstLon == null) {
                  _dstFocusNode.requestFocus();
                } else {
                  _srcFocusNode.unfocus();
                }
              } else {
                _dstName = name;
                _dstLat = lat;
                _dstLon = lon;
                _dstType = 'place';
                _dstController.text = name;
                if (_srcLat == null || _srcLon == null) {
                  _srcFocusNode.requestFocus();
                } else {
                  _dstFocusNode.unfocus();
                }
              }
            });

            _checkAndAutoSearch();
          },
        );
      },
    );
  }

  Widget _buildHistoryList() {
    final history = Provider.of<DataProvider>(context).journeySearchHistory;
    if (history.isEmpty) {
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
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 10.h),
      itemCount: history.length,
      separatorBuilder: (context, index) => const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final item = history[index];
        final src = item['src_name'] ?? '';
        final dst = item['dst_name'] ?? '';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.history, color: AppColors.secondaryText, size: 18.sp),
          title: Text(
            "$src ➔ $dst",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 13.sp,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            _srcFocusNode.unfocus();
            _dstFocusNode.unfocus();
            _applyInitialParams(item);
          },
        );
      },
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

    if (_isFocusingSource || _isFocusingDestination) {
      final query = _isFocusingSource ? _srcController.text : _dstController.text;
      if (query.isEmpty) {
        return _buildHistoryList();
      } else {
        return _buildAutocompleteList(query);
      }
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
      return _buildHistoryList();
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 20.h),
      itemCount: _routes.length + 1,
      separatorBuilder: (context, index) {
        if (index == 0) return const SizedBox.shrink();
        return SizedBox(height: 5.h);
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
    final transitLegsCount = route.legs.where((leg) => leg.type.toLowerCase() != 'walk').length;
    final interchangeCount = transitLegsCount > 1 ? transitLegsCount - 1 : 0;
    final interchangeText = interchangeCount == 0 ? "Direct" : "$interchangeCount interchange${interchangeCount > 1 ? 's' : ''}";

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
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 18.h),
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
                      SizedBox(width: 10.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: AppColors.divider.withValues(alpha: 0.15),
                          border: Border.all(color: AppColors.divider, width: 0.6),
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                        child: Text(
                          "by ${route.reachBy}",
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontFamily: 'Poppins',
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    interchangeText,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
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
          Padding(
            padding: EdgeInsets.symmetric(vertical: 3.h),
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
