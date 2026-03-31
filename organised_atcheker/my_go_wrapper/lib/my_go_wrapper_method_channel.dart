import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'my_go_wrapper_platform_interface.dart';

/// An implementation of [MyGoWrapperPlatform] that uses method channels.
class MethodChannelMyGoWrapper extends MyGoWrapperPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('my_go_wrapper');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
