import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_go_wrapper/my_go_wrapper_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelMyGoWrapper platform = MethodChannelMyGoWrapper();
  const MethodChannel channel = MethodChannel('my_go_wrapper');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });
}
