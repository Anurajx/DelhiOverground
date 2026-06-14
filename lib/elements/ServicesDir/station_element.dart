import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:metroapp/main.dart';
import 'package:metroapp/elements/bus_info.dart';
import 'package:metroapp/elements/search.dart';

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

    return Container(
      height: 60.h,
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
    decoration: const BoxDecoration(
      color: AppColors.primaryAccent,
      borderRadius: BorderRadius.zero,
    ),
    child: Text(
      lineStr,
      style: TextStyle(
        color: Colors.white,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
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

    return Container(
      padding: EdgeInsets.symmetric(vertical: 10.h, horizontal: 8.w),
      child: Row(
        children: [
          Icon(
            Icons.location_on_outlined,
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

class BigNameInfo extends StatefulWidget {
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
  State<BigNameInfo> createState() => _BigNameInfoState();
}

class _BigNameInfoState extends State<BigNameInfo> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    String mainName = widget.stationName.toString();

    final List<dynamic> lines = widget.lineofStation;
    final bool hasManyLines = lines.length > 10;

    List<dynamic> displayedLines;
    if (hasManyLines && !_isExpanded) {
      displayedLines = lines.take(9).toList();
    } else {
      displayedLines = lines;
    }

    return Padding(
      padding: EdgeInsets.only(top: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 25, 0, 0),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget stationLineBadgeForBig(BuildContext context, dynamic line) {
  String lineStr = line.toString();
  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () async {
      try {
        final db = await BusDatabaseHelper.getDatabase();
        final results = await db.rawQuery(
          '''
          SELECT route_id FROM routes WHERE route_long_name = ? LIMIT 1
        ''',
          [lineStr],
        );
        String routeId = "";
        if (results.isNotEmpty) {
          routeId = results.first['route_id'] as String;
        }
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      BusInfoScreen(routeId: routeId, routeLongName: lineStr),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      BusInfoScreen(routeId: "", routeLongName: lineStr),
            ),
          );
        }
      }
    },
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
      child: Text(
        lineStr,
        style: TextStyle(
          color: AppColors.primaryAccent,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
      ),
    ),
  );
}
