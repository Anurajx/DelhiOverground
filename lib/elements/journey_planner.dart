import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:metroapp/elements/ServicesDir/data_provider.dart';
import 'package:metroapp/elements/ServicesDir/journey_planner_service.dart';
import 'package:metroapp/elements/ServicesDir/geolocator_service.dart'
    as geo_service;
import 'package:metroapp/main.dart';
import 'package:metroapp/elements/journey_details.dart';
import 'package:metroapp/elements/ServicesDir/stops_manager.dart';
import 'package:metroapp/elements/ServicesDir/analytics_service.dart';

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

  // Nominatim state variables
  List<dynamic> _nominatimSuggestions = [];
  bool _isNominatimLoading = false;
  Timer? _debounceTimer;
  http.Client? _activeClient;
  int _currentRequestId = 0;

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreenViewed('Journey Planner');
    _srcController = TextEditingController(text: _srcName);
    _dstController = TextEditingController(text: _dstName);
    _srcFocusNode = FocusNode();
    _dstFocusNode = FocusNode();

    _srcFocusNode.addListener(() {
      setState(() {
        _isFocusingSource = _srcFocusNode.hasFocus;
      });
      if (_srcFocusNode.hasFocus) {
        _onSearchChanged(_srcController.text);
      }
    });

    _dstFocusNode.addListener(() {
      setState(() {
        _isFocusingDestination = _dstFocusNode.hasFocus;
      });
      if (_dstFocusNode.hasFocus) {
        _onSearchChanged(_dstController.text);
      }
    });

    _loadStops();

    if (widget.initialParams != null) {
      _applyInitialParams(widget.initialParams!);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _srcFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _activeClient?.close();
    _srcController.dispose();
    _dstController.dispose();
    _srcFocusNode.dispose();
    _dstFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();

    if (val.trim().isEmpty) {
      _activeClient?.close();
      setState(() {
        _nominatimSuggestions = [];
        _isNominatimLoading = false;
      });
      return;
    }

    if (val.trim().length < 3) {
      _activeClient?.close();
      setState(() {
        _nominatimSuggestions = [];
        _isNominatimLoading = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _fetchNominatimSuggestions(val.trim());
    });
  }

  Future<void> _fetchNominatimSuggestions(String text) async {
    // Cancel any pending request
    _activeClient?.close();
    _activeClient = http.Client();
    final requestId = ++_currentRequestId;

    setState(() {
      _isNominatimLoading = true;
    });

    try {
      final encodedText = Uri.encodeComponent(text);
      final url =
          'https://nominatim.openstreetmap.org/search?q=$encodedText&format=jsonv2&addressdetails=1&viewbox=76.70,29.15,77.85,28.05&bounded=1&limit=3';

      final response = await _activeClient!.get(
        Uri.parse(url),
        headers: {'User-Agent': 'DelhiOvergroundApp/1.0'},
      );

      if (requestId != _currentRequestId) return; // Ignore outdated responses

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);

        setState(() {
          _nominatimSuggestions = data.take(3).toList();
          _isNominatimLoading = false;
        });
      } else {
        setState(() {
          _isNominatimLoading = false;
        });
      }
    } catch (e) {
      if (requestId == _currentRequestId) {
        setState(() {
          _isNominatimLoading = false;
        });
      }
    }
  }

  void _applyInitialParams(Map<String, String> params) {
    List<JourneyRoute> cachedRoutes = [];
    final routesJson = params['routes_json'];
    if (routesJson != null && routesJson.isNotEmpty) {
      try {
        final List<dynamic> decodedList = jsonDecode(routesJson);
        cachedRoutes =
            decodedList
                .map((e) => JourneyRoute.fromJson(e as Map<String, dynamic>))
                .toList();
      } catch (e) {
        debugPrint('Error parsing cached routes from history: $e');
      }
    }

    setState(() {
      _srcName = params['src_name'] ?? '';
      _srcLat = double.tryParse(params['src_lat'] ?? '');
      _srcLon = double.tryParse(params['src_lon'] ?? '');
      _srcType = params['src_type'] ?? 'place';

      _dstName = params['dst_name'] ?? '';
      _dstLat = double.tryParse(params['dst_lat'] ?? '');
      _dstLon = double.tryParse(params['dst_lon'] ?? '');
      _dstType = params['dst_type'] ?? 'place';

      _selectedMode = params['mode'] ?? 'bus';

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

      if (cachedRoutes.isNotEmpty) {
        _routes = cachedRoutes;
        _isLoading = false;
        _errorMessage = null;
      }
    });

    if (cachedRoutes.isNotEmpty) {
      // Results restored directly from cached history! No network fetch needed.
      return;
    }

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
    final bool targetIsSource = !_isFocusingDestination;

    setState(() {
      if (targetIsSource) {
        _srcName = 'Loading current location...';
        _srcController.text = _srcName;
      } else {
        _dstName = 'Loading current location...';
        _dstController.text = _dstName;
      }
    });

    try {
      final position = await geo_service.getCurrentLocation();
      final lat = position.latitude;
      final lon = position.longitude;

      if (lat >= 28.0 && lat <= 29.2 && lon >= 76.5 && lon <= 77.8) {
        if (mounted) {
          setState(() {
            if (targetIsSource) {
              _srcName = 'My Location';
              _srcController.text = _srcName;
              _srcLat = lat;
              _srcLon = lon;
              _srcType = 'place';
              if (_dstLat == null || _dstLon == null) {
                _dstFocusNode.requestFocus();
              }
            } else {
              _dstName = 'My Location';
              _dstController.text = _dstName;
              _dstLat = lat;
              _dstLon = lon;
              _dstType = 'place';
              if (_srcLat == null || _srcLon == null) {
                _srcFocusNode.requestFocus();
              }
            }
          });
          _checkAndAutoSearch();
        }
      } else {
        if (mounted) {
          setState(() {
            if (targetIsSource) {
              _srcName = '';
              _srcController.text = '';
              _srcLat = null;
              _srcLon = null;
            } else {
              _dstName = '';
              _dstController.text = '';
              _dstLat = null;
              _dstLon = null;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Location is outside Delhi NCR. Please select manually.',
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
          if (targetIsSource) {
            _srcName = '';
            _srcController.text = '';
            _srcLat = null;
            _srcLon = null;
          } else {
            _dstName = '';
            _dstController.text = '';
            _dstLat = null;
            _dstLon = null;
          }
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
    PostHogService.trackButtonClicked('swap_endpoints');
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
    if (_srcLat != null &&
        _srcLon != null &&
        _dstLat != null &&
        _dstLon != null) {
      _srcFocusNode.unfocus();
      _dstFocusNode.unfocus();
      _planJourney();
    }
  }

  Future<void> _selectTime() async {
    final now = DateTime.now();
    DateTime tempDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) {
        return Material(
          color: AppColors.background,
          child: SizedBox(
            height: 280.h,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    color: AppColors.surface,
                    height: 44.h,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedTime = TimeOfDay(
                                hour: tempDateTime.hour,
                                minute: tempDateTime.minute,
                              );
                            });
                            _checkAndAutoSearch();
                            Navigator.pop(context);
                          },
                          child: Text(
                            'Done',
                            style: TextStyle(
                              color: AppColors.primaryAccent,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: CupertinoTheme(
                      data: const CupertinoThemeData(
                        brightness: Brightness.dark,
                        textTheme: CupertinoTextThemeData(
                          dateTimePickerTextStyle: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.time,
                        initialDateTime: tempDateTime,
                        onDateTimeChanged: (DateTime newDateTime) {
                          tempDateTime = newDateTime;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final hr = tod.hour.toString().padLeft(2, '0');
    final min = tod.minute.toString().padLeft(2, '0');
    return '$hr:$min:00';
  }

  Future<Map<String, double>?> _geocodeAddress(String address) async {
    try {
      final encodedText = Uri.encodeComponent(address);
      final url =
          'https://nominatim.openstreetmap.org/search?q=$encodedText&format=jsonv2&addressdetails=1&viewbox=76.70,29.15,77.85,28.05&bounded=1&limit=3';
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'User-Agent': 'DelhiOvergroundApp/1.0'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final first = data[0];
          final lat = double.tryParse(first['lat']?.toString() ?? '');
          final lon = double.tryParse(first['lon']?.toString() ?? '');
          if (lat != null && lon != null) {
            return {'lat': lat, 'lon': lon};
          }
        }
      }
    } catch (e) {
      debugPrint('Geocoding error: $e');
    }
    return null;
  }

  Future<void> _planJourney() async {
    if (_srcController.text.trim().isEmpty ||
        _dstController.text.trim().isEmpty) {
      PostHogService.trackValidationError(
        'journey_input',
        'Please select both start and end locations.',
      );
      setState(() {
        _errorMessage = 'Please select both start and end locations.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _routes = [];
    });

    try {
      if (_srcLat == null || _srcLon == null) {
        final resolved = await _geocodeAddress(_srcController.text);
        if (resolved != null) {
          setState(() {
            _srcLat = resolved['lat'];
            _srcLon = resolved['lon'];
            _srcName = _srcController.text;
            _srcType = 'place';
          });
        } else {
          PostHogService.trackValidationError(
            'src_location',
            'Could not resolve starting point: ${_srcController.text}',
          );
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Could not resolve starting point: ${_srcController.text}';
          });
          return;
        }
      }

      if (_dstLat == null || _dstLon == null) {
        final resolved = await _geocodeAddress(_dstController.text);
        if (resolved != null) {
          setState(() {
            _dstLat = resolved['lat'];
            _dstLon = resolved['lon'];
            _dstName = _dstController.text;
            _dstType = 'place';
          });
        } else {
          PostHogService.trackValidationError(
            'dst_location',
            'Could not resolve destination: ${_dstController.text}',
          );
          setState(() {
            _isLoading = false;
            _errorMessage =
                'Could not resolve destination: ${_dstController.text}';
          });
          return;
        }
      }

      if (_srcLat == 0.0 ||
          _srcLon == 0.0 ||
          _dstLat == 0.0 ||
          _dstLon == 0.0) {
        PostHogService.trackValidationError(
          'coordinates',
          'Invalid coordinates. Please select locations again.',
        );
        setState(() {
          _isLoading = false;
          _errorMessage = 'Invalid coordinates. Please select locations again.';
        });
        return;
      }

      if (_srcLat! < 28.0 ||
          _srcLat! > 29.2 ||
          _srcLon! < 76.5 ||
          _srcLon! > 77.8 ||
          _dstLat! < 28.0 ||
          _dstLat! > 29.2 ||
          _dstLon! < 76.5 ||
          _dstLon! > 77.8) {
        PostHogService.trackValidationError(
          'bounds',
          'Journey planner is only available within Delhi NCR. Please select locations within the service area.',
        );
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Journey planner is only available within Delhi NCR. Please select locations within the service area.';
        });
        return;
      }

      final timeStr = _formatTimeOfDay(_selectedTime);

      PostHogService.trackSearchPerformed(
        'journey_search',
        '${_srcController.text} to ${_dstController.text}',
      );
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
          if (result.isEmpty) {
            _errorMessage = 'could not find viable route';
            PostHogService.trackValidationError(
              'journey_results',
              'could not find viable route',
            );
          } else {
            _errorMessage = null;
          }
        });

        if (result.isNotEmpty) {
          // Save to search history provider with cached routes JSON
          final routesJson = jsonEncode(result.map((r) => r.toJson()).toList());
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
            routesJson: routesJson,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'could not find viable route';
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
            Expanded(child: _buildResultsSection()),
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
              PostHogService.trackButtonClicked('back_button');
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
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Source (departure) input (Full width)
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
                      CupertinoIcons.circle,
                      color: Colors.black,
                      size: 16.sp,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        controller: _srcController,
                        focusNode: _srcFocusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _planJourney(),
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Poppins',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'From',
                          hintStyle: TextStyle(
                            color: AppColors.secondaryText,
                            fontFamily: 'Poppins',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
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
                          _onSearchChanged(val);
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
                            _nominatimSuggestions = [];
                            _isNominatimLoading = false;
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
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _planJourney(),
                        style: TextStyle(
                          color: Colors.black,
                          fontFamily: 'Poppins',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'To',
                          hintStyle: TextStyle(
                            color: AppColors.secondaryText,
                            fontFamily: 'Poppins',
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
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
                          _onSearchChanged(val);
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
                            _nominatimSuggestions = [];
                            _isNominatimLoading = false;
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
              _buildYourLocationPill(),
            ],
          ),
          // Z-Axis Centered Flip Button
          Positioned(
            left: 0,
            right: 0,
            top:
                30.h, // Centered in the 4.h gap between Row 1 (44.h) and Row 2 (44.h)
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

  String _formatTimeOfDayDisplay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Widget _buildYourLocationPill() {
    final bool showPill =
        _routes.isEmpty || _isFocusingSource || _isFocusingDestination;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      opacity: showPill ? 1.0 : 0.0,
      curve: Curves.easeInOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        height: showPill ? 34.h : 0.0,
        margin: EdgeInsets.only(top: showPill ? 8.h : 0.0),
        child: ClipRect(
          child: OverflowBox(
            minHeight: 0.0,
            maxHeight: 34.h,
            alignment: Alignment.topLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSplitPill(
                  icon: CupertinoIcons.location_solid,
                  text: "your location",
                  onTap: showPill ? _useCurrentLocation : null,
                ),
                SizedBox(width: 8.w),
                _buildSplitPill(
                  icon: CupertinoIcons.time_solid,
                  text: _formatTimeOfDayDisplay(_selectedTime),
                  onTap: showPill ? _selectTime : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSplitPill({
    required IconData icon,
    required String text,
    required VoidCallback? onTap,
  }) {
    const greenColor = AppColors.secondaryAccent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: greenColor, width: 1.0),
          borderRadius: BorderRadius.circular(20.r),
        ),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w),
                alignment: Alignment.center,
                color: greenColor,
                child: Icon(icon, color: Colors.black, size: 13.sp),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                child: Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
    final filteredStops = _getFilteredStops(query);
    final bool isSource = _isFocusingSource;

    final stops = filteredStops.take(2).toList();
    final locations = _nominatimSuggestions.take(3).toList();

    final List<Map<String, dynamic>> items = [];

    for (final stop in stops) {
      items.add({'type': 'stop', 'data': stop});
    }

    if (_isNominatimLoading && locations.isEmpty) {
      items.add({'type': 'loading'});
    }

    for (final suggestion in locations) {
      items.add({'type': 'location', 'data': suggestion});
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 20.h),
          child: Text(
            "No suggestions found.",
            style: TextStyle(
              color: AppColors.tertiaryText,
              fontFamily: 'Poppins',
              fontSize: 13.sp,
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 10.h),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item['type'] == 'loading') {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: Row(
              children: [
                const CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: 8,
                ),
                SizedBox(width: 8.w),
                Text(
                  "Searching locations...",
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontFamily: 'Poppins',
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          );
        } else if (item['type'] == 'stop') {
          final stop = item['data'];
          final name = stop['Name']?.toString() ?? 'Unknown Stop';
          final hindi = stop['Hindi']?.toString() ?? '';
          final lat =
              double.tryParse(stop['Latitude']?.toString() ?? '') ?? 0.0;
          final lon =
              double.tryParse(stop['Longitude']?.toString() ?? '') ?? 0.0;

          return _buildStopListTile(
            title: name,
            subtitle: hindi,
            isSource: isSource,
            lat: lat,
            lon: lon,
            icon: CupertinoIcons.bus,
          );
        } else if (item['type'] == 'location') {
          final suggestion = item['data'];
          final name = suggestion['name'] ?? 'Unknown Location';
          final displayName = suggestion['display_name'] ?? '';
          final lat =
              double.tryParse(suggestion['lat']?.toString() ?? '') ?? 0.0;
          final lon =
              double.tryParse(suggestion['lon']?.toString() ?? '') ?? 0.0;

          return _buildStopListTile(
            title: name.toString(),
            subtitle: displayName.toString(),
            isSource: isSource,
            lat: lat,
            lon: lon,
            icon: CupertinoIcons.location_solid,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildStopListTile({
    required String title,
    required String subtitle,
    required bool isSource,
    required double lat,
    required double lon,
    required IconData icon,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: AppColors.secondaryText, size: 16.sp),
          title: Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
              fontSize: 13.sp,
            ),
          ),
          subtitle:
              subtitle.isNotEmpty
                  ? Text(
                    subtitle,
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
                _srcName = title;
                _srcLat = lat;
                _srcLon = lon;
                _srcType = 'place';
                _srcController.text = title;
                _nominatimSuggestions = [];
                _isNominatimLoading = false;
                if (_dstLat == null || _dstLon == null) {
                  _dstFocusNode.requestFocus();
                } else {
                  _srcFocusNode.unfocus();
                }
              } else {
                _dstName = title;
                _dstLat = lat;
                _dstLon = lon;
                _dstType = 'place';
                _dstController.text = title;
                _nominatimSuggestions = [];
                _isNominatimLoading = false;
                if (_srcLat == null || _srcLon == null) {
                  _srcFocusNode.requestFocus();
                } else {
                  _dstFocusNode.unfocus();
                }
              }
            });

            _checkAndAutoSearch();
          },
        ),
        const Divider(color: AppColors.divider, height: 1),
      ],
    );
  }

  Widget _buildHistoryList() {
    var history = Provider.of<DataProvider>(context).journeySearchHistory;

    if (_isFocusingDestination &&
        _dstController.text.isEmpty &&
        _srcController.text.isNotEmpty) {
      final srcVal = _srcController.text.toLowerCase().trim();
      history =
          history.where((item) {
            final itemSrc = (item['src_name'] ?? '').toLowerCase().trim();
            return itemSrc == srcVal;
          }).toList();
      if (history.isEmpty) {
        return const SizedBox.shrink();
      }
    } else if (_isFocusingSource &&
        _srcController.text.isEmpty &&
        _dstController.text.isNotEmpty) {
      final dstVal = _dstController.text.toLowerCase().trim();
      history =
          history.where((item) {
            final itemDst = (item['dst_name'] ?? '').toLowerCase().trim();
            return itemDst == dstVal;
          }).toList();
      if (history.isEmpty) {
        return const SizedBox.shrink();
      }
    }

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
      separatorBuilder:
          (context, index) =>
              const Divider(color: AppColors.divider, height: 1),
      itemBuilder: (context, index) {
        final item = history[index];
        final src = item['src_name'] ?? '';
        final dst = item['dst_name'] ?? '';

        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            Icons.history,
            color: AppColors.secondaryText,
            size: 18.sp,
          ),
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
          child: const CupertinoActivityIndicator(
            color: Colors.white,
            radius: 14,
          ),
        ),
      );
    }

    if (_isFocusingSource || _isFocusingDestination) {
      final query =
          _isFocusingSource ? _srcController.text : _dstController.text;
      if (query.isEmpty) {
        return _buildHistoryList();
      } else {
        return _buildAutocompleteList(query);
      }
    }

    if (_errorMessage != null) {
      final isNoRouteError = _errorMessage == 'could not find viable route';
      return Container(
        padding: EdgeInsets.only(top: 80.h, left: 24.w, right: 24.w),
        alignment: Alignment.topCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isNoRouteError) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3.r),
                child: Image.asset(
                  'assets/Image/dtcaccident.png',
                  height: 100.h,
                  fit: BoxFit.contain,
                ),
              ),
              SizedBox(height: 16.h),
            ] else ...[
              Icon(
                CupertinoIcons.exclamationmark_circle_fill,
                color: AppColors.destructive,
                size: 28.sp,
              ),
              SizedBox(height: 10.h),
            ],
            Text(
              isNoRouteError ? '${_errorMessage!} :(' : _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    isNoRouteError
                        ? AppColors.primaryAccent
                        : AppColors.destructive,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      );
    }

    if (_routes.isEmpty) {
      if (_srcController.text.isEmpty && _dstController.text.isEmpty) {
        return _buildHistoryList();
      } else {
        return const SizedBox.shrink();
      }
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 20.h),
      itemCount: _routes.length,
      separatorBuilder: (context, index) => SizedBox(height: 5.h),
      itemBuilder: (context, index) {
        return RouteCard(
          route: _routes[index],
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
    final transitLegsCount =
        route.legs.where((leg) => leg.type.toLowerCase() != 'walk').length;
    final interchangeCount = transitLegsCount > 1 ? transitLegsCount - 1 : 0;
    final interchangeText =
        interchangeCount == 0
            ? "Direct"
            : "$interchangeCount interchange${interchangeCount > 1 ? 's' : ''}";

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
          PostHogService.trackButtonClicked('select_route_card', {
            'fare': route.totalFare,
            'duration_min': route.tripTime,
          });
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => JourneyDetailsScreen(
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
                      Icon(
                        CupertinoIcons.clock_solid,
                        color: Colors.white,
                        size: 14.sp,
                      ),
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
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.divider.withValues(alpha: 0.15),
                          border: Border.all(
                            color: AppColors.divider,
                            width: 0.6,
                          ),
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
                Container(width: 4.w, height: 18.h, color: badgeColor),
                SizedBox(width: 6.w),
                Icon(CupertinoIcons.bus, color: Colors.white, size: 11.sp),
                SizedBox(width: 4.w),
                Text(
                  leg.routes.isNotEmpty
                      ? leg.routes.first
                      : leg.type.toUpperCase(),
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
          Icon(
            CupertinoIcons.chevron_right,
            color: AppColors.tertiaryText,
            size: 10.sp,
          ),
        );
      }
    }

    return widgets;
  }
}
