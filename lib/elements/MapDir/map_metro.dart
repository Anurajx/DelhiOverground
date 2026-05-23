import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:photo_view/photo_view.dart';
import 'package:metroapp/main.dart';

class MapMetroScreen extends StatefulWidget {
  const MapMetroScreen({super.key});

  @override
  State<MapMetroScreen> createState() => _MapMetroScreenState();
}

class _MapMetroScreenState extends State<MapMetroScreen> {
  bool _useVector2 = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PhotoView(
                imageProvider: AssetImage(
                  _useVector2
                      ? 'assets/Image/Vector2.png'
                      : 'assets/Image/Vector.png',
                ),
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.covered * 4.0,
                backgroundDecoration: const BoxDecoration(
                  color: Colors.black,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNavBar() {
    return Container(
      color: const Color.fromARGB(178, 0, 0, 0), // 70% opacity black
      padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
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
          Text(
            "Delhi Metro Map",
            style: TextStyle(
              color: AppColors.primaryText,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w600,
              fontSize: 16.sp,
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _useVector2 = !_useVector2;
              });
            },
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.arrow_2_circlepath,
                  color: AppColors.primaryAccent,
                  size: 16.sp,
                ),
                SizedBox(width: 4.w),
                Text(
                  _useVector2 ? "Map 1" : "Map 2",
                  style: TextStyle(
                    color: AppColors.primaryAccent,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                    fontSize: 14.sp,
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
