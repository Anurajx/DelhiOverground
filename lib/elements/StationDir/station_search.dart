import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:metroapp/elements/ServicesDir/station_element.dart';
import 'stop_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:string_similarity/string_similarity.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:metroapp/elements/ServicesDir/data_provider.dart';
import 'package:metroapp/main.dart';
import 'package:metroapp/elements/ServicesDir/stops_manager.dart';


class StationSearchScreen extends StatefulWidget {
  final String? destination;
  const StationSearchScreen({super.key, this.destination});

  @override
  State<StationSearchScreen> createState() => _SearchScreenState();
}

class _StationSearchItem {
  final Map<String, dynamic> station;
  final String normalizedName;
  final String normalizedHindi;
  final List<String> nameWords;
  final List<String> hindiWords;
  final bool hasRealtime;

  _StationSearchItem({
    required this.station,
    required this.normalizedName,
    required this.normalizedHindi,
    required this.nameWords,
    required this.hindiWords,
    required this.hasRealtime,
  });
}

class _SearchScreenState extends State<StationSearchScreen> {
  final FocusNode _focusNode1 = FocusNode();
  final TextEditingController _controller1 = TextEditingController();
  List<dynamic> _originalStations = [];
  List<_StationSearchItem> _searchItems = [];
  List<dynamic> _filteredStations = [];
  List<dynamic> _nearestStations = [];
  bool _isLoadingLocation = false;

