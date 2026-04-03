import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class UpdateInfo {
  final String latestVersion;
  final String downloadUrl;
  final String releaseNotes;

  UpdateInfo({
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

class UpdateChecker {
  static const String repoOwner = 'yashkun263';
  static const String repoName = 'ATchecker_app';
  // Point to the raw version.txt on the main branch
  static const String vUrl = 'https://raw.githubusercontent.com/$repoOwner/$repoName/main/version.txt';
  static const String releasesUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';

  /// Checks for updates. Returns [UpdateInfo] if an update is available, null otherwise.
  /// Silently returns null if there are network issues.
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      // 1. Fetch the latest version string from version.txt
      final vResponse = await http.get(Uri.parse(vUrl));
      if (vResponse.statusCode != 200) return null;
      
      final latestVersion = vResponse.body.trim();
      if (latestVersion.isEmpty) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (!_isNewerVersion(latestVersion, currentVersion)) return null;

      // 2. Fetch the latest release to find the download URL
      final rResponse = await http.get(Uri.parse(releasesUrl));
      if (rResponse.statusCode == 200) {
        final data = jsonDecode(rResponse.body);
        final assets = data['assets'] as List;
        
        String? downloadUrl;
        for (var asset in assets) {
          if (asset['name'].toString().endsWith('.apk')) {
            downloadUrl = asset['browser_download_url'];
            break;
          }
        }

        if (downloadUrl != null) {
          return UpdateInfo(
            latestVersion: latestVersion,
            downloadUrl: downloadUrl,
            releaseNotes: data['body'] ?? 'New version $latestVersion available.',
          );
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
    }
    return null;
  }

  /// Simple version comparison logic.
  static bool _isNewerVersion(String latest, String current) {
    // Remove 'v' prefix if present
    final latestClean = latest.replaceFirst('v', '');
    final currentClean = current.replaceFirst('v', '');

    final latestParts = _parseVersion(latestClean);
    final currentParts = _parseVersion(currentClean);

    for (int i = 0; i < latestParts.length && i < currentParts.length; i++) {
      if (latestParts[i] > currentParts[i]) return true;
      if (latestParts[i] < currentParts[i]) return false;
    }
    
    return latestParts.length > currentParts.length;
  }

  static List<int> _parseVersion(String version) {
    return version.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  }

  /// Downloads the APK and triggers the installation.
  static Future<void> downloadAndInstallUpdate(
    String url, 
    Function(double progress) onProgress,
    Function(String error) onError,
  ) async {
    try {
      final tempDir = await getExternalStorageDirectory();
      if (tempDir == null) {
        onError("Could not access external storage");
        return;
      }
      
      final filePath = "${tempDir.path}/update.apk";
      final file = File(filePath);
      
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (count, total) {
          if (total != -1) {
            onProgress(count / total);
          }
        },
      );

      final result = await OpenFilex.open(filePath);
      if (result.type != ResultType.done) {
        onError("Failed to open APK: ${result.message}");
      }
    } catch (e) {
      onError("Download failed: $e");
    }
  }
}