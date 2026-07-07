import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:metroapp/elements/ServicesDir/journey_planner_service.dart';
import 'package:metroapp/elements/ServicesDir/stops_manager.dart';
import 'package:metroapp/elements/StationDir/stop_info.dart';
import 'package:metroapp/main.dart';
import 'package:url_launcher/url_launcher.dart';

class JourneyDetailsScreen extends StatelessWidget {
  final JourneyRoute route;
  final String srcName;
  final String dstName;

  const JourneyDetailsScreen({
    super.key,
    required this.route,
    required this.srcName,
    required this.dstName,
  });

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
                  _buildSummaryCard(),
                ],
              ),
            ),
            SizedBox(height: 5.h),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.only(
                  left: 14.w,
                  right: 14.w,
                  top: 28.h,
                  bottom: 30.h,
                ),
                children: [
                  _buildTimelineSection(),
                  SizedBox(height: 15.h),
                  _buildCompanyFooter(),
                ],
              ),
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

  String _formatTravelTime(double timeInMinutes) {
    final int totalMinutes = timeInMinutes.toInt();
    if (totalMinutes <= 0) return '0 Mins';

    final int hours = totalMinutes ~/ 60;
    final int minutes = totalMinutes % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '$hours Hr $minutes Mins';
      } else {
        return '$hours Hr';
      }
    } else {
      return '$minutes Mins';
    }
  }

  String _formatReachTime(String reachTime) {
    if (reachTime.isEmpty) return '';
    if (reachTime.toUpperCase().contains('AM') || reachTime.toUpperCase().contains('PM')) {
      return reachTime;
    }
    try {
      final parts = reachTime.split(':');
      if (parts.isNotEmpty) {
        int hour = int.parse(parts[0]);
        int minute = parts.length > 1 ? int.parse(parts[1]) : 0;

        final period = hour >= 12 ? 'PM' : 'AM';
        hour = hour % 12;
        if (hour == 0) hour = 12;

        final minuteStr = minute.toString().padLeft(2, '0');
        return '$hour:$minuteStr $period';
      }
    } catch (e) {
      // ignore
    }
    return reachTime;
  }

  Widget _buildScreenTitle() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Text(
        "Trip Details",
        style: TextStyle(
          color: AppColors.primaryText,
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: EdgeInsets.only(left: 12.w, right: 0, top: 0, bottom: 0),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: AppColors.secondaryAccent,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: From/To Destination info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      "From ",
                      style: TextStyle(
                        color: AppColors.tertiaryText,
                        fontFamily: 'Poppins',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        srcName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontFamily: 'Poppins',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Text(
                      "To ",
                      style: TextStyle(
                        color: AppColors.tertiaryText,
                        fontFamily: 'Poppins',
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        dstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontFamily: 'Poppins',
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          // Right: Travel Time & Reach Time stacked vertically with same width
          IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Section 2: Travel Time
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryAccent,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "TRAVEL TIME",
                        style: TextStyle(
                          color: const Color(0xFF064E3B),
                          fontFamily: 'Poppins',
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _formatTravelTime(route.tripTime),
                        style: TextStyle(
                          color: const Color(0xFF064E3B),
                          fontFamily: 'Poppins',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                // Section 3: Reach Time
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.secondaryAccent,
                      width: 0.8,
                    ),
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "REACH BY",
                        style: TextStyle(
                          color: AppColors.secondaryAccent,
                          fontFamily: 'Poppins',
                          fontSize: 8.sp,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        _formatReachTime(route.reachBy),
                        style: TextStyle(
                          color: AppColors.secondaryAccent,
                          fontFamily: 'Poppins',
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final List<Widget> timelineItems = [];

    Color firstLineColor = AppColors.divider;
    bool isFirstLineDashed = true;
    if (route.legs.isNotEmpty) {
      final firstLeg = route.legs.first;
      final isWalk = firstLeg.type.toLowerCase() == 'walk';
      if (!isWalk) {
        final colorStr = firstLeg.color.replaceAll('#', '0xFF');
        firstLineColor = Color(int.tryParse(colorStr) ?? 0xFFF8CA35);
        isFirstLineDashed = false;
      }
    }

    // 1. Start Node
    timelineItems.add(
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 24.w,
                  height: 24.w,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    size: Size(2.w, double.infinity),
                    painter: LinePainter(
                      color: firstLineColor,
                      nextColor: firstLineColor,
                      isDashed: isFirstLineDashed,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "STARTING POINT",
                      style: TextStyle(
                        color: AppColors.tertiaryText,
                        fontFamily: 'Poppins',
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      srcName,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // 2. Middle Leg Nodes
    for (int i = 0; i < route.legs.length; i++) {
      final leg = route.legs[i];
      final isWalk = leg.type.toLowerCase() == 'walk';

      Color nextLineColor = AppColors.divider;
      bool isNextLineDashed = true;
      if (i < route.legs.length - 1) {
        final nextLeg = route.legs[i + 1];
        final isNextWalk = nextLeg.type.toLowerCase() == 'walk';
        if (!isNextWalk) {
          final colorStr = nextLeg.color.replaceAll('#', '0xFF');
          nextLineColor = Color(int.tryParse(colorStr) ?? 0xFFF8CA35);
          isNextLineDashed = false;
        }
      }

      if (isWalk) {
        timelineItems.add(
          WalkLegTimelineTile(
            leg: leg,
            nextLineColor: nextLineColor,
            isNextDashed: isNextLineDashed,
          ),
        );
      } else {
        final colorStr = leg.color.replaceAll('#', '0xFF');
        final legColor = Color(int.tryParse(colorStr) ?? 0xFFF8CA35);

        timelineItems.add(TransitLegBoardingTile(leg: leg, legColor: legColor));

        timelineItems.add(
          TransitLegDepaboardingTile(
            leg: leg,
            legColor: legColor,
            nextLineColor: nextLineColor,
            isNextDashed: isNextLineDashed,
          ),
        );
      }
    }

    // 3. Destination Node
    timelineItems.add(
      Row(
        children: [
          Container(
            width: 24.w,
            height: 24.w,
            decoration: const BoxDecoration(
              color: AppColors.destructive,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 12.w,
                height: 12.w,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.rectangle,
                ),
              ),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DESTINATION",
                  style: TextStyle(
                    color: AppColors.tertiaryText,
                    fontFamily: 'Poppins',
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  dstName,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: timelineItems,
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

class WalkLegTimelineTile extends StatelessWidget {
  final JourneyLeg leg;
  final Color nextLineColor;
  final bool isNextDashed;

  const WalkLegTimelineTile({
    super.key,
    required this.leg,
    required this.nextLineColor,
    required this.isNextDashed,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              SizedBox(
                width: 24.w,
                height: 24.w,
                child: Center(
                  child: Icon(
                    Icons.directions_walk,
                    color: AppColors.secondaryText,
                    size: 16.sp,
                  ),
                ),
              ),
              Expanded(
                child: CustomPaint(
                  size: Size(2.w, double.infinity),
                  painter: LinePainter(
                    color: AppColors.divider,
                    nextColor: AppColors.divider,
                    isDashed: true,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "Walk ${leg.tripTime} min",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.sp,
                                ),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: Container(
                                  margin: EdgeInsets.only(left: 8.w),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.divider.withValues(
                                      alpha: 0.2,
                                    ),
                                    border: Border.all(
                                      color: AppColors.divider,
                                      width: 0.6,
                                    ),
                                    borderRadius: BorderRadius.circular(3.r),
                                  ),
                                  child: Text(
                                    "${leg.distance.toInt()}m",
                                    style: TextStyle(
                                      color: AppColors.secondaryText,
                                      fontFamily: 'Poppins',
                                      fontSize: 9.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontFamily: 'Poppins',
                        fontSize: 13.sp,
                        height: 1.3,
                      ),
                      children: [
                        const TextSpan(text: "Walk from "),
                        TextSpan(
                          text: leg.stops.first.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Container(
                            margin: EdgeInsets.symmetric(horizontal: 6.w),
                            padding: EdgeInsets.symmetric(
                              horizontal: 5.w,
                              vertical: 1.5.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.divider.withValues(alpha: 0.2),
                              border: Border.all(
                                color: AppColors.divider,
                                width: 0.6,
                              ),
                              borderRadius: BorderRadius.circular(3.r),
                            ),
                            child: Text(
                              "TO",
                              style: TextStyle(
                                color: AppColors.secondaryText,
                                fontFamily: 'Poppins',
                                fontSize: 9.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(
                          text: leg.stops.last.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  GestureDetector(
                    onTap: () async {
                      if (leg.stops.isNotEmpty) {
                        final startLat = leg.stops.first.lat;
                        final startLon = leg.stops.first.lon;
                        final endLat = leg.stops.last.lat;
                        final endLon = leg.stops.last.lon;
                        final googleMapsUrl = Uri.parse(
                          "https://www.google.com/maps/dir/?api=1&origin=$startLat,$startLon&destination=$endLat,$endLon&travelmode=walking",
                        );
                        try {
                          if (await canLaunchUrl(googleMapsUrl)) {
                            await launchUrl(
                              googleMapsUrl,
                              mode: LaunchMode.externalApplication,
                            );
                          } else {
                            debugPrint("Could not launch $googleMapsUrl");
                          }
                        } catch (e) {
                          debugPrint("Error launching walking route: $e");
                        }
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(
                          color: AppColors.divider,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.location_north_fill,
                            color: AppColors.secondaryText,
                            size: 11.sp,
                          ),
                          SizedBox(width: 5.w),
                          Text(
                            "Navigate",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontFamily: 'Poppins',
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TransitLegBoardingTile extends StatefulWidget {
  final JourneyLeg leg;
  final Color legColor;

  const TransitLegBoardingTile({
    super.key,
    required this.leg,
    required this.legColor,
  });

  @override
  State<TransitLegBoardingTile> createState() => _TransitLegBoardingTileState();
}

class _TransitLegBoardingTileState extends State<TransitLegBoardingTile> {
  bool _showStops = true;

  dynamic _resolveStationDict() {
    final stop = widget.leg.stops.first;
    final stations = StopsManager.getStations();

    // 1. Try to find by matching ID
    dynamic matched = stations.firstWhere((s) {
      final codes = s["StationCode"]?.toString().split(',') ?? [];
      return codes.contains(stop.id.toString()) ||
          (stop.code.isNotEmpty && codes.contains(stop.code));
    }, orElse: () => null);

    // 2. Try to find by matching name
    if (matched == null) {
      final cleanName = stop.name.trim().toLowerCase();
      matched = stations.firstWhere((s) {
        final sName = s["Name"]?.toString().trim().toLowerCase() ?? "";
        return sName == cleanName;
      }, orElse: () => null);
    }

    // 3. Fallback to constructing a valid station map
    final sourceMap =
        matched ??
        {
          "StationCode": stop.id.toString(),
          "Name": stop.name,
          "Hindi": stop.name,
          "Line": "",
          "Latitude": stop.lat.toString(),
          "Longitude": stop.lon.toString(),
        };

    return {"Source": sourceMap};
  }

  @override
  Widget build(BuildContext context) {
    final intermediateStops =
        widget.leg.stops.length > 2
            ? widget.leg.stops.sublist(1, widget.leg.stops.length - 1)
            : <JourneyStop>[];

    final hasStops = intermediateStops.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          hasStops
              ? () {
                setState(() {
                  _showStops = !_showStops;
                });
              }
              : null,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  margin: EdgeInsets.only(top: 2.h),
                  width: 24.w,
                  height: 24.w,
                  decoration: BoxDecoration(
                    color: widget.legColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.bus,
                    color: Colors.white,
                    size: 13.sp,
                  ),
                ),
                Expanded(
                  child: CustomPaint(
                    size: Size(2.w, double.infinity),
                    painter: LinePainter(
                      color: widget.legColor,
                      nextColor: widget.legColor,
                      isDashed: false,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: 14.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.leg.stops.first.name,
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w700,
                        fontSize: 15.sp,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Row(
                      children: [
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(
                              color: AppColors.divider,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 4.w,
                                height: 18.h,
                                color: widget.legColor,
                              ),
                              SizedBox(width: 6.w),
                              Icon(
                                CupertinoIcons.bus,
                                color: Colors.white,
                                size: 11.sp,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                widget.leg.routes.isNotEmpty
                                    ? widget.leg.routes.first
                                    : 'Transit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'Poppins',
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(width: 6.w),
                            ],
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            "Depart ${widget.leg.departureTime} • ${widget.leg.tripTime} min",
                            style: TextStyle(
                              color: AppColors.secondaryText,
                              fontFamily: 'Poppins',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (hasStops) ...[
                      SizedBox(height: 10.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _showStops
                                ? CupertinoIcons.chevron_up
                                : CupertinoIcons.chevron_down,
                            color: AppColors.primaryAccent,
                            size: 14.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            "${intermediateStops.length} intermediate stop${intermediateStops.length > 1 ? 's' : ''}",
                            style: TextStyle(
                              color: AppColors.primaryAccent,
                              fontFamily: 'Poppins',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      AnimatedCrossFade(
                        firstChild: const SizedBox(
                          width: double.infinity,
                          height: 0,
                        ),
                        secondChild: Container(
                          margin: EdgeInsets.only(top: 8.h),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black,
                            border: Border.all(
                              color: AppColors.divider,
                              width: 0.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children:
                                intermediateStops.map((stop) {
                                  return Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 10.w,
                                      vertical: 8.h,
                                    ),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.divider,
                                          width: 0.3,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 4.w,
                                          height: 4.w,
                                          decoration: const BoxDecoration(
                                            color: AppColors.tertiaryText,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            stop.name,
                                            style: TextStyle(
                                              color: AppColors.secondaryText,
                                              fontFamily: 'Poppins',
                                              fontSize: 12.sp,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                          ),
                        ),
                        crossFadeState:
                            _showStops
                                ? CrossFadeState.showSecond
                                : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 200),
                        sizeCurve: Curves.easeInOut,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => StopInfoScreen(
                            stationDict: _resolveStationDict(),
                          ),
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 2.h,
                    left: 10.w,
                    right: 6.w,
                    bottom: 10.h,
                  ),
                  child: Icon(
                    CupertinoIcons.info_circle,
                    color: AppColors.secondaryText,
                    size: 20.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransitLegDepaboardingTile extends StatelessWidget {
  final JourneyLeg leg;
  final Color legColor;
  final Color nextLineColor;
  final bool isNextDashed;

  const TransitLegDepaboardingTile({
    super.key,
    required this.leg,
    required this.legColor,
    required this.nextLineColor,
    required this.isNextDashed,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                margin: EdgeInsets.only(top: 2.h),
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  color: legColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.square_arrow_right,
                  color: Colors.white,
                  size: 11.sp,
                ),
              ),
              Expanded(
                child: CustomPaint(
                  size: Size(2.w, double.infinity),
                  painter: LinePainter(
                    color: nextLineColor,
                    nextColor: nextLineColor,
                    isDashed: isNextDashed,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leg.stops.last.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    "Alight around ${leg.endingTime}",
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontFamily: 'Poppins',
                      fontSize: 13.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  final Color color;
  final Color nextColor;
  final bool isDashed;

  LinePainter({
    required this.color,
    required this.nextColor,
    this.isDashed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = 2.w
          ..style = PaintingStyle.stroke;

    final double startY = 0;
    final double endY = size.height;
    final double midY = size.height * 0.9;

    if (isDashed) {
      const double dashHeight = 4;
      const double dashSpace = 4;
      double currentY = startY;
      while (currentY < endY) {
        if (nextColor != Colors.transparent && currentY > midY) {
          paint.color = nextColor;
        }
        canvas.drawLine(
          Offset(size.width / 2, currentY),
          Offset(size.width / 2, (currentY + dashHeight).clamp(startY, endY)),
          paint,
        );
        currentY += dashHeight + dashSpace;
      }
    } else {
      if (nextColor == Colors.transparent || nextColor == color) {
        canvas.drawLine(
          Offset(size.width / 2, startY),
          Offset(size.width / 2, endY),
          paint,
        );
      } else {
        canvas.drawLine(
          Offset(size.width / 2, startY),
          Offset(size.width / 2, midY),
          paint,
        );
        paint.color = nextColor;
        canvas.drawLine(
          Offset(size.width / 2, midY),
          Offset(size.width / 2, endY),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
