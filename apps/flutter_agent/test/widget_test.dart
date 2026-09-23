import 'package:flutter_test/flutter_test.dart';
import 'package:mdk_agent_desktop/main.dart';

void main() {
  testWidgets('renders the Agent Mode shell', (tester) async {
    await tester.pumpWidget(const MdkAgentApp());
    expect(find.text('MDK Agent'), findsOneWidget);
    expect(find.text('Agent Mode'), findsOneWidget);
    expect(find.text('Live workflow'), findsOneWidget);
  });
}
