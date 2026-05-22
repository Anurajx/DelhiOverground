import 'package:url_launcher/url_launcher.dart';

Future<void> sendToGoogleForm() async {
  final Uri formUrl = Uri.parse(
    'https://docs.google.com/forms/d/e/1FAIpQLSc-7GCGoizvjAuNl61Peu9YXkqQTHlAtHCmyPgSmIjYDx7Tqg/viewform?usp=dialog',
  );

  try {
    final launched = await launchUrl(
      formUrl,
      mode: LaunchMode.externalApplication, // required for external URLs
    );

    if (!launched) {
      throw Exception('Could not launch Google Form');
    }
  } catch (e) {
    print('Error launching form: $e');
  }
}
