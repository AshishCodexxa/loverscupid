import 'dart:io';

import 'package:dating_app/constants/constants.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:share/share.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:dating_app/models/user_model.dart';
import 'package:dating_app/models/app_model.dart';

class AppHelper {
  /// Local variables
  final _firestore = FirebaseFirestore.instance;

  /// Check current User VIP Account status
  /// Restore VIP Account Subscription
  Future<void> restoreVipAccount({
    VoidCallback? onSuccess,
    VoidCallback? onNotFound,
  }) async {
    // Query past subscriptions
    InAppPurchaseConnection.instance
        .queryPastPurchases()
        .then((QueryPurchaseDetailsResponse pastPurchases) {
      // Chek past purchases result
      if (pastPurchases.pastPurchases.isNotEmpty) {
        for (var purchase in pastPurchases.pastPurchases) {
          /// Updae User VIP Status to true
          UserModel().setUserVip();
          // Set Vip Subscription Id
          UserModel().setActiveVipId(purchase.productID);
          // Debug
          print('Active VIP SKU: ${purchase.productID}');
          // Success Callback
          if (onSuccess != null) {
            onSuccess();
          }
        }
      } else {
        print('No Active VIP Subscription');
        // Not found Callback
        if (onNotFound != null) {
          onNotFound();
        }
      }
    });
  }

  /// Check and request location permission
  Future<void> checkLocationPermission(
      {required VoidCallback onGpsDisabled,
      required VoidCallback onDenied,
      required VoidCallback onGranted}) async {
    /// Check if GPS is enabled
    if (!(await Geolocator.isLocationServiceEnabled())) {
      // Callback function
      onGpsDisabled();
      debugPrint('onGpsDisabled() -> disabled');
      return Future.value();
    } else {
      /// Get permission status
      LocationPermission permission = await Geolocator.checkPermission();

      // This is the initial state on both Android and iOS
      if (permission == LocationPermission.denied) {
        /// Request permission
        permission = await Geolocator.requestPermission();
        // Check the result
        if (permission == LocationPermission.denied) {
          onDenied();
          debugPrint('permission: denied');
          return Future.value();
        }
      }

      // Location permissions are permanently denied, we cannot request permissions.
      if (permission == LocationPermission.deniedForever) {
        onDenied();
        debugPrint('permission: deniedForever');
        return Future.value();
      }

      // Location permissions are granted, we can get current user location
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        onGranted();
        debugPrint('Permission: granted -> status: $permission');
        return Future.value();
      }
    }
  }

  /// Get User location from formatted address
  Future<Placemark> getUserAddress(double latitude, double longitude) async {
    // Get Placemark to retrieve user formatted location address info
    // and returns the first place
    return (await placemarkFromCoordinates(latitude, longitude)).first;
  }

  /// Get distance between current user and another user
  /// Returns distance in (Kilometers - KM)
  int getDistanceBetweenUsers(
      {required double userLat, required double userLong}) {
    /// Get instance of [Geoflutterfire]
    final Geoflutterfire geo = new Geoflutterfire();

    /// Set current user location [GeoFirePoint]
    final GeoFirePoint center = geo.point(
        latitude: UserModel().user.userGeoPoint.latitude,
        longitude: UserModel().user.userGeoPoint.longitude);

    /// Return distance (double) between users then round to int
    return center.distance(lat: userLat, lng: userLong).round();
  }

  /// Get app store URL - Google Play / Apple Store
  String get _appStoreUrl {
    // Variables
    String url = "";
    final String androidPackageName = AppModel().appInfo.androidPackageName;
    final String iOsAppId = AppModel().appInfo.iOsAppId;

    // Check device OS
    if (Platform.isAndroid) {
      url = "https://play.google.com/store/apps/details?id=$androidPackageName";
    } else if (Platform.isIOS) {
      url = "https://apps.apple.com/app/id$iOsAppId";
    }
    return url;
  }

  /// Get app current version from Cloud Firestore Database,
  /// that is the same with Google Play Store / Apple Store app version
  Future<int> getAppStoreVersion() async {
    final DocumentSnapshot<Map<String, dynamic>> appInfo =
        await _firestore.collection(C_APP_INFO).doc('settings').get();
    // Update AppInfo object
    AppModel().setAppInfo(appInfo.data() ?? {});
    // Check Platform
    if (Platform.isAndroid) {
      return appInfo.data()?[ANDROID_APP_CURRENT_VERSION] ?? 1;
    } else if (Platform.isIOS) {
      return appInfo.data()?[IOS_APP_CURRENT_VERSION] ?? 1;
    }
    return 1;
  }

  /// Update app info data in database
  Future<void> updateAppInfo(Map<String, dynamic> data) async {
    // Update app data
    _firestore.collection(C_APP_INFO).doc('settings').update(data);
  }

  /// Share app method
  Future<void> shareApp() async {
    Share.share(_appStoreUrl);
  }

  /// Review app method
  Future<void> reviewApp() async {
    // Check OS and get correct url
    final String url =
        Platform.isIOS ? "$_appStoreUrl?action=write-review" : _appStoreUrl;
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw "Could not launch $url";
    }
  }

  /// Open app store - Google Play / Apple Store
  Future<void> openAppStore() async {
    if (await canLaunch(_appStoreUrl)) {
      await launch(_appStoreUrl);
    } else {
      throw "Could not open app store url....";
    }
  }

  /// Open Privacy Policy Page in Browser
  Future<void> openPrivacyPage() async {
    // Get url
    final String privacyUrl = AppModel().appInfo.privacyPolicyUrl;

    try {
      // Try to launch url
      if (await canLaunch(privacyUrl)) {
        await launch(privacyUrl);
      }
    } catch (e) {
      print("Could not launch url -> $privacyUrl, error: $e");
    }
  }

  /// Open Terms of Services in Browser
  Future<void> openTermsPage() async {
    // Get url
    final String termsUrl = AppModel().appInfo.termsOfServicesUrl;

    try {
      // Try to launch url
      if (await canLaunch(termsUrl)) {
        await launch(termsUrl);
      }
    } catch (e) {
      print("Could not launch url -> $termsUrl, error: $e");
    }
  }
}
