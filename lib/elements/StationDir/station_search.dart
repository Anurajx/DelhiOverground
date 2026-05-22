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
  }); //if destination comes as an argument aslo calulate sopurce station with gps location if gps not available use homestation if that too now available leave that space empty

  @override
  State<StationSearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<StationSearchScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 8, 8, 8),
      body: SearchBody(context: context, destination: widget.destination),
      //resizeToAvoidBottomInset: true,
    );
  }
}

class SearchBody extends StatefulWidget {
  final dynamic context;
  final String? destination;

  const SearchBody({super.key, required this.context, this.destination});

  @override
  State<SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<SearchBody> {
  final FocusNode _focusNode1 = FocusNode();
  //final FocusNode _focusNode2 = FocusNode();
  final TextEditingController _controller1 = TextEditingController();
  //final TextEditingController _controller2 = TextEditingController();
  List<dynamic> orignalStations = [];
  List<dynamic> filteredStations = [];
  //bool _shouldClear = false;

  @override
  void initState() {
    super.initState();


    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode1.requestFocus();
    });
    loadStationsFromJson().then((stations) {
      setState(() {
        orignalStations = stations;
        filteredStations = stations;
      });
    });
  }

  @override
  void deactivate() {
    // when the router is poped and user goes back to home screen this is triggered
    super.deactivate();
    if (!Navigator.canPop(context)) {
      coreTransferStationsDict.clear();
    }
  }
  //////////////

  void filterStationsLogic(String query) {
    //TODO: MAKE THIS COMPAITABLE WITH JSON
    //Logiv to find the best match
    final lowerQuery = query.toLowerCase();

    setState(() {
      if (query.isNotEmpty) {
        // Create list of entries with scores
        final scoredList =
            orignalStations
                .where(
                  (station) =>
                      station["Name"] != null && station["Hindi"] != null,
                )
                //print("JSON STATIONS IS $orignalStations")
                .map((station) {
                  final name = station["Name"]?.toString().toLowerCase() ?? "";
                  final zone = station["Hindi"]?.toString().toLowerCase() ?? "";
                  print("JSON ZONE IS $zone");
                  final nameScore = StringSimilarity.compareTwoStrings(
                    name,
                    lowerQuery,
                  );
                  final zoneScore = StringSimilarity.compareTwoStrings(
                    zone,
                    lowerQuery,
                  );

                  // Combine both scores (weight name higher if needed)
                  final combinedScore = (nameScore + zoneScore);

                  return MapEntry(station, combinedScore);
                })
                .where(
                  (entry) =>
                      entry.value > 0.7 || // Similarity threshold
                      entry.key["Name"]?.toString().toLowerCase().contains(
                            lowerQuery,
                          ) ==
                          true || //checks if the query matches the name or hindi name/common name
                      entry.key["Hindi"]?.toString().toLowerCase().contains(
                            lowerQuery,
                          ) ==
                          true,
                )
                .toList();

        // Sort stations by score descending
        scoredList.sort((a, b) => b.value.compareTo(a.value));

        // Extract only the station entries
        filteredStations = scoredList.map((entry) => entry.key).toList();
      } else {
        filteredStations = orignalStations;
      }
    });
  }

  Future<List> loadStationsFromJson() async {
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            backBox(
              context,
              _controller1, //_controller2
            ), //leave as is
            screenName(), //leave as is
            Stack(
              //adding the search cluster here
              alignment: Alignment.centerLeft,
              children: [
                Column(
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: 10, top: 20),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 208, 208, 208),
                        //color: Color.fromARGB(255, 0, 0, 0),
                        ////color: const Color.fromARGB(255, 8, 8, 8),
                        border: Border.all(
                          color: const Color.fromARGB(255, 234, 234, 234),
                          width: 1.w,
                        ),
                        borderRadius: BorderRadius.circular(0), //40
                      ),
                      //width: double.infinity,
                      height: 45.h,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.fromLTRB(15, 0, 10, 0),
                            child: TextField(
                              textCapitalization:
                                  TextCapitalization
                                      .sentences, //makes the keyboard open with caps on for first letter
                              focusNode: _focusNode1,
                              cursorOpacityAnimates: true,
                              controller: _controller1,
                              onChanged: filterStationsLogic,
                              decoration: InputDecoration.collapsed(
                                border: InputBorder.none,
                                hintText: "Search",
                                hintStyle: TextStyle(
                                  color: const Color.fromARGB(200, 68, 68, 68),
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
                          //NEOPOP
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
                //fromToIcon(),
              ], //add flip circle function flipcircle()
            ),
            stationList(
              filteredStations,
              _controller1,
              //_controller2,
              _focusNode1,
              //_focusNode2,
            ),
          ],
        ),
      ),
    );
  }
}

