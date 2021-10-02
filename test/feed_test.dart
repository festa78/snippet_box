import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';
import 'package:webfeed/webfeed.dart';
import 'package:xml/xml.dart';

import 'package:myapp/models/user.dart';
import 'package:myapp/models/feed.dart';
import 'package:myapp/widgets/feed.dart';
import 'package:myapp/widgets/up_down_vote_buttons.dart';

class FakeRssUrlParser extends Fake implements RssUrlParser {
  List<String> returnValues;
  int index = 0;

  FakeRssUrlParser({@required this.returnValues});

  @override
  Future<String> parse(String uri) {
    final returnValue = this.returnValues[this.index];
    this.index += 1;
    return Future.value(returnValue);
  }
}

void main() {
  group('FeedListTile', () {
    testWidgets('atom feed', (WidgetTester tester) async {
      final String atomXml = '''<?xml version="1.0"?>
      <entry>
        <id>dummy_id</id>
        <title>dummy_title</title>
        <updated>2021-08-06T02:41:16.782Z</updated>
        <link href="https://example.com/" />
      </entry>''';

      final xmlDocument = XmlDocument.parse(atomXml);
      final atomItem = AtomItem.parse(xmlDocument.getElement('entry'));
      final feedItemAndTime = FeedItemAndTime(atomItem);
      final votedUri =
          VotedUri(uri: 'dummy_uri', state: 0, uriCreatedAt: DateTime.now());

      // Build our app and trigger a frame.
      final sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Scaffold(
            body: FeedListTile(
              feedItemAndTime: feedItemAndTime,
              initialVotedUri: votedUri,
              firestoreInstance: FakeFirebaseFirestore(),
            ),
          ),
        ),
      );
      await tester.pumpWidget(sut);

      // Verify it shows feed title properly.
      expect(find.text('dummy_title'), findsOneWidget);

      // Tap the feed and show up the url.
      await tester.tap(find.text('dummy_title'));
      await tester.pumpAndSettle();

      // Verify that it switches to EasyWebView.
      expect(find.byKey(Key('dummy_title')), findsNWidgets(2));
    });

    testWidgets('rss feed', (WidgetTester tester) async {
      final String rssXml = '''<?xml version="1.0"?>
      <item>
        <title>dummy_title</title>
        <pubDate>2021-08-06T02:41:16.782Z</pubDate>
        <link>"https://example.com/"</link>
      </item>''';

      final xmlDocument = XmlDocument.parse(rssXml);
      final rssItem = RssItem.parse(xmlDocument.getElement('item'));
      final feedItemAndTime = FeedItemAndTime(rssItem);
      final votedUri =
          VotedUri(uri: 'dummy_uri', state: 0, uriCreatedAt: DateTime.now());

      // Build our app and trigger a frame.
      final sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Scaffold(
            body: FeedListTile(
                feedItemAndTime: feedItemAndTime, initialVotedUri: votedUri),
          ),
        ),
      );
      await tester.pumpWidget(sut);

      // Verify it shows feed title properly.
      expect(find.text('dummy_title'), findsOneWidget);

      // Tap the feed and show up the url.
      await tester.tap(find.text('dummy_title'));
      await tester.pumpAndSettle();

      // Verify that it switches to EasyWebView.
      expect(find.byKey(Key('dummy_title')), findsNWidgets(2));
    });

    testWidgets('feed with votes', (WidgetTester tester) async {
      final String rssXml = '''<?xml version="1.0"?>
      <item>
        <title>dummy_title</title>
        <pubDate>2021-08-06T02:41:16.782Z</pubDate>
        <link>"https://example.com/"</link>
      </item>''';

      final xmlDocument = XmlDocument.parse(rssXml);
      final rssItem = RssItem.parse(xmlDocument.getElement('item'));
      final feedItemAndTime = FeedItemAndTime(rssItem);
      final votedUri =
          VotedUri(uri: 'dummy_uri', state: 1, uriCreatedAt: DateTime.now());

      // Build our app and trigger a frame.
      final sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Scaffold(
            body: FeedListTile(
                feedItemAndTime: feedItemAndTime, initialVotedUri: votedUri),
          ),
        ),
      );
      await tester.pumpWidget(sut);

      // Verify it shows feed with thumb_up vote.
      expect(find.byIcon(Icons.thumb_down), findsOneWidget);
      final upDownVoteButtons =
          tester.state<UpDownVoteButtonsState>(find.byType(UpDownVoteButtons));
      expect(upDownVoteButtons.votedUri.state, equals(1));
    });
  });

  group('SortedFeedListWithVote', () {
    testWidgets('Detect vote data with uri and timestamp exact match',
        (WidgetTester tester) async {
      final dateTime = DateTime.now();
      final instance = FakeFirebaseFirestore();
      await instance
          .collection('user_data')
          .doc('dummy_uid')
          .collection('votes')
          .add({
        'uri': 'https://example.com/',
        'state': 1,
        'uriCreatedAt': Timestamp.fromDate(dateTime),
      });

      final String atomXml = '''<?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <entry>
          <id>dummy_id</id>
          <title>dummy_title</title>
          <updated>${dateTime.toIso8601String()}</updated>
          <link href="https://example.com/" />
        </entry>
      </feed>''';

      final sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Provider(
            create: (_) => SnippetBoxUser(uid: 'dummy_uid'),
            child: Scaffold(
              body: SortedFeedListWithVote(
                feedItemAndTimes: AtomFeedItems(atomXml).getItems(),
                firestoreInstance: instance,
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(sut);

      // Wait enough so that it shows the actual feed content.
      await tester.pumpAndSettle();

      // Verify it shows feed with thumb_up vote.
      expect(find.byIcon(Icons.thumb_down), findsOneWidget);
      final upDownVoteButtons =
          tester.state<UpDownVoteButtonsState>(find.byType(UpDownVoteButtons));
      expect(upDownVoteButtons.votedUri.state, equals(1));
    });
  });

  group('SortedFeedList', () {
    testWidgets('check sorted', (WidgetTester tester) async {
      final String atomXml = '''<?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <entry>
          <id>dummy_id</id>
          <title>dummy_title</title>
          <updated>2021-08-06T02:41:16.782Z</updated>
          <link href="https://example.com/" />
        </entry>
      </feed>''';

      final sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Provider(
            create: (_) => SnippetBoxUser(uid: 'dummy_uid'),
            child: Scaffold(
              body: SortedFeedList(
                xmlDataList: [Future<String>.value(atomXml)],
                firestoreInstance: FakeFirebaseFirestore(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(sut);

      // Verify it shows "Loading" at first while loading.
      expect(find.text('Sorting contents'), findsOneWidget);

      // Wait enough so that it shows the actual feed content.
      await tester.pumpAndSettle();

      // Verify it shows feed title properly.
      expect(find.text('dummy_title'), findsOneWidget);
    });
  });

  group('FeedList', () {
    testWidgets('check feedlist', (WidgetTester tester) async {
      final instance = FakeFirebaseFirestore();
      await instance
          .collection('user_data')
          .doc('dummy_uid')
          .collection('feeds')
          .add({'uri': 'dummy_url1'});
      await instance
          .collection('user_data')
          .doc('dummy_uid')
          .collection('feeds')
          .add({'uri': 'dummy_url2'});

      final String atomXml1 = '''<?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <entry>
          <id>dummy_id</id>
          <title>dummy_title1</title>
          <updated>2021-08-06T02:41:16.782Z</updated>
          <link href="https://example.com/" />
        </entry>
      </feed>''';

      final String atomXml2 = '''<?xml version="1.0"?>
      <feed xmlns="http://www.w3.org/2005/Atom">
        <entry>
          <id>dummy_id_2</id>
          <title>dummy_title2</title>
          <updated>2021-08-07T02:41:16.782Z</updated>
          <link href="https://example.com/" />
        </entry>
      </feed>''';

      final sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Provider(
            create: (_) => SnippetBoxUser(uid: 'dummy_uid'),
            child: Scaffold(
              body: FeedList(
                firestoreInstance: instance,
                rssUrlParser:
                    FakeRssUrlParser(returnValues: [atomXml1, atomXml2]),
              ),
            ),
          ),
        ),
      );
      await tester.pumpWidget(sut);

      // Verify it shows "Loading" at first while loading.
      expect(find.text('Loading contents'), findsOneWidget);

      // Wait enough so that it shows the actual feed content.
      await tester.pumpAndSettle();

      // Verify it shows feed title properly.
      expect(find.text('dummy_title1'), findsOneWidget);
      expect(find.text('dummy_title2'), findsOneWidget);
    });
  });
}
