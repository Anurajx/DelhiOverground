import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metroapp/elements/ServicesDir/station_element.dart';
import 'package:metroapp/elements/ServicesDir/new_schedule_service.dart';
import 'package:metroapp/elements/ServicesDir/report_error_service.dart';
import 'package:metroapp/main.dart';

class StopInfoScreen extends StatelessWidget {
  final dynamic stationDict;
  const StopInfoScreen({super.key, required this.stationDict});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: stationCluster(context, stationDict),
    );
  }
}

stationCluster(context, stationDict) {
  final stationCode = stationDict["Source"]["StationCode"];
  print("TRIAL1 THE STATION CODE IS - $stationDict");
  return SafeArea(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          topNavBar(context),
          Expanded(
            child: ListView(
              shrinkWrap: true,
              children: [
                stationLineMarker(stationDict),
                _buildBusStopDetailsCard(context, stationDict),
                SizedBox(height: 20.h),
                ScheduleWidget(stationCode: stationCode),
                SizedBox(height: 40.h),
                reportError(),
                SizedBox(height: 40.h),
                companyFooter(),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

topNavBar(context) {
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

stationLineMarker(stationDict) {
  dynamic station = stationDict["Source"];
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

Widget _buildBusStopDetailsCard(BuildContext context, dynamic stationDict) {
  final source = stationDict["Source"];
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
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: AppColors.primaryAccent,
          borderRadius: BorderRadius.zero,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.compass_fill, color: Colors.white, size: 18.sp),
            SizedBox(width: 8.w),
            Text(
              "Navigate to Stop",
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
  );
}

reportError() {
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

companyFooter() {
  return Container(
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
