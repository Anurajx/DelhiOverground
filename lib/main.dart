import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:metroapp/elements/ServicesDir/data_provider.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:metroapp/elements/ServicesDir/stops_manager.dart';
import 'elements/metro.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:metroapp/elements/ServicesDir/env_service.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await StopsManager.init();
  final dataProvider = DataProvider();
  await dataProvider.loadBusSearchHistory();
  await dataProvider.loadJourneySearchHistory();


  // Set global status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ChangeNotifierProvider<DataProvider>.value(
      value: dataProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      // for an responsive design
      designSize: Size(411, 917), // Based on Samsung M33 5G
      minTextAdapt: true,
      useInheritedMediaQuery: true, // ✅ Ensure full media query inheritance
      builder: (context, child) {
        // had to use builder because the mediaquery was resulting to bugging of top status bar
        return MaterialApp(
          navigatorObservers: [
            PosthogObserver(),
          ],
          title: 'DTC Bus Service',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            fontFamily: 'Poppins',
            brightness: Brightness.dark,
            scaffoldBackgroundColor: AppColors.background,
            cardColor: AppColors.surface,
            dividerColor: AppColors.divider,
            primaryColor: AppColors.primaryAccent,
            colorScheme: ColorScheme.dark(
              primary: AppColors.primaryAccent,
              secondary: AppColors.secondaryAccent,
              error: AppColors.destructive,
              surface: AppColors.surface,
              onPrimary: AppColors.whiteAccent,
              onSecondary: AppColors.primaryText,
              onSurface: AppColors.primaryText,
              onError: AppColors.whiteAccent,
            ),
            //backgroundColor: AppColors.background,
            extensions: const [SkeletonizerConfigData.dark()],
            textTheme: TextTheme(
              bodyLarge: TextStyle(color: AppColors.primaryText),
              bodyMedium: TextStyle(
                fontFamily: "Poppins",
                fontWeight: FontWeight.w300,
                color: AppColors.secondaryText,
              ),
              bodySmall: TextStyle(color: AppColors.tertiaryText),
              // bodyMedium: TextStyle(
              //   fontFamily: "Poppins",
              //   fontWeight: FontWeight.w300,
              // ),
            ),
            textSelectionTheme: const TextSelectionThemeData(
              cursorColor: Color.fromARGB(255, 47, 130, 255),
              selectionColor: Color.fromARGB(150, 47, 130, 255),
              selectionHandleColor: Color.fromARGB(255, 47, 130, 255),
            ),
          ),
          home: AnnotatedRegion<SystemUiOverlayStyle>(
            // for top nav bar
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.black,
              statusBarIconBrightness: Brightness.light,
            ),
            child: Scaffold(
              backgroundColor: const Color.fromARGB(255, 0, 0, 0),

              //Color.fromARGB(255, 13, 13, 13),
              body: const SafeArea(child: HomeScreen()),
            ),
          ),
          builder: (context, widget) {
            // BUILDER TO Apply textScaler override here safely
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              //if user has set font size to be big or small this resets it
              data: mediaQuery.copyWith(textScaler: TextScaler.linear(1.0)),
              child: widget!,
            );
          },
        );
      },
    );
  }
}

class AppColors {
  // Backgrounds
  static const background = Color.fromARGB(255, 13, 13, 13); // #0D0D0D
  static const foreground = Color.fromARGB(255, 26, 26, 26); // #1A1A1A
  static const surface = Color.fromARGB(255, 30, 30, 30); // #1E1E1E
  static const inputBackground = Color.fromARGB(255, 42, 42, 42); // #2A2A2A
  static const inputBorder = Color.fromARGB(255, 58, 58, 58); // #3A3A3A
  static const divider = Color.fromARGB(255, 44, 44, 44); // #2C2C2C

  // Text
  static const primaryText = Color.fromARGB(255, 240, 240, 240); // #F0F0F0
  static const secondaryText = Color.fromARGB(255, 176, 176, 176); // #B0B0B0
  static const tertiaryText = Color.fromARGB(255, 112, 112, 112); // #707070

  // Accent & Feedback
  static const primaryAccent = Color.fromARGB(255, 59, 130, 246); // #3B82F6
  static const secondaryAccent = Color.fromARGB(255, 16, 185, 129); // #10B981
  static const destructive = Color.fromARGB(255, 239, 68, 68); // #EF4444
  static const warning = Color.fromARGB(255, 245, 158, 11); // #F59E0B
  static const info = Color.fromARGB(255, 14, 165, 233); // #0EA5E9

  // Overlay Effects
  static const hoverOverlay = Color.fromARGB(13, 255, 255, 255); // #FFFFFF0D
  static const activeOverlay = Color.fromARGB(26, 255, 255, 255); // #FFFFFF1A

  // White Accent
  static const whiteAccent = Color.fromARGB(255, 245, 245, 245); // #F5F5F5
}
