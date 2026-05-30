import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:metroapp/elements/ServicesDir/station_element.dart';
import 'stop_info.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:string_similarity/string_similarity.dart';

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

  final Map<String, Map<String, dynamic>> _coreTransferStationsDict = {
    'Source': {},
  };

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode1.requestFocus();
    });

    Future.wait([_loadStationsFromJson(), _loadReconciledStops()]).then((
      results,
    ) {
      final stations = results[0] as List<dynamic>;
      final staticStopIdsWithRealtime = results[1] as Set<String>;

      final items =
          stations.map((station) {
            final Map<String, dynamic> stationMap = Map<String, dynamic>.from(
              station as Map,
            );
            final name = stationMap["Name"]?.toString().toLowerCase() ?? "";
            final hindi = stationMap["Hindi"]?.toString().toLowerCase() ?? "";
            final nameWords =
                name.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
            final hindiWords =
                hindi.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

            final stationCode = stationMap["StationCode"]?.toString() ?? "";
            final stopIds =
                stationCode.split(',').map((id) => id.trim()).toList();
            final hasRealtime = stopIds.any(
              (id) => staticStopIdsWithRealtime.contains(id),
            );

            return _StationSearchItem(
              station: stationMap,
              normalizedName: name,
              normalizedHindi: hindi,
              nameWords: nameWords,
              hindiWords: hindiWords,
              hasRealtime: hasRealtime,
            );
          }).toList();

      setState(() {
        _originalStations = stations;
        _searchItems = items;
        _filteredStations = stations;
      });
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
        _filteredStations = _originalStations;
      }
    });
  }

  Future<List> _loadStationsFromJson() async {
    try {
      final jsonRawData = await rootBundle.loadString(
        "assets/Map/stationsjson.json",
      );
      final List<dynamic> jsonList = jsonDecode(jsonRawData);
      return jsonList;
    } catch (e) {
      return [];
    }
  }

  Future<Set<String>> _loadReconciledStops() async {
    try {
      final reconciledStr = await rootBundle.loadString(
        'assets/reconciled_stops.json',
      );
      final List<dynamic> reconciledJson = jsonDecode(reconciledStr);
      final Set<String> staticStopIdsWithRealtime = {};
      for (final item in reconciledJson) {
        if (item['realtime_stop_id'] != null) {
          final staticId = item['static_stop_id']?.toString();
          if (staticId != null) {
            staticStopIdsWithRealtime.add(staticId);
          }
        }
      }
      return staticStopIdsWithRealtime;
    } catch (e) {
      return {};
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
        SizedBox(
          height: 50.h,
          child: GestureDetector(
            onTap: () {
              if (MediaQuery.of(context).viewInsets.bottom != 0) {
                FocusScope.of(context).unfocus();
                Navigator.pop(context);
              } else {
                Navigator.pop(context);
              }
            },
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.back,
                  color: const Color.fromARGB(255, 47, 130, 255),
                ),
                Text(
                  "Back",
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
        ),
      ],
    );
  }

  Widget _buildScreenName() {
    return Center(
      child: Text(
        "Stop Search",
        style: TextStyle(
          color: const Color.fromARGB(255, 220, 220, 220),
          fontSize: 20.sp,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildStationList() {
    if (_filteredStations.isEmpty) {
      return const Center(
        child: Column(
          children: [
            SizedBox(height: 30),
            Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: Color.fromARGB(255, 255, 145, 145),
            ),
            Text(
              "no matches found",
              style: TextStyle(
                color: Color.fromARGB(255, 255, 145, 145),
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Expanded(
      child: ListView.separated(
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
            children: [
              _buildBackBox(),
              _buildScreenName(),
              Stack(
                alignment: Alignment.centerLeft,
                children: [
                  Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 10, top: 20),
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
                        height: 1.h,
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
