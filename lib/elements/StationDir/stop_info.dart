import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:metroapp/elements/ServicesDir/station_element.dart';
import 'package:metroapp/elements/ServicesDir/new_schedule_service.dart';
import 'package:metroapp/elements/ServicesDir/report_error_service.dart';

class StopInfoScreen extends StatelessWidget {
  final dynamic stationDict;
  const StopInfoScreen({super.key, required this.stationDict});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 0, 0),
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
    padding: const EdgeInsets.symmetric(vertical: 20),
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
              const Icon(
                CupertinoIcons.back,
                color: Color.fromARGB(255, 47, 130, 255),
              ),
              Text(
                "Done",
                style: TextStyle(
                  color: const Color.fromARGB(255, 47, 130, 255),
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Poppins',
                  fontSize: 18.sp,
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
    padding: EdgeInsets.symmetric(vertical: 12.h),
    child: GestureDetector(
      onTap: () async {
        if (lat.isNotEmpty && lon.isNotEmpty) {
          final googleMapsUrl = Uri.parse(
            "https://www.google.com/maps/dir/?api=1&destination=$lat,$lon",
          );
          try {
            if (await canLaunchUrl(googleMapsUrl)) {
              await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
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
          gradient: const LinearGradient(
            colors: [Color(0xFF2F82FF), Color(0xFF0055D4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.zero,
          boxShadow: [
            BoxShadow(
              color: Colors.blueAccent.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
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
        height: 50.h,
        width: 170.w,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          border: Border.all(color: const Color.fromARGB(255, 35, 35, 35)),
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
              "report error",
              style: TextStyle(
                color: const Color.fromARGB(255, 187, 187, 187),
                fontSize: 18.sp,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
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
          "DELHI\nUNDERGROUND",
          textAlign: TextAlign.center,
          style: TextStyle(
            height: 1.h,
            color: const Color.fromARGB(255, 90, 90, 90),
            fontWeight: FontWeight.w800,
            fontSize: 14.sp,
          ),
        ),
      ],
    ),
  );
}