backBox(
  BuildContext context,
  controller1, //controller2
) {
  return Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      SizedBox(
        //back button sized box
        height: 50.h,
        child: GestureDetector(
          onTap: () {
            HitTestBehavior.opaque;
            if (MediaQuery.of(context).viewInsets.bottom != 0) {
              //if keyboard is open it closes first then the screen goes back
              FocusScope.of(context).unfocus();
              Navigator.pop(context);
            } else {
              Navigator.pop(context);
            }
          },
          child: Row(
            children: [
              Icon(
                CupertinoIcons
                    .back, //check if the icon gesture detector working
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

screenName() {
  //Plan your trip box
  return Center(
    child: Text(
      "Enquiry",
      style: TextStyle(
        color: Color.fromARGB(255, 220, 220, 220),
        fontSize: 20.sp,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

Map<String, Map<String, dynamic>> coreTransferStationsDict = {
  //used for transfer screen process, making sure both source and destination are available
  //Dictionary format
  'Source': {}, //adding some defaults
  //'Destination': {},
};

Widget stationList(
  // widget that is expanded and scrollable of stations at bottom
  List<dynamic> stations,
  controller1,
  focusNode1,
) {
  if (stations.isEmpty) {
    return const Center(
      child: Column(
        children: [
          SizedBox(height: 30),
          //CupertinoActivityIndicator(color: Colors.white, radius: 15),
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
      itemCount: stations.length,
      itemBuilder: (context, index) {
        var station = stations[index];

        // Defensive check
        if (station.length < 3) {
          return const SizedBox(); // or some error placeholder
        }

        String line = station["Line"] ?? "";
        line = line.replaceAll(RegExp(r'[\[\]]'), '');
        List<String> lineNumbers = line.isNotEmpty ? line.split('-') : [];
        //List<int> lineNumbers = [1, 4];
        //HARD CODED LINE NUMBERS FOR NOW
        //print("Line numbers: $lineNumbers");
        String name = station["Name"]; // Station Name
        String hindiName =
            station["Hindi"]; // not hindiName actually hindi name

        return InkWell(
          focusColor: const Color.fromARGB(0, 255, 255, 255),
          splashColor: const Color.fromARGB(86, 76, 76, 76),
          onTap: () {
            if (focusNode1.hasFocus) {
              print("coreTransferStationsDict is focus node 2 fault");
              //inputs text in the text filed on tap
              controller1.text = name;
              //FocusScope.of(context).requestFocus(focusNode2);
              print("JSON TRIAL69 STATION CODE IS ${station}");
              coreTransferStationsDict['Source'] = //TODO: MAKE IT COMAPITABLE WITH TRAFER DICT SO THAT SUGGESTION ON HOMESCREEN ADAPT TO FORMAT
                  station;
              print(
                "JSON TRIAL69 STATION CODE coretransferdict IS ${coreTransferStationsDict}",
              );
              if (ifSourceSelected()) {
                screenTransferController(
                  context,
                  controller1, //changed
                  //controller2,
                );
              } else {
                //focusNode2.requestFocus();
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

screenTransferController(
  context,
  controller1, //controller2
) {
  String source = controller1.text;
  //String destination = controller2.text;
  //sends user to next route screen
  if (ifSourceSelected() && source.isNotEmpty) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => StopInfoScreen(stationDict: coreTransferStationsDict),
      ),
    );
    //checks for source and destination in dectinory and the text controller text if all are valid only then proceed and destination is not same as source
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
        onPressed: () {
          //if you think of anyhting that would be good for UX add here
        },
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}

bool ifSourceSelected() {
  //put these checks on different and opposite text fields
  try {
    return coreTransferStationsDict['Source']?.isNotEmpty ?? false;
  } catch (e) {
    return false;
  }
}
