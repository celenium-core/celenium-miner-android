// Classic integration driver: lets `flutter drive` run the
// integration_test/ targets on the emulator and report results to the host.
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
