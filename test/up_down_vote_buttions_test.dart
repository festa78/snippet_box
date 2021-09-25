import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/user.dart';
import 'package:myapp/widgets/up_down_vote_buttons.dart';
import 'package:myapp/widgets/feed.dart';

void main() {
  Widget sut;

  group('UpDownVoteButtons', () {
    setUpAll(() async {
      // Build our app and trigger a frame.
      sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Provider(
            create: (_) => MyUser(uid: 'dummy_uid'),
            child: Scaffold(
              body: UpDownVoteButtons(
                initialVotedUri: VotedUri(
                    uri: 'dummy_uri', state: 0, uriCreatedAt: DateTime.now()),
                firestoreInstance: FakeFirebaseFirestore(),
              ),
            ),
          ),
        ),
      );
    });

    final verifier = (WidgetTester tester, int state) {
      final upDownVoteButtons =
          tester.state<UpDownVoteButtonsState>(find.byType(UpDownVoteButtons));
      expect(upDownVoteButtons.votedUri.state, equals(state));
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
