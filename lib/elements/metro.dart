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
      onTap: () {},
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
}
