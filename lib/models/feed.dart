import 'package:webfeed/webfeed.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

enum FeedTypes {
  ATOM,
  RSS,
  UNKNOWN,
}

class RssUriParser {
  HttpsCallable getRssContentFunction;
  final defaultGetRssContentFunction =
      FirebaseFunctions.instance.httpsCallable('getRssContent');

  RssUriParser({this.getRssContentFunction}) {
    // Avoid non-const default value error.
    this.getRssContentFunction ??= this.defaultGetRssContentFunction;
  }

  Future<String> getRssContent(String uri) {
    return this.getRssContentFunction(uri).then((res) {
      return res.data.toString();
    }).catchError((error) {
      throw error;
    });
  }
}

class RssUriStore {
  FirebaseFirestore firestoreInstance = FirebaseFirestore.instance;

  RssUriStore({this.firestoreInstance});

  saveToFirestore(String userId, String uri) {
    RssUriParser().getRssContent(uri).then((rssContent) {
      final feedType = getFeedType(rssContent);
      return this
          .firestoreInstance
          .collection('user_data')
          .doc(userId)
          .collection('feeds')
          .add({
        'type': feedType.toString(),
        'uri': uri,
        'timestamp': FieldValue.serverTimestamp(),
      });
    });
  }
}

FeedTypes getFeedType(String xmlString) {
  try {
    RssFeed.parse(xmlString);
    return FeedTypes.RSS;
  } catch (e) {
    print(e);
  }

  try {
    AtomFeed.parse(xmlString);
    return FeedTypes.ATOM;
  } catch (e) {
    print(e);
  }

  throw 'Given XML string is not ATOM nor XML';
}

class FeedItemAndTime<T> {
  final T item;

  DateTime dateTime;
  String title;
  String uri;

  FeedItemAndTime(this.item) {
    if (T == AtomItem) {
      final atomItem = this.item as AtomItem;
      this.dateTime = atomItem.updated;
      this.title = atomItem.title;
      this.uri = atomItem.links[0].href;
      if (atomItem.links.length != 1) {
        throw 'atomItem.links.length is not 1 but ${atomItem.links.length}';
      }
    } else if (T == RssItem) {
      final rssItem = this.item as RssItem;
      this.dateTime = rssItem.pubDate;
      this.title = rssItem.title;
      this.uri = rssItem.link;
    } else {
      throw 'Given item is neither Atom nor Rss feed';
    }
  }
}

abstract class FeedItems {
  FeedItems(String xmlString) {
    parse(xmlString);
  }

  parse(String xmlString);
  List<FeedItemAndTime> getItems();
}

class RssFeedItems extends FeedItems {
  RssFeed _rssFeeds;

  RssFeedItems(String xmlString) : super(xmlString);

  @override
  parse(String xmlString) {
    _rssFeeds = RssFeed.parse(xmlString);
  }

  @override
  List<FeedItemAndTime<RssItem>> getItems() {
    return _rssFeeds.items
        .map((RssItem rssItem) => FeedItemAndTime<RssItem>(rssItem))
        .toList();
  }
}

class AtomFeedItems extends FeedItems {
  AtomFeed _atomFeeds;

  AtomFeedItems(String xmlString) : super(xmlString);

  @override
  parse(String xmlString) {
    _atomFeeds = AtomFeed.parse(xmlString);
  }

  @override
  List<FeedItemAndTime<AtomItem>> getItems() {
    return _atomFeeds.items
        .map((AtomItem atomItem) => FeedItemAndTime<AtomItem>(atomItem))
        .toList();
  }
}

class VotedUri {
  // <0: negative, 0: not selected, >0: positive.
  final int state;
  final String uri;
  final String title;
  final DateTime uriCreatedAt;
  // expect null as we do not store a document when it is not voted for efficiency.
  final String docId;

  VotedUri({
    @required this.uri,
    @required this.title,
    @required this.state,
    @required this.uriCreatedAt,
    this.docId,
  });
}
