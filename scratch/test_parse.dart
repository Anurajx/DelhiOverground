import 'dart:convert';

class ScheduleInfo {
  final String destination;
  final String lineId;
  final String lineColor;
  final String frequencyText;
  final int minutesLeft;
  final String relativeText;
  final String routeId;
  final String routeLongName;

  ScheduleInfo({
    required this.destination,
    required this.lineId,
    required this.lineColor,
    required this.frequencyText,
    required this.minutesLeft,
    required this.relativeText,
    required this.routeId,
    required this.routeLongName,
  });

  @override
  String toString() {
    return 'ScheduleInfo(route: $routeLongName, dest: $destination, mins: $minutesLeft, relative: $relativeText, time: $frequencyText)';
  }
}

List<ScheduleInfo> parseRealtimeHtml(String html) {
  final List<ScheduleInfo> results = [];
  
  // Split by the schedule section to only parse the live/upcoming departures
  String liveSection = html;
  final scheduleIndex = html.toLowerCase().indexOf('class="schedule"');
  if (scheduleIndex != -1) {
    liveSection = html.substring(0, scheduleIndex);
  }

  // Find all colcard blocks in the live section
  final colcardMatches = RegExp(
    r'<div\s+class="colcard">([\s\S]*?)(?=<div\s+class="colcard">|<div\s+class="headernames">|<div\s+class="logos">|<\/body>|<\/html>)',
    caseSensitive: false,
  ).allMatches(liveSection);

  final now = DateTime(2026, 6, 14, 15, 53, 0); // Mocked time to match the dump's 03:53 PM

  for (final match in colcardMatches) {
    final colcardHtml = match.group(1) ?? "";

    // 1. Extract route name
    final routeMatch = RegExp(
      r'class="route_info"[^>]*>\s*([^<]+?)\s*<br>',
      caseSensitive: false,
    ).firstMatch(colcardHtml);
    final routeName = routeMatch?.group(1)?.trim() ?? "";
    if (routeName.isEmpty) continue;

    // 2. Extract terminal/destination
    final terminalMatch = RegExp(
      r'class="terminal"[^>]*>\s*([^<]+?)\s*<\/span>',
      caseSensitive: false,
    ).firstMatch(colcardHtml);
    final terminal = terminalMatch?.group(1)?.trim() ?? "Terminal";

    // 3. Extract all ETAs
    final etaDivMatches = RegExp(
      r'<div\s+class="eta">([\s\S]*?)<\/div>',
      caseSensitive: false,
    ).allMatches(colcardHtml);

    for (final etaDivMatch in etaDivMatches) {
      final etaInnerHtml = etaDivMatch.group(1) ?? "";
      // Strip comments to avoid matching commented-out spans
      final cleanEtaHtml = etaInnerHtml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

      final spanMatch = RegExp(
        r'<span[^>]*>\s*:?(\w+)\s*<\/span>',
        caseSensitive: false,
      ).firstMatch(cleanEtaHtml);

      if (spanMatch != null) {
        final val = spanMatch.group(1)?.trim() ?? "";
        final int minutesLeft;
        if (val.toLowerCase() == "coming") {
          minutesLeft = 0;
        } else {
          minutesLeft = int.tryParse(val) ?? 0;
        }

        // Calculate absolute time
        final arrivalTime = now.add(Duration(minutes: minutesLeft));
        final amPm = arrivalTime.hour >= 12 ? "PM" : "AM";
        int hour = arrivalTime.hour % 12;
        if (hour == 0) hour = 12;
        final minuteStr = arrivalTime.minute.toString().padLeft(2, '0');
        final frequencyText = "$hour:$minuteStr $amPm";

        String relativeText;
        if (minutesLeft == 0) {
          relativeText = "Now";
        } else {
          relativeText = "In $minutesLeft mins";
        }

        results.add(
          ScheduleInfo(
            destination: terminal,
            lineId: "Route $routeName",
            lineColor: "Colors.blue",
            frequencyText: frequencyText,
            minutesLeft: minutesLeft,
            relativeText: relativeText,
            routeId: "",
            routeLongName: routeName,
          ),
        );
      }
    }
  }

  return results;
}

void main() {
  final htmlDump = '''
            
                <div class="colcard">
                    <span class="route_info">621<br><span class="terminal">Poorvanchal Hostel (T)</span></span>
<!--                    <span class="endstop">Poorvanchal Hostel (T)</span>-->
                    <div class="etas">
                    
                        <div class="eta">
                            
                                <span class="blink">coming</span>
<!--                                <span style="color: red">:01</span> -->
                            
                            <br><img class="bus" src="/static/images/light_blue_bus.png" alt="bus">
                        </div>
                    
                    </div>
                </div>
            
                <div class="colcard">
                    <span class="route_info">711A<br><span class="terminal">Uttam Nagar Terminal / Uttam Nagar East Metro Station</span></span>
                    <div class="etas">
                    
                        <div class="eta">
                                <span class="blink">coming</span>
                        </div>
                    
                        <div class="eta">
                                <span class="blink">coming</span>
                        </div>
                    
                    </div>
                </div>
            
                <div class="colcard">
                    <span class="route_info">544<br><span class="terminal">RK Puram Sec 1</span></span>
                    <div class="etas">
                    
                        <div class="eta">
                                <span>:07</span>
                        </div>
                    
                        <div class="eta">
                                <span>:23</span>
                        </div>
                    
                    </div>
                </div>
  </body>''';

  final schedules = parseRealtimeHtml(htmlDump);
  print('Parsed ${schedules.length} departures:');
  for (final s in schedules) {
    print(s);
  }
}
