import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
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
import 'StationDir/station_search.dart';
import 'ServicesDir/data_provider.dart';
import 'package:provider/provider.dart';
import 'journey_planner.dart';
import 'package:metroapp/elements/ServicesDir/stops_manager.dart';
import 'package:metroapp/elements/ServicesDir/analytics_service.dart';
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
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;

  Future<void> _refreshNearbyStations(DataProvider dataProvider) async {
    if (_isRefreshing) return;
    setState(() {
      _isRefreshing = true;
    });
    dataProvider.updateCoreNearestStationsDict({});
    dataProvider.setLocationEnabled(null);
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

  Future<void> _checkInitialConnectivity() async {
    final results = await Connectivity().checkConnectivity();
    final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
    if (mounted) {
      setState(() {
        _isOffline = isOffline;
      });
    }
  }

  Future<void> _checkLocationPermissionOnStartup() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      if (mounted) {
        await initialize(context);
      }
    } else {
      if (mounted) {
        _showLocationPermissionDialog();
      }
    }
  }

  void _showLocationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.secondaryAccent,
        insetPadding: EdgeInsets.symmetric(horizontal: 40.w),
        shape: const Border(),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.secondaryAccent,
            border: Border.all(
              color: Colors.black,
              width: 0.8,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "LOCATION ACCESS",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.sp,
                  fontFamily: 'Poppins',
                  letterSpacing: 1.5,
                ),
              ),
              SizedBox(height: 12.h),
              Text(
                "Delhi Overground requires your location to find nearby bus and metro stops.",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w400,
                  fontSize: 12.sp,
                  fontFamily: 'Poppins',
                  height: 1.5,
                ),
              ),
              SizedBox(height: 24.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      PostHogService.trackButtonClicked('location_permission_cancel');
                      Navigator.pop(ctx);
                      Provider.of<DataProvider>(context, listen: false)
                          .setLocationEnabled(false);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: Colors.black.withValues(alpha: 0.4),
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        "CANCEL",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.sp,
                          fontFamily: 'Poppins',
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      PostHogService.trackButtonClicked('location_permission_allow');
                      Navigator.pop(ctx);
                      initialize(context);
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: Colors.black,
                          width: 1.2,
                        ),
                      ),
                      child: Text(
                        "ALLOW",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 11.sp,
                          fontFamily: 'Poppins',
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreenViewed('Home');
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLocationPermissionOnStartup());
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final isOffline = results.isEmpty || results.contains(ConnectivityResult.none);
      if (mounted && _isOffline != isOffline) {
        setState(() {
          _isOffline = isOffline;
        });
      }
    });
    _checkInitialConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
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
        PostHogService.trackMenuItemClicked('plan_journey');
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
          return _buildHistoryPlaceholder();
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

  Widget _buildHistoryPlaceholder() {
    return Container(
      margin: const EdgeInsets.only(left: 2, right: 2, top: 1, bottom: 2),
      width: double.infinity,
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
                  "Make your first search",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryText,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  "Your search history will appear here",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.secondaryText,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPlaceholder() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
      child: Row(
        children: [
          Icon(
            Icons.location_off_outlined,
            color: AppColors.tertiaryText,
            size: 20.sp,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Enable Location",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryText,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  "Turn on location and find nearby stops",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.secondaryText,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
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
          final isLocationEnabled = dataProvider.isLocationEnabled;

          if (isLocationEnabled == false) {
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
                _buildLocationPlaceholder(),
              ],
            );
          }

          if (data["Near"] != null && data["NearEnough"] != null) {
            _coreTransferStationsDictNE['Source'] = data["NearEnough"]![0];
            String lineNE = data["NearEnough"]![0]["Line"].toString();
            lineNE = lineNE.replaceAll(RegExp(r'[\[\]]'), '');
            List<String> lineNumbersNE = lineNE.split('-');

            _coreTransferStationsDictN['Source'] = data["Near"]![0];
            String lineN = data["Near"]![0]["Line"].toString();
            lineN = lineN.replaceAll(RegExp(r'[\[\]]'), '');
            List<String> lineNumbersN = lineN.split('-');

            Position? userPos;
            if (data["UserLocation"] != null && data["UserLocation"]!.isNotEmpty) {
              final loc = data["UserLocation"]![0];
              if (loc is Position) {
                userPos = loc;
              }
            }

            double? distNE;
            final latNE = double.tryParse(data["NearEnough"]?[0]["Latitude"]?.toString() ?? '');
            final lonNE = double.tryParse(data["NearEnough"]?[0]["Longitude"]?.toString() ?? '');
            if (userPos != null && latNE != null && lonNE != null) {
              final meters = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, latNE, lonNE);
              distNE = meters / 1000.0;
            }

            double? distN;
            final latN = double.tryParse(data["Near"]?[0]["Latitude"]?.toString() ?? '');
            final lonN = double.tryParse(data["Near"]?[0]["Longitude"]?.toString() ?? '');
            if (userPos != null && latN != null && lonN != null) {
              final meters = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, latN, lonN);
              distN = meters / 1000.0;
            }

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
                    distance: distNE,
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
                    distance: distN,
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
                      PostHogService.trackButtonClicked('whatsapp_tickets');
                      final whatsappUrl = Uri.parse(
                        'https://wa.me/+918744073223?text=Hi',
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
                      PostHogService.trackMenuItemClicked('settings');
                      _showSettingsBottomSheet(context);
                    },
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.all(Radius.circular(80)),
                      ),
                      child: const Center(
                        child: Icon(CupertinoIcons.settings, color: Colors.white),
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
                  PostHogService.trackMenuItemClicked('stop_search');
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
                            RotateAnimatedText('Schedule'),
                            RotateAnimatedText('Location'),
                            RotateAnimatedText('Route'),
                          ],
                          onTap: () {
                            PostHogService.trackMenuItemClicked('stop_search');
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
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
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
          ),
        ),
        Positioned.fill(
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
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
                        if (_isOffline) ...[
                          SizedBox(height: 14.h),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            decoration: const BoxDecoration(
                              color: AppColors.destructive, // Solid red color
                              borderRadius: BorderRadius.zero, // Sharp corners
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.wifi_off,
                                  color: Colors.white,
                                  size: 12.sp,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  "you're offline",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Poppins',
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
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

class _SettingsBottomSheetState extends State<SettingsBottomSheet> {
  bool _isUpdating = false;
  String _lastFetchTime = "Loading...";

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreenViewed('Settings');
    _loadLastFetchTime();
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
    PostHogService.trackButtonClicked('force_update_assets');
    setState(() {
      _isUpdating = true;
    });

    await StopsManager.forceRefresh();

    if (mounted) {
      setState(() {
        _isUpdating = false;
      });
      _loadLastFetchTime();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 20.h,
            bottom: MediaQuery.of(context).padding.bottom + 24.h,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65), // Neutral transparent background
            borderRadius: BorderRadius.zero, // Sharp corners
            border: const Border(
              top: BorderSide(
                color: AppColors.divider,
                width: 1.0,
              ),
            ),
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                onTap: () {
                  PostHogService.trackButtonClicked('close_settings');
                  Navigator.pop(context);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: const BoxDecoration(
                    color: Colors.black, // Solid color close background
                    shape: BoxShape.rectangle, // Sharp corners
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
          SizedBox(height: 24.h),



          // Action 1: Update Stop Database
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
            child: Row(
              children: [
                _isUpdating
                    ? SizedBox(
                        width: 20.sp,
                        height: 20.sp,
                        child: const CupertinoActivityIndicator(
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        CupertinoIcons.refresh,
                        color: Colors.white,
                        size: 20.sp,
                      ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isUpdating ? "Updating Assets..." : "Update Assets",
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        "Last updated: $_lastFetchTime",
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _isUpdating ? null : _triggerForceUpdate,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: _isUpdating ? Colors.white.withValues(alpha: 0.5) : Colors.white,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Text(
                      _isUpdating ? "Updating" : "Update",
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'Poppins',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),


          GestureDetector(
            onTap: () async {
              PostHogService.trackMenuItemClicked('official_website');
              final url = Uri.parse("https://delhioverground.vercel.app/");
              try {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              } catch (e) {
                debugPrint("Error launching Website URL: $e");
              }
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 18.h),
              child: Row(
                children: [
                  Icon(
                    CupertinoIcons.globe,
                    color: Colors.white,
                    size: 20.sp,
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Official Website",
                          style: TextStyle(
                            color: AppColors.primaryText,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "Visit our official homepage",
                          style: TextStyle(
                            color: AppColors.secondaryText,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w400,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.chevron_forward,
                    color: AppColors.secondaryText,
                    size: 14.sp,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16.h),
          Center(
            child: Text(
              "Version 1.0.0 (1)",
              style: TextStyle(
                color: AppColors.tertiaryText,
                fontSize: 11.sp,
                fontWeight: FontWeight.w400,
                fontFamily: 'Poppins',
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    )));
  }
}
