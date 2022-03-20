import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/user.dart';
import 'package:myapp/models/feed.dart';
import 'package:myapp/widgets/feed_list/up_down_vote_buttons.dart';

void main() {
  Widget sut;
  var instance = FakeFirebaseFirestore();

  group('UpDownVoteButtons', () {
    setUp(() async {
      // Build our app and trigger a frame.
      sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Provider(
            create: (_) => SnippetBoxUser(uid: 'dummy_uid'),
            child: Scaffold(
              body: UpDownVoteButtons(
                initialVotedUri: VotedUri(
                    uri: 'dummy_uri',
                    title: 'dummy_title',
                    state: 0,
                    uriCreatedAt: DateTime.now()),
                firestoreInstance: instance,
              ),
            ),
          ),
        ),
      );
    });

    tearDown(() async {
      instance = FakeFirebaseFirestore();
    });

    final verifier = (WidgetTester tester, int state) {
      final upDownVoteButtons =
          tester.state<UpDownVoteButtonsState>(find.byType(UpDownVoteButtons));
      expect(upDownVoteButtons.votedUri.state, equals(state));
      if (state == 0) {
        expect(upDownVoteButtons.votedUri.docId, isNull);
      } else {
        expect(upDownVoteButtons.votedUri.docId, isNotNull);
      }

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

      await instance
          .collection('user_data')
          .doc('dummy_uid')
          .collection('votes')
          .get()
          .then((snapshot) => expect(snapshot.docs.length, 0));
    });

    testWidgets('Verify thumb_up button is selected and its color is changed',
        (WidgetTester tester) async {
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_up));
      await tester.pumpWidget(sut);

      verifier(tester, 1);
      await instance
          .collection('user_data')
          .doc('dummy_uid')
          .collection('votes')
          .get()
          .then((snapshot) {
        expect(snapshot.docs.length, 1);
      });
    });

    testWidgets('Verify thumb_down button is selected and its color is changed',
        (WidgetTester tester) async {
      await tester.pumpWidget(sut);
      await tester.tap(find.byIcon(Icons.thumb_down));
      await tester.pumpWidget(sut);

      verifier(tester, -1);
      await instance
          .collection('user_data')
          .doc('dummy_uid')
          .collection('votes')
          .get()
          .then((snapshot) => expect(snapshot.docs.length, 1));
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
