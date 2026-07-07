import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

class PostHogService {
  // --- Lifecycle Events ---
  static void trackAppOpened() {
    _capture('app_opened');
  }

  static void trackAppBackgrounded() {
    _capture('app_backgrounded');
  }

  static void trackAppForegrounded() {
    _capture('app_foregrounded');
  }

  static void trackAppClosed() {
    _capture('app_closed');
  }

  // --- Navigation Events ---
  static void trackScreenViewed(String screenName) {
    _capture('screen_viewed', {'screen_name': screenName});
  }

  static void trackTabChanged(String tabName) {
    _capture('tab_changed', {'tab_name': tabName});
  }

  static void trackMenuItemClicked(String menuItemName) {
    _capture('menu_item_clicked', {'menu_item_name': menuItemName});
  }

  // --- User Engagement Events ---
  static void trackButtonClicked(String buttonName, [Map<String, Object>? additionalProperties]) {
    final props = <String, Object>{'button_name': buttonName};
    if (additionalProperties != null) {
      props.addAll(additionalProperties);
    }
    _capture('button_clicked', props);
  }

  static void trackSearchPerformed(String searchType, String query) {
    _capture('search_performed', {
      'search_type': searchType,
      'query': query,
    });
  }

  static void trackFilterApplied(String filterName, String selectedValue) {
    _capture('filter_applied', {
      'filter_name': filterName,
      'selected_value': selectedValue,
    });
  }

  // --- Error Monitoring Events ---
  static void trackApiError(String endpoint, String errorMessage, [int? statusCode]) {
    _capture('api_error', {
      'endpoint': endpoint,
      'error_message': errorMessage,
      if (statusCode != null) 'status_code': statusCode,
    });
  }

  static void trackAppException(dynamic exception, [StackTrace? stackTrace]) {
    _capture('app_exception', {
      'exception_type': exception.runtimeType.toString(),
      'exception_message': exception.toString(),
      if (stackTrace != null) 'stack_trace': stackTrace.toString(),
    });
  }

  static void trackValidationError(String fieldName, String errorMessage) {
    _capture('validation_error', {
      'field_name': fieldName,
      'error_message': errorMessage,
    });
  }

  // Private helper to send to PostHog
  static void _capture(String eventName, [Map<String, Object>? properties]) {
    try {
      debugPrint('[PostHogService] Capturing event: $eventName, properties: $properties');
      Posthog().capture(
        eventName: eventName,
        properties: properties,
      );
    } catch (e, stack) {
      debugPrint('[PostHogService] Error capturing event: $e\n$stack');
    }
  }
}
