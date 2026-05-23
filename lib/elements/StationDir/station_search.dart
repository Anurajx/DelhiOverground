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
  const StationSearchScreen({
    super.key,
    this.destination,
  });

  @override
  State<StationSearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<StationSearchScreen> {
  final FocusNode _focusNode1 = FocusNode();
  final TextEditingController _controller1 = TextEditingController();
  List<dynamic> _originalStations = [];
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
    _loadStationsFromJson().then((stations) {
      setState(() {
        _originalStations = stations;
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
    final lowerQuery = query.toLowerCase();

    setState(() {
      if (query.isNotEmpty) {
        final scoredList = _originalStations
            .where(
              (station) =>
                  station["Name"] != null && station["Hindi"] != null,
            )
            .map((station) {
              final name = station["Name"]?.toString().toLowerCase() ?? "";
              final zone = station["Hindi"]?.toString().toLowerCase() ?? "";
              final nameScore = StringSimilarity.compareTwoStrings(
                name,
                lowerQuery,
              );
              final zoneScore = StringSimilarity.compareTwoStrings(
                zone,
                lowerQuery,
              );

              final combinedScore = (nameScore + zoneScore);

              return MapEntry(station, combinedScore);
            })
            .where(
              (entry) =>
                  entry.value > 0.7 ||
                  entry.key["Name"]?.toString().toLowerCase().contains(
                        lowerQuery,
                      ) ==
                      true ||
                  entry.key["Hindi"]?.toString().toLowerCase().contains(
                        lowerQuery,
                      ) ==
                      true,
            )
            .toList();

        scoredList.sort((a, b) => b.value.compareTo(a.value));
        _filteredStations = scoredList.map((entry) => entry.key).toList();
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
          builder: (context) => StopInfoScreen(stationDict: _coreTransferStationsDict),
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
        "Enquiry",
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
          return const Divider(color: Color.fromARGB(255, 27, 27, 27), height: 1);
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
                                textCapitalization: TextCapitalization.sentences,
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
