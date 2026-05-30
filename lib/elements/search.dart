import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:metroapp/main.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'bus_info.dart';
import 'package:provider/provider.dart';
import 'package:metroapp/elements/ServicesDir/data_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BusDatabaseHelper {
  static Database? _db;

  static Future<Database> getDatabase() async {
    if (_db != null && _db!.isOpen) return _db!;
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "routes.db");

    final prefs = await SharedPreferences.getInstance();
    final currentDbVersion = prefs.getInt('db_version_key') ?? 0;
    const targetDbVersion = 6; // Increment this whenever the database asset changes

    bool needsCopy = false;
    final exists = await databaseExists(path);
    if (!exists || currentDbVersion < targetDbVersion) {
      needsCopy = true;
    } else {
      try {
        final tempDb = await openDatabase(path, readOnly: true);
        final tables = await tempDb.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='routes'"
        );
        await tempDb.close();
        if (tables.isEmpty) {
          needsCopy = true;
        }
      } catch (e) {
        needsCopy = true;
      }
    }

    if (needsCopy) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // ignore
      }
      final data = await rootBundle.load("assets/routes.db");
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      await File(path).writeAsBytes(bytes, flush: true);
      await prefs.setInt('db_version_key', targetDbVersion);
    }

    _db = await openDatabase(path, readOnly: true);
    return _db!;
  }
}

class SearchScreen extends StatefulWidget {
  final String? destination;
  const SearchScreen({
    super.key,
    this.destination,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  @override
  Widget build(BuildContext context) {
    return const SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SearchBody(),
      ),
    );
  }
}

class SearchBody extends StatefulWidget {
  const SearchBody({super.key});

  @override
  State<SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<SearchBody> {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> _allRoutes = [];
  List<Map<String, dynamic>> _filteredRoutes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
    _loadInitialRoutes();
  }

  Future<void> _loadInitialRoutes() async {
    try {
      final db = await BusDatabaseHelper.getDatabase();
      final results = await db.rawQuery('''
        SELECT r.route_id, r.route_long_name, r.agency_id,
               r.end_stop as headsign
        FROM routes r
        ORDER BY r.route_long_name ASC
      ''');
      
      if (mounted) {
        setState(() {
          _allRoutes = List<Map<String, dynamic>>.from(results);
          _filteredRoutes = _allRoutes;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _searchRoutes(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredRoutes = _allRoutes;
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      final db = await BusDatabaseHelper.getDatabase();
      final results = await db.rawQuery('''
        SELECT r.route_id, r.route_long_name, r.agency_id,
               r.end_stop as headsign
        FROM routes r
        WHERE r.route_long_name LIKE ?
      ''', ['%$query%']);

      final sortedResults = List<Map<String, dynamic>>.from(results);
      final lowerQuery = query.toLowerCase().trim();
      sortedResults.sort((a, b) {
        final aName = (a['route_long_name'] as String).toLowerCase();
        final bName = (b['route_long_name'] as String).toLowerCase();
        
        if (aName == lowerQuery && bName != lowerQuery) return -1;
        if (bName == lowerQuery && aName != lowerQuery) return 1;
        
        final aStarts = aName.startsWith(lowerQuery);
        final bStarts = bName.startsWith(lowerQuery);
        if (aStarts && !bStarts) return -1;
        if (bStarts && !aStarts) return 1;
        
        final nameCmp = aName.compareTo(bName);
        if (nameCmp != 0) return nameCmp;

        final aAgency = (a['agency_id'] as String? ?? '').toLowerCase();
        final bAgency = (b['agency_id'] as String? ?? '').toLowerCase();
        return aAgency.compareTo(bAgency);
      });

      if (mounted) {
        setState(() {
          _filteredRoutes = sortedResults;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackBox(context),
          _buildScreenTitle(),
          _buildSearchField(),
          Divider(
            color: AppColors.divider,
            thickness: 0.2,
            height: 15.h,
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CupertinoActivityIndicator(color: Colors.white))
                : _buildRoutesList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackBox(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(0, 15.h, 15.w, 15.h),
          child: GestureDetector(
            onTap: () {
              if (MediaQuery.of(context).viewInsets.bottom != 0) {
                FocusScope.of(context).unfocus();
              }
              Navigator.pop(context);
            },
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.back,
                  color: AppColors.primaryAccent,
                  size: 20.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  "Back",
                  style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenTitle() {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Text(
        "Search Buses",
        style: TextStyle(
          color: AppColors.primaryText,
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          fontFamily: 'Poppins',
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: AppColors.whiteAccent,
        borderRadius: BorderRadius.zero, // NeoPop Sharp Corners
      ),
      height: 48.h,
      alignment: Alignment.centerLeft,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.search,
            color: AppColors.background,
            size: 20.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: TextField(
              textCapitalization: TextCapitalization.characters, // Bus numbers are often alphanumeric uppercase
              focusNode: _focusNode,
              controller: _controller,
              onChanged: _searchRoutes,
              decoration: InputDecoration.collapsed(
                border: InputBorder.none,
                hintText: "727",
                hintStyle: TextStyle(
                  color: const Color.fromARGB(150, 15, 15, 15),
                  fontWeight: FontWeight.w500,
                  fontSize: 15.sp,
                ),
              ),
              style: TextStyle(
                color: AppColors.background,
                fontSize: 16.sp,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_controller.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                _controller.clear();
                _searchRoutes("");
              },
              child: Icon(
                CupertinoIcons.clear,
                color: AppColors.background,
                size: 16.sp,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoutesList() {
    if (_filteredRoutes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_circle_fill,
              color: AppColors.destructive,
              size: 28.sp,
            ),
            SizedBox(height: 10.h),
            Text(
              "No matching routes found",
              style: TextStyle(
                color: AppColors.destructive,
                fontSize: 16.sp,
                fontWeight: FontWeight.w500,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _filteredRoutes.length,
      separatorBuilder: (context, index) => Divider(
        color: AppColors.divider,
        thickness: 0.5,
        height: 1,
      ),
      itemBuilder: (context, index) {
        final route = _filteredRoutes[index];
        final routeName = route['route_long_name'] as String;
        final agencyId = route['agency_id'] as String? ?? 'DTC';
        final headsign = route['headsign'] as String? ?? "";

        return InkWell(
          onTap: () {
            FocusScope.of(context).unfocus();
            final displaySubtitle = headsign.isNotEmpty
                ? "To $headsign"
                : "To Destination";
            Provider.of<DataProvider>(context, listen: false).addBusToHistory(
              route['route_id'] as String,
              routeName,
              displaySubtitle,
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BusInfoScreen(
                  routeId: route['route_id'] as String,
                  routeLongName: routeName,
                ),
              ),
            );
          },
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
            child: Row(
              children: [
                Container(
                  width: 36.w,
                  height: 24.h,
                  padding: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.zero,
                  ),
                  child: agencyId == 'DTC'
                      ? Image.asset(
                          'assets/Image/dtc.png',
                          fit: BoxFit.contain,
                        )
                      : Center(
                          child: Text(
                            "DIMTS",
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'Poppins',
                              letterSpacing: 0.5,
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
                        "Route $routeName",
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        headsign.isNotEmpty
                            ? "To $headsign"
                            : "To Destination",
                        style: TextStyle(
                          color: AppColors.secondaryText,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Poppins',
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
          ),
        );
      },
    );
  }
}
