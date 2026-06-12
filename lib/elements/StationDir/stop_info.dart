import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metroapp/elements/ServicesDir/station_element.dart';
import 'package:metroapp/elements/ServicesDir/new_schedule_service.dart';
import 'package:metroapp/elements/ServicesDir/report_error_service.dart';
import 'package:metroapp/main.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _buildStationCluster(context),
    );
  }

  Widget _buildStationCluster(BuildContext context) {
    final stationCode = widget.stationDict["Source"]["StationCode"];
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            _buildTopNavBar(context),
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
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  children: [
                    _buildStationLineMarker(),
                    _buildBusStopDetailsCard(context),
                    SizedBox(height: 10.h),
                    ScheduleWidget(
                      stationCode: stationCode,
                      refreshTrigger: _refreshTrigger,
                    ),
                    SizedBox(height: 40.h),
                    _buildReportError(),
                    SizedBox(height: 40.h),
                    _buildCompanyFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
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
        ],
      ),
    );
  }

  Widget _buildStationLineMarker() {
    dynamic station = widget.stationDict["Source"];
    String stationName = station["Name"].toString();
    String stationNameHindiCommon = station["Hindi"].toString();
    String line = station["Line"];
    line = line.replaceAll(RegExp(r'[\[\]]'), '');
    List<String> parts = line.split('-');
    return BigNameInfo(
      stationName: stationName,
      stationNameHindiCommon: stationNameHindiCommon,
      lineofStation: parts,
    );
  }

  Widget _buildBusStopDetailsCard(BuildContext context) {
    final source = widget.stationDict["Source"];
    final lat = source["Latitude"]?.toString() ?? "";
    final lon = source["Longitude"]?.toString() ?? "";

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: GestureDetector(
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
        child: Column(
          children: [
            Row(
              children: [
                Container(
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
                SizedBox(width: 3.w),
                Expanded(
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
              ],
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  Widget _buildReportError() {
    return Row(
      children: [
        Container(
          height: 40.h,
          width: 150.w,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: AppColors.inputBorder, width: 1.5),
          ),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              try {
                sendToGoogleForm();
              } catch (e) {
                debugPrint("Error sending email: $e");
              }
            },
            child: Align(
              alignment: Alignment.center,
              child: Text(
                "Report Error",
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 12.sp,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
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
