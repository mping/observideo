import "package:flutter_test/flutter_test.dart";
import "package:observideo/localization/app_strings.dart";
import "package:observideo/main.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppStrings strings;

  setUpAll(() async {
    strings = await AppStrings.load();
  });

  testWidgets("displays the startup failure message", (tester) async {
    await tester.pumpWidget(StartupFailureApp(strings: strings));

    expect(find.text(strings.text("startup_failure_title")), findsOneWidget);
    expect(find.text(strings.text("startup_failure_message")), findsOneWidget);
  });
}