  final Map<String, Map<String, dynamic>> _coreTransferStationsDict = {
    'Source': {},
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode1.requestFocus();
    });

    final stations = StopsManager.getStations();
    final items = stations.map((station) {
      final Map<String, dynamic> stationMap = Map<String, dynamic>.from(
        station as Map,
      );
      final name = stationMap["Name"]?.toString().toLowerCase() ?? "";
      final hindi = stationMap["Hindi"]?.toString().toLowerCase() ?? "";
      final nameWords =
          name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      final hindiWords =
          hindi.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

      return _StationSearchItem(
        station: stationMap,
        normalizedName: name,
        normalizedHindi: hindi,
        nameWords: nameWords,
        hindiWords: hindiWords,
        hasRealtime: true,
      );
    }).toList();

    setState(() {
      _originalStations = stations;
      _searchItems = items;
      _filteredStations = [];
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _determineNearestStops();
    });
  }

  @override
  void deactivate() {
    super.deactivate();
    if (!Navigator.canPop(context)) {
      _coreTransferStationsDict.clear();
    }
  }

  void _filterStationsLogic(String query) {
    final cleanQuery = query.trim().toLowerCase();

    setState(() {
      if (cleanQuery.isNotEmpty) {
        final List<MapEntry<_StationSearchItem, double>> scoredList = [];

        for (final item in _searchItems) {
          double score = 0.0;
          bool matched = false;

          final name = item.normalizedName;
          final hindi = item.normalizedHindi;

          // 1. Exact Match
          if (name == cleanQuery || hindi == cleanQuery) {
            score += 10000.0;
            matched = true;
          }

          // 2. Prefix Match of Full Name
          if (name.startsWith(cleanQuery) || hindi.startsWith(cleanQuery)) {
            score +=
                5000.0 +
                (100.0 *
                    cleanQuery.length /
                    (name.isNotEmpty ? name.length : 1));
            matched = true;
          }

          // 3. Prefix Match of Individual Words
          int wordIndex = 0;
          for (final word in item.nameWords) {
            if (word.startsWith(cleanQuery)) {
              final wordBonus =
                  wordIndex == 0 ? 3500.0 : 3000.0 - (wordIndex * 100.0);
              score =
                  score > wordBonus
                      ? score
                      : wordBonus + (100.0 * cleanQuery.length / word.length);
              matched = true;
            }
            wordIndex++;
          }

          wordIndex = 0;
          for (final word in item.hindiWords) {
            if (word.startsWith(cleanQuery)) {
              final wordBonus =
                  wordIndex == 0 ? 3500.0 : 3000.0 - (wordIndex * 100.0);
              score =
                  score > wordBonus
                      ? score
                      : wordBonus + (100.0 * cleanQuery.length / word.length);
              matched = true;
            }
            wordIndex++;
          }

          // 4. Substring Match
          if (name.contains(cleanQuery) || hindi.contains(cleanQuery)) {
            final substringScore =
                1000.0 +
                (100.0 *
                    cleanQuery.length /
                    (name.isNotEmpty ? name.length : 1));
            score = score > substringScore ? score : substringScore;
            matched = true;
          }

          // 5. Fuzzy Match (Dice's coefficient) - only run for query length >= 3
          if (cleanQuery.length >= 3) {
            double maxSimilarity = 0.0;
            bool fuzzyMatched = false;

            // Full-name similarity
            final nameSimilarity = StringSimilarity.compareTwoStrings(
              name,
              cleanQuery,
            );
            final hindiSimilarity = StringSimilarity.compareTwoStrings(
              hindi,
              cleanQuery,
            );
            final maxFullNameSim =
                nameSimilarity > hindiSimilarity
                    ? nameSimilarity
                    : hindiSimilarity;
            if (maxFullNameSim > 0.35) {
              maxSimilarity = maxFullNameSim;
              fuzzyMatched = true;
            }

            // Word-level similarity
            for (final word in item.nameWords) {
              if (word.length >= 3) {
                final sim = StringSimilarity.compareTwoStrings(
                  word,
                  cleanQuery,
                );
                if (sim > 0.5 && sim > maxSimilarity) {
                  maxSimilarity = sim;
                  fuzzyMatched = true;
                }
              }
            }
            for (final word in item.hindiWords) {
              if (word.length >= 3) {
                final sim = StringSimilarity.compareTwoStrings(
                  word,
                  cleanQuery,
                );
                if (sim > 0.5 && sim > maxSimilarity) {
                  maxSimilarity = sim;
                  fuzzyMatched = true;
                }
              }
            }

            if (fuzzyMatched) {
              final fuzzyScore = maxSimilarity * 400.0;
              score = score > fuzzyScore ? score : fuzzyScore;
              matched = true;
            }
          }

          if (matched) {
            scoredList.add(MapEntry(item, score));
          }
        }

        // Sort scored items in descending order
        scoredList.sort((a, b) => b.value.compareTo(a.value));

        // Realtime stops filter and fallback:
        // Only show results of stops that have realtime_stop_id available.
        // If no stop meeting that criteria can be found, then show stops without it.
        final hasAnyRealtime = scoredList.any((entry) => entry.key.hasRealtime);
        final List<MapEntry<_StationSearchItem, double>> finalScoredList;
        if (hasAnyRealtime) {
          finalScoredList =
              scoredList.where((entry) => entry.key.hasRealtime).toList();
        } else {
          finalScoredList = scoredList;
        }

        _filteredStations =
            finalScoredList.map((entry) => entry.key.station).toList();
      } else {
        _filteredStations = _nearestStations.isNotEmpty ? _nearestStations : _originalStations;
      }
    });
  }

  Future<void> _determineNearestStops() async {
    if (!mounted) return;
    try {
      setState(() {
        _isLoadingLocation = true;
      });

      final dataProvider = Provider.of<DataProvider>(context, listen: false);
      final nearDict = dataProvider.coreNearestStationsDict;
      Position? position;
      if (nearDict['UserLocation'] != null && nearDict['UserLocation']!.isNotEmpty) {
        position = nearDict['UserLocation']!.first as Position;
      }

      if (position == null) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
          setState(() {
            _isLoadingLocation = false;
            if (_controller1.text.trim().isEmpty) {
              _filteredStations = _originalStations;
            }
          });
          return;
        }

        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 4),
          ),
        );
      }

      final double userLat = position.latitude;
      final double userLon = position.longitude;

      // Filter: stations that have realtime_stop_id available
      final List<_StationSearchItem> candidateItems =
          _searchItems.where((item) => item.hasRealtime).toList();

      // Sort by distance
      candidateItems.sort((a, b) {
        final double latA = double.tryParse(a.station["Latitude"]?.toString() ?? "0.0") ?? 0.0;
        final double lonA = double.tryParse(a.station["Longitude"]?.toString() ?? "0.0") ?? 0.0;
        final double latB = double.tryParse(b.station["Latitude"]?.toString() ?? "0.0") ?? 0.0;
        final double lonB = double.tryParse(b.station["Longitude"]?.toString() ?? "0.0") ?? 0.0;

        final double distA = Geolocator.distanceBetween(userLat, userLon, latA, lonA);
        final double distB = Geolocator.distanceBetween(userLat, userLon, latB, lonB);
        return distA.compareTo(distB);
      });

      final top3 = candidateItems.take(3).map((item) => item.station).toList();

      if (mounted) {
        setState(() {
          _nearestStations = top3;
          _isLoadingLocation = false;
          if (_controller1.text.trim().isEmpty) {
            _filteredStations = _nearestStations.isNotEmpty ? _nearestStations : _originalStations;
          }
        });
      }
    } catch (e) {
      debugPrint("Error determining nearest stops: $e");
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          if (_controller1.text.trim().isEmpty) {
            _filteredStations = _originalStations;
          }
        });
      }
    }
  }



  bool _ifSourceSelected() {
    try {
      return _coreTransferStationsDict['Source']?.isNotEmpty ?? false;
    } catch (e) {
      return false;
    }
  }

  void _screenTransferController() {
    String source = _controller1.text;
    if (_ifSourceSelected() && source.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) =>
                  StopInfoScreen(stationDict: _coreTransferStationsDict),
        ),
      );
    } else {
      final snackBar = SnackBar(
        backgroundColor: const Color.fromARGB(255, 31, 200, 127),
        content: const Text(
          'Please select station for enquiry correctly',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w300,
            fontFamily: "Poppins",
          ),
        ),
        action: SnackBarAction(
          backgroundColor: Colors.black,
          label: 'Okay',
          textColor: Colors.white,
          onPressed: () {},
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(snackBar);
    }
  }

  Widget _buildBackBox() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Transform.translate(
          offset: Offset(-8.w, 0),
          child: BackButton(
            color: AppColors.primaryAccent,
            onPressed: () {
              if (MediaQuery.of(context).viewInsets.bottom != 0) {
                FocusScope.of(context).unfocus();
              }
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
        "Stop Search",
        style: TextStyle(
          color: AppColors.primaryText,
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildStationList() {
    if (_isLoadingLocation && _filteredStations.isEmpty) {
      return const Expanded(
        child: Center(
          child: CupertinoActivityIndicator(
            color: Colors.white,
            radius: 14,
          ),
        ),
      );
    }

    if (_filteredStations.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 30),
            ClipRRect(
              borderRadius: BorderRadius.circular(3.r),
              child: Image.asset(
                'assets/Image/dtcaccident.png',
                height: 100.h,
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 16.h),
            Text(
              "no matches found :(",
              style: TextStyle(
                color: AppColors.primaryAccent,
                fontSize: 20.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final bool showingNearby = _controller1.text.trim().isEmpty &&
        _nearestStations.isNotEmpty &&
        _filteredStations == _nearestStations;

    final listView = Expanded(
      child: ListView.separated(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: EdgeInsets.zero,
        itemCount: _filteredStations.length,
        itemBuilder: (context, index) {
          var station = _filteredStations[index];

          if (station.length < 3) {
            return const SizedBox();
          }

          String line = station["Line"] ?? "";
          line = line.replaceAll(RegExp(r'[\[\]]'), '');
          List<String> lineNumbers = line.isNotEmpty ? line.split('-') : [];
          String name = station["Name"];
          String hindiName = station["Hindi"];

          return InkWell(
            focusColor: const Color.fromARGB(0, 255, 255, 255),
            splashColor: const Color.fromARGB(86, 76, 76, 76),
            onTap: () {
              if (_focusNode1.hasFocus) {
                _controller1.text = name;
                _coreTransferStationsDict['Source'] = station;
                if (_ifSourceSelected()) {
                  _screenTransferController();
                }
              }
            },
            child: StationUnit(
              name: name,
              hindiName: hindiName,
              lines: lineNumbers,
            ),
          );
        },
        separatorBuilder: (context, index) {
          return const Divider(
            color: Color.fromARGB(255, 27, 27, 27),
            height: 1,
          );
        },
      ),
    );

    if (showingNearby) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 14.h, bottom: 6.h, left: 8.w),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45),
                    width: 1.0,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  "Stops near you",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            listView,
          ],
        ),
      );
    }

    return listView;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 8, 8, 8),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildBackBox(),
              _buildScreenTitle(),
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Column(
                    children: [
                      Container(
                        margin: EdgeInsets.only(bottom: 4.h),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 208, 208, 208),
                          border: Border.all(
                            color: const Color.fromARGB(255, 234, 234, 234),
                            width: 1.w,
                          ),
                          borderRadius: BorderRadius.circular(0),
                        ),
                        height: 45.h,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.fromLTRB(15, 0, 10, 0),
                              child: TextField(
                                textCapitalization:
                                    TextCapitalization.sentences,
                                focusNode: _focusNode1,
                                cursorOpacityAnimates: true,
                                controller: _controller1,
                                onChanged: _filterStationsLogic,
                                decoration: const InputDecoration.collapsed(
                                  border: InputBorder.none,
                                  hintText: "Search",
                                  hintStyle: TextStyle(
                                    color: Color.fromARGB(200, 68, 68, 68),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                style: TextStyle(
                                  color: const Color.fromARGB(225, 15, 15, 15),
                                  fontSize: 18.sp,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Divider(
                        color: const Color.fromARGB(255, 130, 130, 130),
                        thickness: 0.2,
                        height: 4.h,
                      ),
                    ],
                  ),
                ],
              ),
              _buildStationList(),
            ],
          ),
        ),
      ),
    );
  }
}
