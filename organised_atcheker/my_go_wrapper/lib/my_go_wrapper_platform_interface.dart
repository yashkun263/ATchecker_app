import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'my_go_wrapper_method_channel.dart';

abstract class MyGoWrapperPlatform extends PlatformInterface {
  /// Constructs a MyGoWrapperPlatform.
  MyGoWrapperPlatform() : super(token: _token);

  static final Object _token = Object();

  static MyGoWrapperPlatform _instance = MethodChannelMyGoWrapper();

  /// The default instance of [MyGoWrapperPlatform] to use.
  ///
  /// Defaults to [MethodChannelMyGoWrapper].
  static MyGoWrapperPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [MyGoWrapperPlatform] when
  /// they register themselves.
  static set instance(MyGoWrapperPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
