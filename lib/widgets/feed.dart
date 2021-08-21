import 'package:easy_web_view/easy_web_view.dart';
import 'package:flutter/material.dart';
import 'package:webfeed/webfeed.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'package:myapp/models/user.dart';

enum FeedTypes {
  ATOM,
  RSS,
  UNKNOWN,
}

// HttpsCallable getRssContent =
//     FirebaseFunctions.instance.httpsCallable('getRssContent');

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

_saveUrlToFirestore(
    BuildContext context, Future<String> Function(String) getRssContent) {
  final contentController = TextEditingController();

  return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Provide URL'),
          content: TextField(
            controller: contentController,
            decoration: InputDecoration(hintText: "URL path"),
          ),
          actions: <Widget>[
            new TextButton(
              child: new Text('Add'),
              onPressed: () async {
                print('Add new feed ${contentController.text}');
                final userData = Provider.of<MyUser>(context, listen: false);
                final res = await getRssContent(contentController.text);
                final FeedTypes feedType = getFeedType(res);
                await FirebaseFirestore.instance
                    .collection('user_data')
                    .doc(userData.uid)
                    .collection('feeds')
                    .add({
                  'type': feedType.toString(),
                  'uri': contentController.text,
                  'timestamp': FieldValue.serverTimestamp(),
                });
                Navigator.of(context).pop();
              },
            ),
            new TextButton(
              child: new Text('CANCEL'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      });
}

class FeedListPage extends StatelessWidget {
  final String title;
  final Future<String> Function(String) getRssContent;

  FeedListPage({@required this.title, @required this.getRssContent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(this.title),
      ),
      body: FeedList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _saveUrlToFirestore(context, this.getRssContent);
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

class FeedList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<MyUser>(context);

    return StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_data')
            .doc(userData.uid)
            .collection('feeds')
            .snapshots(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
            return new Text('Error: ${snapshot.error}');
          }
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return new Text('Loading...');
            default:
              return SortedFeedList(
                querySnapshot: snapshot.data,
                getRssContent: (String uri) {
                  return FirebaseFunctions.instance
                      .httpsCallable('getRssContent')(uri)
                      .then((res) {
                    return res.data.toString();
                  });
                },
              );
          }
        });
  }
}

class SortedFeedList extends StatelessWidget {
  final QuerySnapshot querySnapshot;
  final Future<String> Function(String) getRssContent;

  SortedFeedList({@required this.querySnapshot, @required this.getRssContent});

  @override
  Widget build(BuildContext context) {
    List<Future<List<FeedItemAndTime>>> feedItemFutureList = [];
    this.querySnapshot.docs.map((DocumentSnapshot document) {
      return this.getRssContent(document['uri']).then((xmlData) {
        FeedTypes feedType = getFeedType(xmlData);
        switch (feedType) {
          case FeedTypes.RSS:
            return RssFeedItems(xmlData).getItems();
            break;
          case FeedTypes.ATOM:
            return AtomFeedItems(xmlData).getItems();
            break;
          default:
            throw 'Unsupported feed type $feedType';
        }
      });
    }).forEach((Future<List<FeedItemAndTime>> futureListItem) {
      feedItemFutureList.add(futureListItem);
    });

    Future<List<List<FeedItemAndTime>>> feedItemListFuture =
        Future.wait(feedItemFutureList);
    return FutureBuilder<List<List<FeedItemAndTime>>>(
        future: feedItemListFuture,
        builder: (BuildContext context,
            AsyncSnapshot<List<List<FeedItemAndTime>>> snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
            return new Text('Error: ${snapshot.error}');
          }
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Text('Loading');
            default:
              List feedItemAndTimes = snapshot.data.expand((x) => x).toList();
              feedItemAndTimes.sort((a, b) => b.dateTime.compareTo(a.dateTime));
              return ListView.builder(
                shrinkWrap: true,
                itemCount: feedItemAndTimes.length,
                itemBuilder: (context, index) {
                  return FeedListTile(feedItemAndTime: feedItemAndTimes[index]);
                },
              );
          }
        });
  }
}

class FeedListTile extends StatelessWidget {
  final FeedItemAndTime feedItemAndTime;

  FeedListTile({@required this.feedItemAndTime});

  _navigate(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) {
        return Scaffold(
          appBar: AppBar(title: Text(this.feedItemAndTime.title)),
          body: EasyWebView(
            key: Key(this.feedItemAndTime.title),
            src: this.feedItemAndTime.uri,
            onLoaded: () => print('loaded uri ${this.feedItemAndTime.uri}'),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigate(context),
      child: ListTile(
        contentPadding: EdgeInsets.all(10.0),
        title: Text(
          this.feedItemAndTime.title,
        ),
        subtitle: Text(this.feedItemAndTime.dateTime.toString()),
      ),
    );
  }
}
