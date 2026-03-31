import 'package:flutter_test/flutter_test.dart';
import 'package:my_go_wrapper/my_go_wrapper.dart';
import 'package:my_go_wrapper/my_go_wrapper_platform_interface.dart';
import 'package:my_go_wrapper/my_go_wrapper_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockMyGoWrapperPlatform
    with MockPlatformInterfaceMixin
    implements MyGoWrapperPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final MyGoWrapperPlatform initialPlatform = MyGoWrapperPlatform.instance;

  test('$MethodChannelMyGoWrapper is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelMyGoWrapper>());
  });

  test('getPlatformVersion', () async {
    MyGoWrapper myGoWrapperPlugin = MyGoWrapper();
    MockMyGoWrapperPlatform fakePlatform = MockMyGoWrapperPlatform();
    MyGoWrapperPlatform.instance = fakePlatform;

    expect(await myGoWrapperPlugin.getPlatformVersion(), '42');
  });
}
