import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final srcLat = 28.507767;
  final srcLon = 77.242589;
  final dstLat = 28.5829873;
  final dstLon = 77.2416624;
  final srcType = 'place';
  final dstType = 'place';
  final mode = 'bus';
  final time = '09:31:30';

  final srcEncoded = '%5B$srcLat,$srcLon%5D';
  final dstEncoded = '%5B$dstLat,$dstLon%5D';
  final srcTypeEncoded = Uri.encodeComponent(srcType);
  final dstTypeEncoded = Uri.encodeComponent(dstType);
  final modeEncoded = Uri.encodeComponent(mode);
  final timeEncoded = Uri.encodeComponent(time);

  final baseUrl = 'https://dts-backend.transportstack.in';
  final requestUrl = '$baseUrl/api/serviceset/journey-planner/multi_modal'
      '?src=$srcEncoded'
      '&src_type=$srcTypeEncoded'
      '&dst=$dstEncoded'
      '&dst_type=$dstTypeEncoded'
      '&mode=$modeEncoded'
      '&time=$timeEncoded';

  print('Original string: $requestUrl');
  final uri = Uri.parse(requestUrl);
  print('Uri.parse result: $uri');
  print('Uri.parse queryParameters: ${uri.queryParameters}');
  
  try {
    final response = await http.get(
      uri,
      headers: {
        'x-api-key': 'hsrNV2fU3I9O774q02X1BgGOf8T3f7vlbzdFjXSRB6Y=',
      },
    );
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
