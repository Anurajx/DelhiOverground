import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:metroapp/main.dart';

class StationUnit extends StatelessWidget {
  final dynamic name;
  final dynamic hindiName;
  final List lines;

  const StationUnit({
    super.key,
    required this.name,
    required this.hindiName,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    String mainText = name.toString();
    String? subText;
    if (mainText.contains('/')) {
      final parts = mainText.split('/');
      mainText = parts[0].trim();
      subText = parts[1].trim();
    }

    return Container(
      height: 72.h,
      margin: EdgeInsets.symmetric(vertical: 2.h),
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  mainText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryText,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subText != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    subText,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: AppColors.secondaryText,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Icon(
            CupertinoIcons.arrow_right,
            color: AppColors.tertiaryText,
            size: 20.sp,
          ),
        ],
      ),
    );
  }
}

Color getColorFromRouteName(String routeName) {
  if (routeName.isEmpty) return const Color.fromARGB(226, 255, 255, 255);
  int hash = 0;
  for (int i = 0; i < routeName.length; i++) {
    hash = routeName.codeUnitAt(i) + ((hash << 5) - hash);
  }
  double hue = (hash.abs() % 360).toDouble();
  return HSLColor.fromAHSL(1.0, hue, 0.35, 0.7).toColor();
}

Color getColorFromLine(dynamic line) {
  if (line is int) {
    return getColorFromRouteName(line.toString());
  } else if (line is String) {
    return getColorFromRouteName(line);
  }
  return const Color.fromARGB(226, 255, 255, 255);
}

Widget stationLineBadgeBuilder(List<dynamic> lines) {
  return Wrap(
    spacing: 4.w,
    runSpacing: 4.h,
    children:
        lines.map<Widget>((line) {
          return stationLineBadge(line);
        }).toList(),
  );
}

Widget stationLineBadge(dynamic line) {
  String lineStr = line.toString();
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
    decoration: BoxDecoration(
      color: getColorFromLine(line),
      borderRadius: BorderRadius.zero,
    ),
    child: Text(
      lineStr,
      style: TextStyle(
        color: Colors.black,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class StationPrimitive extends StatelessWidget {
  //for station list on main screen
  final dynamic name;

  const StationPrimitive({super.key, required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            '$name',
            //maxLines: 2,
            overflow: TextOverflow.fade,
            softWrap: false,
            // minFontSize: 14,
            // maxFontSize: 18,
            style: TextStyle(
              fontFamily: 'Poppins',
              color: AppColors.primaryText,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600, //300
            ),
          ),
        ),
        //Spacer(),
        // Row(
        //   children: [
        //     SizedBox(
        //       width: 10,
        //     ), // adding to create a bit of space between line indicatot and text
        //     Container(
        //       width: 15,
        //       height: 15,
        //       decoration: BoxDecoration(
        //         color: const Color.fromARGB(255, 0, 122, 204),
        //         borderRadius: BorderRadius.all(Radius.circular(3)),
        //       ),
        //       child: Center(
        //         child: Text(
        //           "3",
        //           style: TextStyle(
        //             color: Colors.black,
        //             fontSize: 10,
        //             fontWeight: FontWeight.w700,
        //           ),
        //         ),
        //       ),
        //       // color: const Color(
        //       //   0xFF0072BC,
        //       // ), //blue line color will make it dynamic later
        //     ),
        //     SizedBox(width: 1),
        //     Container(
        //       width: 15,
        //       height: 15,

        //       decoration: BoxDecoration(
        //         color: const Color.fromARGB(255, 200, 155, 0),
        //         borderRadius: BorderRadius.all(Radius.circular(3)),
        //       ),
        //       child: Center(
        //         child: Text(
        //           "7",
        //           style: TextStyle(
        //             color: Colors.black,
        //             fontSize: 10,
        //             fontWeight: FontWeight.w700,
        //           ),
        //         ),
        //       ), //make this change dynamically based on the station
        //       // color: const Color(
        //       //   0xFFF47B20,
        //       // ), //blue line color will make it dynamic later
        //     ),
        //   ],
        // ),
        //Spacer(),
        //right: 0,
        Icon(CupertinoIcons.arrow_right, color: AppColors.primaryText),
      ],
    );
  }
}

class StationNearby extends StatelessWidget {
  //for station list on main screen
  final dynamic name;
  final dynamic line;
  const StationNearby({super.key, required this.name, required this.line});

  @override
  Widget build(BuildContext context) {
    String mainText = name.toString();
    String? subText;
    if (mainText.contains('/')) {
      final parts = mainText.split('/');
      mainText = parts[0].trim();
      subText = parts[1].trim();
    }

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.location,
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
                  mainText,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.primaryText,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subText ?? "Nearby Stop",
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: AppColors.secondaryText,
                    fontSize: 11.sp,
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
}

///////////////////////
class BigNameInfo extends StatelessWidget {
  final dynamic stationName;
  final dynamic stationNameHindiCommon;
  final dynamic lineofStation;
  const BigNameInfo({
    super.key,
    required this.stationName,
    required this.stationNameHindiCommon,
    required this.lineofStation,
  });

  @override
  Widget build(BuildContext context) {
    String mainName = stationName.toString();
    String? subName;
    if (mainName.contains('/')) {
      final parts = mainName.split('/');
      mainName = parts[0].trim();
      subName = parts[1].trim();
    }

    final showHindi =
        stationNameHindiCommon != null &&
        stationNameHindiCommon.toString().isNotEmpty &&
        stationNameHindiCommon.toString().toLowerCase() !=
            stationName.toString().toLowerCase() &&
        stationNameHindiCommon.toString().toLowerCase() !=
            mainName.toLowerCase();

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 25, 0, 25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  mainName,
                  style: TextStyle(
                    height: 1.2,
                    color: AppColors.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 24.sp,
                    fontFamily: 'Poppins',
                  ),
                ),
                if (subName != null) ...[
                  Text(
                    subName,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontWeight: FontWeight.w400,
                      fontSize: 16.sp,
                      fontFamily: 'Poppins',
                    ),
                  ),
                ],
              ],
            ),
          ),
          stationLineBadgeBuilderForBIG(lineofStation),
        ],
      ),
    );
  }
}

Widget stationLineBadgeBuilderForBIG(List<dynamic> lines) {
  return Wrap(
    spacing: 4.w,
    runSpacing: 4.h,
    children:
        lines.map<Widget>((line) {
          return stationLineBadgeForBig(line);
        }).toList(),
  );
}

Widget stationLineBadgeForBig(dynamic line) {
  String lineStr = line.toString();
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
    decoration: BoxDecoration(
      color: getColorFromLine(line),
      borderRadius: BorderRadius.zero,
    ),
    child: Text(
      lineStr,
      style: TextStyle(
        color: Colors.black,
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
