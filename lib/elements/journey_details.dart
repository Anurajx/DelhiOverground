import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:metroapp/elements/ServicesDir/journey_planner_service.dart';
import 'package:metroapp/main.dart';

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
            SizedBox(height: 20.h),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: EdgeInsets.only(left: 14.w, right: 14.w, bottom: 30.h),
                children: [
                  _buildTimelineSection(),
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
      padding: EdgeInsets.all(16.w),
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
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      "FROM",
                      style: TextStyle(
                        color: AppColors.tertiaryText,
                        fontFamily: 'Poppins',
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  srcName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10.h),
                Row(
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: const BoxDecoration(
                        color: AppColors.destructive,
                        shape: BoxShape.rectangle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      "TO",
                      style: TextStyle(
                        color: AppColors.tertiaryText,
                        fontFamily: 'Poppins',
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  dstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          // Right: Travel Time details
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "TRAVEL TIME",
                style: TextStyle(
                  color: AppColors.tertiaryText,
                  fontFamily: 'Poppins',
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                "${route.tripTime.toInt()} min",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Poppins',
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.clock, color: AppColors.secondaryText, size: 12.sp),
                  SizedBox(width: 4.w),
                  Text(
                    "Reach: ${route.reachBy}",
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontFamily: 'Poppins',
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    final List<Widget> timelineItems = [];

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
                  child: Icon(
                    CupertinoIcons.location_solid,
                    color: Colors.black,
                    size: 12.sp,
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2.w,
                    color: AppColors.divider, // Neutral vertical line
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
      final nextLegColor = (i < route.legs.length - 1)
          ? Color(int.tryParse(route.legs[i + 1].color.replaceAll('#', '0xFF')) ?? 0xFFF8CA35)
          : Colors.transparent;

      timelineItems.add(
        TransitLegTimelineTile(
          leg: leg,
          nextLegColor: nextLegColor,
        ),
      );
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
            child: Icon(
              CupertinoIcons.location_solid,
              color: Colors.white,
              size: 12.sp,
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
      children: [
        Text(
          "Journey Timeline",
          style: TextStyle(
            color: AppColors.secondaryText,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
          ),
        ),
        SizedBox(height: 16.h),
        ...timelineItems,
      ],
    );
  }
}

class TransitLegTimelineTile extends StatefulWidget {
  final JourneyLeg leg;
  final Color nextLegColor;

  const TransitLegTimelineTile({
    super.key,
    required this.leg,
    required this.nextLegColor,
  });

  @override
  State<TransitLegTimelineTile> createState() => _TransitLegTimelineTileState();
}

class _TransitLegTimelineTileState extends State<TransitLegTimelineTile> {
  bool _showStops = false;

  @override
  Widget build(BuildContext context) {
    final leg = widget.leg;
    final isWalk = leg.type.toLowerCase() == 'walk';
    final colorStr = leg.color.replaceAll('#', '0xFF');
    final legColor = Color(int.tryParse(colorStr) ?? 0xFFF8CA35);
    final intermediateStops = leg.stops.length > 2
        ? leg.stops.sublist(1, leg.stops.length - 1)
        : <JourneyStop>[];

    // Define neutral colors for walk nodes, and transit colors for bus nodes
    final circleBorderColor = isWalk ? AppColors.tertiaryText : legColor;
    final circleBgColor = isWalk ? AppColors.divider.withValues(alpha: 0.3) : legColor.withValues(alpha: 0.15);
    final circleIconColor = isWalk ? AppColors.secondaryText : legColor;

    final canToggle = !isWalk && intermediateStops.isNotEmpty;

    Widget tileContent = Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Icon and custom drawn vertical line
        Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 2.h),
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: circleBgColor,
                border: Border.all(color: circleBorderColor, width: 1.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isWalk ? Icons.directions_walk : CupertinoIcons.bus,
                color: circleIconColor,
                size: 13.sp,
              ),
            ),
            Expanded(
              child: CustomPaint(
                size: Size(2.w, double.infinity),
                painter: LinePainter(
                  color: AppColors.divider, // Neutral line color
                  nextColor: AppColors.divider, // Neutral line color
                  isDashed: isWalk,
                ),
              ),
            ),
          ],
        ),
        SizedBox(width: 14.w),
        // Right Column: Timeline Content Details
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
                      child: Text(
                        isWalk
                            ? "Walk ${leg.distance.toInt()}m"
                            : "Bus ${leg.routes.isNotEmpty ? leg.routes.first : 'Transit'}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "${leg.tripTime} min",
                      style: TextStyle(
                        color: AppColors.secondaryText,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  isWalk
                      ? "Walk from ${leg.stops.first.name} to ${leg.stops.last.name}"
                      : "Board from ${leg.stops.first.name} at ${leg.departureTime}",
                  style: TextStyle(
                    color: AppColors.secondaryText,
                    fontFamily: 'Poppins',
                    fontSize: 13.sp,
                    height: 1.3,
                  ),
                ),
                if (!isWalk && intermediateStops.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showStops ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
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
                    firstChild: const SizedBox(width: double.infinity, height: 0),
                    secondChild: Container(
                      margin: EdgeInsets.only(top: 8.h),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: intermediateStops.map((stop) {
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: AppColors.divider, width: 0.3),
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
                    crossFadeState: _showStops ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                    sizeCurve: Curves.easeInOut,
                  ),
                ],
                if (!isWalk) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppColors.divider.withValues(alpha: 0.25),
                      border: Border.all(color: AppColors.divider, width: 0.5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.square_arrow_right,
                          color: AppColors.primaryAccent,
                          size: 14.sp,
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            "Alight at ${leg.stops.last.name} around ${leg.endingTime}",
                            style: TextStyle(
                              color: AppColors.primaryText,
                              fontFamily: 'Poppins',
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );

    if (canToggle) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _showStops = !_showStops;
          });
        },
        child: IntrinsicHeight(child: tileContent),
      );
    }

    return IntrinsicHeight(child: tileContent);
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
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.w
      ..style = PaintingStyle.stroke;

    final double startY = 0;
    final double endY = size.height;
    final double midY = size.height * 0.7; // Transition color blend halfway down if next color exists

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
        // Draw top half with current leg color
        canvas.drawLine(
          Offset(size.width / 2, startY),
          Offset(size.width / 2, midY),
          paint,
        );
        // Draw bottom half with next leg color transition
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
