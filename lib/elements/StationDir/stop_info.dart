import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metroapp/elements/ServicesDir/station_element.dart';
import 'package:metroapp/elements/ServicesDir/new_schedule_service.dart';
import 'package:metroapp/elements/journey_planner.dart';
import 'package:metroapp/main.dart';
import 'package:metroapp/elements/ServicesDir/analytics_service.dart';
import 'package:metroapp/elements/ServicesDir/ad_service.dart';

class StopInfoScreen extends StatefulWidget {
  final dynamic stationDict;
  const StopInfoScreen({super.key, required this.stationDict});

  @override
  State<StopInfoScreen> createState() => _StopInfoScreenState();
}

class _StopInfoScreenState extends State<StopInfoScreen> {
  DateTime _refreshTrigger = DateTime.now();
  bool _hasTriggeredRefresh = false;

  @override
  void initState() {
    super.initState();
    PostHogService.trackScreenViewed('Stop Info');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildStationCluster(context),
    );
  }

  Widget _buildStationCluster(BuildContext context) {
    final source = (widget.stationDict != null && widget.stationDict is Map)
        ? widget.stationDict["Source"]
        : null;
    if (source == null) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopNavBar(context),
            ],
          ),
        ),
      );
    }
    final stationCode = source["StationCode"]?.toString() ?? "";
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTopNavBar(context),
            _buildStationLineMarker(),
            _buildBusStopDetailsCard(context),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  if (scrollInfo.metrics.pixels < -80.0) {
                    if (!_hasTriggeredRefresh) {
                      _hasTriggeredRefresh = true;
                      setState(() {
                        _refreshTrigger = DateTime.now();
                      });
                    }
                  } else if (scrollInfo.metrics.pixels >= 0.0) {
                    _hasTriggeredRefresh = false;
                  }
                  return false;
                },
                child: ListView(
                  padding: EdgeInsets.only(top: 30.h),
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    ScheduleWidget(
                      stationCode: stationCode,
                      refreshTrigger: _refreshTrigger,
                    ),
                    SizedBox(height: 15.h),
                    _buildCompanyFooter(),
                  ],
                ),
              ),
            ),
            const StopInfoBannerAd(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context) {
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

  Widget _buildStationLineMarker() {
    dynamic station = (widget.stationDict != null && widget.stationDict is Map)
        ? widget.stationDict["Source"]
        : null;
    if (station == null) return const SizedBox();
    String stationName = station["Name"]?.toString() ?? "";
    String stationNameHindiCommon = station["Hindi"]?.toString() ?? "";
    String line = station["Line"]?.toString() ?? "";
    line = line.replaceAll(RegExp(r'[\[\]]'), '');
    List<String> parts = line.isNotEmpty ? line.split('-') : [];
    return BigNameInfo(
      stationName: stationName,
      stationNameHindiCommon: stationNameHindiCommon,
      lineofStation: parts,
    );
  }

  Widget _buildBusStopDetailsCard(BuildContext context) {
    final source = (widget.stationDict != null && widget.stationDict is Map)
        ? widget.stationDict["Source"]
        : null;
    if (source == null) return const SizedBox();
    final lat = source["Latitude"]?.toString() ?? "";
    final lon = source["Longitude"]?.toString() ?? "";

    return Padding(
      padding: EdgeInsets.only(top: 24.h, bottom: 5.h),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  if (lat.isNotEmpty && lon.isNotEmpty) {
                    final googleMapsUrl = Uri.parse(
                      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lon",
                    );
                    try {
                      if (await canLaunchUrl(googleMapsUrl)) {
                        await launchUrl(
                          googleMapsUrl,
                          mode: LaunchMode.externalApplication,
                        );
                      } else {
                        throw 'Could not launch $googleMapsUrl';
                      }
                    } catch (e) {
                      debugPrint("Error launching Google Maps: $e");
                    }
                  }
                },
                child: Container(
                  padding: EdgeInsets.all(12.h),
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(38, 59, 131, 246),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Center(
                    child: Row(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.map_pin_ellipse,
                              color: Colors.white,
                              size: 18.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              "on Map",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Poppins',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => JourneyPlannerScreen(
                          initialParams: {
                            'dst_name': source["Name"]?.toString() ?? '',
                            'dst_lat': lat,
                            'dst_lon': lon,
                          },
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.all(12.h),
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(38, 59, 131, 246),
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                CupertinoIcons.arrow_down_circle,
                                color: Colors.white,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                "get Route",
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
                      ],
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


  Widget _buildCompanyFooter() {
    return SizedBox(
      width: double.infinity,
      height: 50.h,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            "DELHI\nOVERGROUND",
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.h,
              color: AppColors.tertiaryText,
              fontWeight: FontWeight.w800,
              fontSize: 12.sp,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}
