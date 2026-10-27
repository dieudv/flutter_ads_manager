import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Wraps UMP (GDPR / US states) from google_mobile_ads.
class ConsentHelper {
  const ConsentHelper._();

  /// Updates consent info and shows the form if required. Never throws.
  static Future<void> gather({ConsentDebugSettings? debugSettings, bool tagForUnderAgeOfConsent = false}) {
    final done = Completer<void>();
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(
          consentDebugSettings: debugSettings,
          tagForUnderAgeOfConsent: tagForUnderAgeOfConsent,
        ),
        () {
          ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {
            if (error != null) debugPrint('[Ads] consent form error: ${error.message}');
            finish();
          });
        },
        (FormError error) {
          debugPrint('[Ads] consent info error: ${error.message}');
          finish();
        },
      );
    } catch (e) {
      debugPrint('[Ads] consent exception: $e');
      finish();
    }
    return done.future;
  }

  static Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  /// `true` if the app must show a "Privacy options" entry in Settings.
  static Future<bool> isPrivacyOptionsRequired() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  static Future<void> showPrivacyOptionsForm() {
    final done = Completer<void>();
    ConsentForm.showPrivacyOptionsForm((FormError? error) {
      if (error != null) debugPrint('[Ads] privacy options error: ${error.message}');
      if (!done.isCompleted) done.complete();
    });
    return done.future;
  }
}
