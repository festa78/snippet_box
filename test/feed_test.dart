// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility that Flutter provides. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webfeed/webfeed.dart';
import 'package:xml/xml.dart';

import 'package:myapp/widgets/feed.dart';

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

      // Build our app and trigger a frame.
      final sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Scaffold(
            body: FeedListTile(feedItemAndTime: feedItemAndTime),
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

      // Build our app and trigger a frame.
      final sut = MediaQuery(
        data: MediaQueryData(),
        child: MaterialApp(
          home: Scaffold(
            body: FeedListTile(feedItemAndTime: feedItemAndTime),
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
  });

  group('SortedFeedList', () {
    testWidgets('check sorted', (WidgetTester tester) async {
      final instance = FakeFirebaseFirestore();
      await instance.collection('dummy').add({'uri': 'dummy_url'});
      final snapshot = await instance.collection('dummy').get();

      final String rssXml = '''<?xml version="1.0"?>
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
          home: Scaffold(
            body: SortedFeedList(
              querySnapshot: snapshot,
              getRssContent: (String uri) {
                return Future<String>.value(rssXml);
              },
            ),
          ),
        ),
      );
      await tester.pumpWidget(sut);

      // Verify it shows "Loading" at first while loading.
      expect(find.text('Loading'), findsOneWidget);

      // Wait enough so that it shows the actual feed content.
      await tester.pumpAndSettle();

      // Verify it shows feed title properly.
      expect(find.text('dummy_title'), findsOneWidget);
    });
  });
}
