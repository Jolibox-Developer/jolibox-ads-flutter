import 'package:flutter/services.dart';

class ExampleNativeInitialization {
  const ExampleNativeInitialization._();

  static const _channel =
      MethodChannel('jolibox_ads_flutter_example/initialization');

  static Future<ExampleNativeInitializationSnapshot> fetch() async {
    try {
      final response = await _channel.invokeMapMethod<String, dynamic>(
        'getInitializationState',
      );
      return ExampleNativeInitializationSnapshot(
        state: response?['state'] as String? ?? 'unavailable',
        message: response?['message'] as String? ??
            'Native initialization state is unavailable.',
      );
    } on PlatformException catch (error) {
      return ExampleNativeInitializationSnapshot(
        state: 'unavailable',
        message:
            'Could not read native initialization state: ${error.message ?? error.code}',
      );
    } catch (error) {
      return ExampleNativeInitializationSnapshot(
        state: 'unavailable',
        message: 'Could not read native initialization state: $error',
      );
    }
  }
}

class ExampleNativeInitializationSnapshot {
  const ExampleNativeInitializationSnapshot({
    required this.state,
    required this.message,
  });

  final String state;
  final String message;

  bool get isReady => state == 'ready';

  bool get isTerminal => state != 'initializing';
}
