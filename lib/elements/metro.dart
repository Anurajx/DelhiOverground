import 'dart:ui';
import 'package:metroapp/elements/ServicesDir/geolocator_service.dart';
import 'package:metroapp/elements/StationDir/stop_info.dart';
import 'package:metroapp/main.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import './ServicesDir/station_element.dart';
import 'search.dart';
import 'StationDir/station_search.dart';
import 'ServicesDir/data_provider.dart';
import 'package:provider/provider.dart';
import 'journey_planner.dart';
import 'package:metroapp/elements/ServicesDir/stops_manager.dart';



class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Map<String, Map<String, dynamic>> _coreTransferStationsDictNE = {
    'Source': {},
  };
  final Map<String, Map<String, dynamic>> _coreTransferStationsDictN = {
    'Source': {},
  };
  bool _isRefreshing = false;

  Future<void> _refreshNearbyStations(DataProvider dataProvider) async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    dataProvider.updateCoreNearestStationsDict({});
    try {
      await initialize(context);
    } catch (e) {
      debugPrint("Error refreshing nearby stations: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => initialize(context));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      width: double.infinity,
      //padding: const EdgeInsets.fromLTRB(5, 0, 5, 0),
      child: Column(
        children: [
          Expanded(child: _buildAppFooter(context)),
          _buildSearchBar(context),
          _buildBusHistory(context),
          _buildNearYou(context),
          //const Divider(thickness: 0, color: Color.fromARGB(0, 35, 35, 35)),
          _buildTicketAndExit(context),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const JourneyPlannerScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        width: double.infinity,
        //height: 45.h,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(0),
            topRight: Radius.circular(0),
          ),
          color: AppColors.whiteAccent,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Plan Journey',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
                fontSize: 18.sp,
                color: AppColors.background,
              ),
            ),
            const Icon(CupertinoIcons.search, color: AppColors.background),
          ],
        ),
      ),
    );
  }


  Widget _buildBusHistory(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, dataProvider, child) {
        final history = dataProvider.journeySearchHistory;
        if (history.isEmpty) {
          return const SizedBox.shrink();
        }

        final items = history.take(2).toList();
        final List<Widget> children = [];
        for (int i = 0; i < items.length; i++) {
          final item = items[i];
          children.add(
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => JourneyPlannerScreen(
                          initialParams: item,
                        ),
                  ),
                );
              },
              child: _buildBusHistoryItem(context, item),
            ),
          );
          if (i < items.length - 1) {
            children.add(
              const Divider(
                color: AppColors.divider,
                thickness: 0.5,
                height: 1,
              ),
            );
          }
        }

        return Container(
          margin: const EdgeInsets.only(left: 2, right: 2, top: 1, bottom: 2),
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        );
      },
    );
  }

  Widget _buildBusHistoryItem(BuildContext context, Map<String, String> item) {
    final srcName = item['src_name'] ?? '';
    final dstName = item['dst_name'] ?? '';

    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
      child: Row(
        children: [
          Icon(CupertinoIcons.time, color: AppColors.tertiaryText, size: 20.sp),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "To $dstName",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryText,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2.h),
                Text(
                  "From $srcName",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.secondaryText,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_forward,
            color: AppColors.tertiaryText,
            size: 16.sp,
          ),
        ],
      ),
    );
  }


  Widget _buildNearYou(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(5),
      child: Consumer<DataProvider>(
        builder: (context, dataProvider, child) {
          final data = dataProvider.coreNearestStationsDict;
          if (data["Near"] != null && data["NearEnough"] != null) {
            _coreTransferStationsDictNE['Source'] = data["NearEnough"]![0];
            String lineNE = data["NearEnough"]![0]["Line"].toString();
            lineNE = lineNE.replaceAll(RegExp(r'[\[\]]'), '');
            List<String> lineNumbersNE = lineNE.split('-');

            _coreTransferStationsDictN['Source'] = data["Near"]![0];
            String lineN = data["Near"]![0]["Line"].toString();
            lineN = lineN.replaceAll(RegExp(r'[\[\]]'), '');
            List<String> lineNumbersN = lineN.split('-');

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Nearby",
                        style: TextStyle(
                          color: AppColors.tertiaryText,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                          letterSpacing: 1.0,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _refreshNearbyStations(dataProvider),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          child:
                              _isRefreshing
                                  ? SizedBox(
                                    width: 16.sp,
                                    height: 16.sp,
                                    child: const CupertinoActivityIndicator(
                                      radius: 8,
                                      color: AppColors.tertiaryText,
                                    ),
                                  )
                                  : Icon(
                                    CupertinoIcons.refresh,
                                    color: AppColors.tertiaryText,
                                    size: 16.sp,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => StopInfoScreen(
                              stationDict: _coreTransferStationsDictNE,
                            ),
                      ),
                    );
                  },
                  child: StationNearby(
                    name: data["NearEnough"]?[0]["Name"],
                    line: lineNumbersNE,
                  ),
                ),
                const Divider(
                  color: AppColors.divider,
                  thickness: 0.5,
                  height: 1,
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => StopInfoScreen(
                              stationDict: _coreTransferStationsDictN,
                            ),
                      ),
                    );
                  },
                  child: StationNearby(
                    name: data["Near"]?[0]["Name"],
                    line: lineNumbersN,
                  ),
                ),
              ],
            );
          } else {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4.h),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Nearby",
                        style: TextStyle(
                          color: AppColors.tertiaryText,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                          letterSpacing: 1.0,
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _refreshNearbyStations(dataProvider),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          child:
                              _isRefreshing
                                  ? SizedBox(
                                    width: 16.sp,
                                    height: 16.sp,
                                    child: const CupertinoActivityIndicator(
                                      radius: 8,
                                      color: AppColors.tertiaryText,
                                    ),
                                  )
                                  : Icon(
                                    CupertinoIcons.refresh,
                                    color: AppColors.tertiaryText,
                                    size: 16.sp,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Skeletonizer(
                  child: Column(
                    children: [
                      StationNearby(
                        name: "Loading Station Name / Subname",
                        line: [],
                      ),
                      Divider(
                        color: AppColors.divider,
                        thickness: 0.5,
                        height: 1,
                      ),
                      StationNearby(
                        name: "Loading Station Name / Subname",
                        line: [],
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildTicketAndExit(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60.h,
      margin: const EdgeInsets.all(5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      final whatsappUrl = Uri.parse(
                        'https://wa.me/+911123456789?text=Hi',
                      );
                      await launchUrl(whatsappUrl);
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.all(Radius.circular(80)),
                      ),
                      child: const Center(
                        child: Icon(
                          CupertinoIcons.tickets,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 5.w),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => const MapMetroScreen(),
                      //   ),
                      // );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.all(Radius.circular(80)),
                      ),
                      child: const Center(
                        child: Icon(CupertinoIcons.bus, color: Colors.white),
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
          SizedBox(width: 5.w),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.all(Radius.circular(80)),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StationSearchScreen(),
                    ),
                  );
                },
                child: Center(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(25, 0, 5, 0),
                        child: const Text(
                          "Stop",
                          style: TextStyle(
                            color: Color.fromARGB(255, 244, 244, 244),
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      DefaultTextStyle(
                        style: const TextStyle(
                          fontSize: 15.0,
                          fontFamily: 'Poppins',
                          color: Color.fromARGB(255, 194, 194, 194),
                          fontWeight: FontWeight.w500,
                        ),
                        child: AnimatedTextKit(
                          repeatForever: true,
                          animatedTexts: [
                            RotateAnimatedText('Information'),
                            RotateAnimatedText('Exit Gates'),
                            RotateAnimatedText('Schedule'),
                            RotateAnimatedText('Status'),
                          ],
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const StationSearchScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
        image: DecorationImage(
          image: AssetImage('assets/Image/nighthero.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Delhi\nOverground",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: const Color.fromARGB(255, 255, 255, 255),
                    height: 1.h,
                    fontSize: 30.sp,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w800,
                  ),
                ),
                _buildBlurSettingsButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurSettingsButton() {
    return GestureDetector(
      onTap: () {
        _showSettingsBottomSheet(context);
      },
      behavior: HitTestBehavior.opaque,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            child: Icon(
              CupertinoIcons.settings,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return const SettingsBottomSheet();
      },
    );
  }
}

// -------------------- PULSING DOT CONNECTIVITY INDICATOR --------------------
class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 8.w,
        height: 8.w,
        decoration: const BoxDecoration(
          color: AppColors.secondaryAccent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.secondaryAccent,
              blurRadius: 6,
              spreadRadius: 1.5,
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------- SETTINGS BOTTOM SHEET --------------------
class SettingsBottomSheet extends StatefulWidget {
  const SettingsBottomSheet({super.key});

  @override
  State<SettingsBottomSheet> createState() => _SettingsBottomSheetState();
}

class _SettingsBottomSheetState extends State<SettingsBottomSheet> with SingleTickerProviderStateMixin {
  bool _isUpdating = false;
  String _lastFetchTime = "Loading...";
  late AnimationController _buttonAnimController;

  @override
  void initState() {
    super.initState();
    _loadLastFetchTime();
    _buttonAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _buttonAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadLastFetchTime() async {
    final timeStr = await StopsManager.getLastFetchTimeString();
    if (mounted) {
      setState(() {
        _lastFetchTime = timeStr;
      });
    }
  }

  Future<void> _triggerForceUpdate() async {
    if (_isUpdating) return;
    setState(() {
      _isUpdating = true;
    });
    _buttonAnimController.repeat();

    final success = await StopsManager.forceRefresh();

    if (mounted) {
      _buttonAnimController.stop();
      setState(() {
        _isUpdating = false;
      });
      _loadLastFetchTime();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
          backgroundColor: success ? AppColors.secondaryAccent : AppColors.destructive,
          content: Row(
            children: [
              Icon(
                success ? Icons.check_circle_rounded : Icons.error_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  success ? "Stops updated successfully!" : "Failed to update stops. Please check your internet connection.",
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalStops = StopsManager.getStations().length;

    return Container(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 16.h,
        bottom: MediaQuery.of(context).padding.bottom + 24.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24.r),
          topRight: Radius.circular(24.r),
        ),
        border: Border.all(
          color: AppColors.divider,
          width: 1.0,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 20.h),

          // Title Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Settings",
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Poppins',
                  letterSpacing: -0.5,
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.xmark,
                    color: AppColors.secondaryText,
                    size: 16.sp,
                  ),
                ),
              )
            ],
          ),
          SizedBox(height: 20.h),

          // Card 1: Bus Stops Database
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.divider,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.map_pin_ellipse,
                          color: AppColors.primaryAccent,
                          size: 18.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          "Bus Stops Database",
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.primaryAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                        border: Border.all(
                          color: AppColors.primaryAccent.withValues(alpha: 0.2),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        "DTS API",
                        style: TextStyle(
                          color: AppColors.primaryAccent,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                const Divider(
                  color: AppColors.divider,
                  thickness: 0.5,
                  height: 1,
                ),
                SizedBox(height: 14.h),
                _buildInfoRow(
                  label: "Grouped Stations",
                  value: totalStops > 0 ? "$totalStops Stations" : "Loading...",
                  isHighlight: true,
                ),
                SizedBox(height: 10.h),
                _buildInfoRow(
                  label: "Last Updated",
                  value: _lastFetchTime,
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // Card 2: App Information & Connectivity
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.divider,
                width: 1.0,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.info_circle,
                      color: AppColors.secondaryAccent,
                      size: 18.sp,
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "System Status",
                      style: TextStyle(
                        color: AppColors.primaryText,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                const Divider(
                  color: AppColors.divider,
                  thickness: 0.5,
                  height: 1,
                ),
                SizedBox(height: 14.h),
                _buildInfoRow(
                  label: "Update Interval",
                  value: "Every 14 Days",
                ),
                SizedBox(height: 10.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "API Server Status",
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: 13.sp,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const PulsingDot(),
                        SizedBox(width: 8.w),
                        Text(
                          "Online",
                          style: TextStyle(
                            color: AppColors.secondaryAccent,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 24.h),

          // Force Update Button (styled as a rounded pill)
          GestureDetector(
            onTap: _isUpdating ? null : _triggerForceUpdate,
            child: Container(
              height: 52.h,
              decoration: BoxDecoration(
                color: _isUpdating
                    ? AppColors.primaryAccent.withValues(alpha: 0.6)
                    : AppColors.primaryAccent,
                borderRadius: BorderRadius.circular(80.r),
              ),
              child: Center(
                child: _isUpdating
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          RotationTransition(
                            turns: _buttonAnimController,
                            child: Icon(
                              CupertinoIcons.refresh_thick,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            "Updating Dataset...",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            CupertinoIcons.refresh,
                            color: Colors.white,
                            size: 18.sp,
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            "Force Update Stops",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    bool isHighlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.secondaryText,
            fontSize: 13.sp,
            fontFamily: 'Poppins',
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? AppColors.primaryText : AppColors.secondaryText,
            fontSize: 13.sp,
            fontWeight: isHighlight ? FontWeight.w600 : FontWeight.w500,
            fontFamily: 'Poppins',
          ),
        ),
      ],
    );
  }
}
