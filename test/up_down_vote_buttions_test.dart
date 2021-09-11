import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myapp/widgets/up_down_vote_buttons.dart';

void main() {
  Widget sut;

  group('UpDownVoteButtons', () {
    setUpAll(() async {
      // Build our app and trigger a frame.
      sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Scaffold(
            body: UpDownVoteButtons(voteStateInit: 0),
          ),
        ),
      );
    });

    final verifier = (WidgetTester tester, int state) {
      final upDownVoteButtons =
          tester.state<UpDownVoteButtonsState>(find.byType(UpDownVoteButtons));
      expect(upDownVoteButtons.voteState, equals(state));
      final upButton = tester
          .element(find.byIcon(Icons.thumb_up))
          .findAncestorWidgetOfExactType<IconButton>();
      expect(upButton.color, state > 0 ? Colors.blueAccent : Colors.grey);
      final downButton = tester
          .element(find.byIcon(Icons.thumb_down))
          .findAncestorWidgetOfExactType<IconButton>();
      expect(downButton.color, state < 0 ? Colors.blueAccent : Colors.grey);
    };

    testWidgets('buttons initializes correctly', (WidgetTester tester) async {
      await tester.pumpWidget(sut);

      expect(find.byIcon(Icons.thumb_up), findsOneWidget);
      expect(find.byIcon(Icons.thumb_down), findsOneWidget);
      verifier(tester, 0);
    });

    testWidgets('Verify thumb_up button is selected and its color is changed',
        (WidgetTester tester) async {
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_up));
      await tester.pumpWidget(sut);

      verifier(tester, 1);
    });

    testWidgets('Verify thumb_down button is selected and its color is changed',
        (WidgetTester tester) async {
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_down));
      await tester.pumpWidget(sut);

      verifier(tester, -1);
    });

    testWidgets('Verify thumb_up button state can toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_up));
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_up));
      await tester.pumpWidget(sut);

      verifier(tester, 0);
    });

    testWidgets('Verify thumb_down button state can toggle',
        (WidgetTester tester) async {
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_down));
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_down));
      await tester.pumpWidget(sut);

      verifier(tester, 0);
    });

    testWidgets('Verify button states do not conflict',
        (WidgetTester tester) async {
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_down));
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_up));
      await tester.pumpWidget(sut);

      verifier(tester, 1);

      await tester.tap(find.byIcon(Icons.thumb_down));
      await tester.pumpWidget(sut);

      verifier(tester, -1);
    });
  });
}
