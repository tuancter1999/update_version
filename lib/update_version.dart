library update_version;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

enum MethodType { POST, GET }

class VersionStatus {
  final String localVersion;

  final String? storeVersion;

  final String appStoreLink;

  final String? releaseNotes;

  final bool isReviewVersion;

  bool get canUpdate {
    if (storeVersion == null) return false;
    try {
      final localFields = localVersion.split('.');
      final storeFields = storeVersion!.split('.');
      String localPad = '';
      String storePad = '';
      for (int i = 0; i < storeFields.length; i++) {
        localPad = localPad + localFields[i].padLeft(3, '0');
        storePad = storePad + storeFields[i].padLeft(3, '0');
      }
      if (localPad.compareTo(storePad) < 0)
        return true;
      else
        return false;
    } catch (e) {
      return localVersion.compareTo(storeVersion!).isNegative;
    }
  }

  VersionStatus._({
    required this.localVersion,
    required this.storeVersion,
    required this.appStoreLink,
    this.releaseNotes,
    this.isReviewVersion = false,
  });
}

class UpdateVersion {

  Future<VersionStatus?> getVersionStatus() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (Platform.isIOS) {
      return _getiOSStoreVersion(packageInfo);
    } else if (Platform.isAndroid) {
      return _getAndroidStoreVersion(packageInfo);
    } else {
      debugPrint('The target platform "${Platform.operatingSystem}" is not yet supported by this package.');
    }
  }

  Future<VersionStatus?> _getiOSStoreVersion(PackageInfo packageInfo) async {
    final id = packageInfo.packageName;
    final parameters = {"bundleId": "$id"};
    var uri = Uri.https("itunes.apple.com", "/lookup", parameters);
    Map<String, dynamic> _storeVersionGet = await getVersion(uri, MethodType.GET);
    Map<String, dynamic> _storeVersionPost = await getVersion(uri, MethodType.POST);
    Map<String, dynamic> _storeVersion = compareVersion(_storeVersionGet, _storeVersionPost);
    return VersionStatus._(
        localVersion: packageInfo.version,
        storeVersion: _storeVersion['storeVersion'],
        appStoreLink: _storeVersion['appStoreLink'],
        releaseNotes: _storeVersion['releaseNotes'],
        isReviewVersion: checkVersionReview(versionStore: _storeVersion['storeVersion'], versionLocal: packageInfo.version)
    );
  }

  Future<Map<String, dynamic>> getVersion(Uri uri, MethodType methodType) async {
    try {
      final _response;
      if (methodType == MethodType.GET)
        _response = await http.get(uri);
      else
        _response = await http.post(uri);
      final _jsonObj = json.decode(_response.body);
      String _version = _jsonObj['results'][0]['version'];
      return {
        'storeVersion' : _version,
        'appStoreLink' : _jsonObj['results'][0]['trackViewUrl'],
        'releaseNotes' : _jsonObj['results'][0]['releaseNotes'],
      };
    } catch (e) {
      return {};
    }
  }

  Map<String, dynamic> compareVersion(Map<String, dynamic> verObj1, Map<String, dynamic> verObj2) {
    String? ver1 = verObj1['storeVersion'];
    String? ver2 = verObj2['storeVersion'];
    if (ver1 == null && ver2 == null)
      return <String, dynamic>{};
    if (ver1 == null) return verObj2;
    if (ver2 == null) return verObj1;
    //compare
    try {
      List<String> _liVer1 = ver1.split('.');
      List<String> _liVer2 = ver2.split('.');
      for (int i = 0; i < _liVer1.length; ++ i) {
        if (int.parse(_liVer1[i]) > int.parse(_liVer2[i])) {
          return verObj1;
        } else if (int.parse(_liVer1[i]) < int.parse(_liVer2[i])) {
          return verObj2;
        }
      }
      return verObj1;
    } catch (e) {
      return <String, dynamic>{};
    }
  }

  bool checkVersionReview({ required String versionStore, required String versionLocal }) {
    try {
      List<String> _liVersionStore = versionStore.split('.');
      List<String> _liVersionLocal = versionLocal.split('.');
      for (int i = 0; i < _liVersionStore.length; ++ i) {
        if (int.parse(_liVersionStore[i]) > int.parse(_liVersionLocal[i])) {
          return false;
        } else if (int.parse(_liVersionStore[i]) < int.parse(_liVersionLocal[i])) {
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<VersionStatus?> _getAndroidStoreVersion(
      PackageInfo packageInfo) async {
    final id = packageInfo.packageName;
    final uri =
    Uri.https("play.google.com", "/store/apps/details", {"id": "$id"});
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Can\'t find an app in the Play Store with the id: $id');
      return null;
    }
    final document = parse(response.body);

    final additionalInfoElements = document.getElementsByClassName('hAyfc');
    final versionElement = additionalInfoElements.firstWhere(
          (elm) => elm.querySelector('.BgcNfc')!.text == 'Current Version',
    );
    final storeVersion = versionElement.querySelector('.htlgb')!.text;

    final sectionElements = document.getElementsByClassName('W4P4ne');
    final releaseNotesElement = sectionElements.firstWhereOrNull(
          (elm) => elm.querySelector('.wSaTQd')!.text == 'What\'s New',
    );
    final releaseNotes = releaseNotesElement
        ?.querySelector('.PHBdkd')
        ?.querySelector('.DWPxHb')
        ?.text;

    return VersionStatus._(
        localVersion: packageInfo.version,
        storeVersion: storeVersion,
        appStoreLink: uri.toString(),
        releaseNotes: releaseNotes,
        isReviewVersion: checkVersionReview(versionStore: storeVersion, versionLocal: packageInfo.version)
    );
  }

  void launchAppStore(String appStoreLink) async {
    debugPrint(appStoreLink);
    if (await canLaunch(appStoreLink)) {
      await launch(appStoreLink);
    } else {
      throw 'Could not launch appStoreLink';
    }
  }
}