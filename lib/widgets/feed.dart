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

HttpsCallable getRssContent =
    FirebaseFunctions.instance.httpsCallable('getRssContent');

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
  final DateTime dateTime;
  final T item;

  FeedItemAndTime(this.dateTime, this.item);
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
        .map((RssItem rssItem) =>
            FeedItemAndTime<RssItem>(rssItem.pubDate, rssItem))
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
        .map((AtomItem atomItem) =>
            FeedItemAndTime<AtomItem>(atomItem.updated, atomItem))
        .toList();
  }
}

_saveUrlToFirestore(BuildContext context) {
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
                final FeedTypes feedType = getFeedType(res.data);
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

  FeedListPage({@required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(this.title),
      ),
      body: FeedList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _saveUrlToFirestore(context);
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
              List<Future<List<FeedItemAndTime>>> feedItemFutureList = [];
              snapshot.data.docs.map((DocumentSnapshot document) {
                return getRssContent(document['uri']).then((res) {
                  final xmlData = res.data.toString();
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
                        List feedItemAndTimes =
                            snapshot.data.expand((x) => x).toList();
                        feedItemAndTimes
                            .sort((a, b) => b.dateTime.compareTo(a.dateTime));
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: feedItemAndTimes.length,
                          itemBuilder: (context, index) {
                            return ListTile(
                              contentPadding: EdgeInsets.all(10.0),
                              title: Text(
                                feedItemAndTimes[index].item.title,
                              ),
                              subtitle: Text(
                                  feedItemAndTimes[index].dateTime.toString()),
                            );
                          },
                        );
                    }
                  });
          }
        });
  }
}

class ItemDetailPage extends StatefulWidget {
  final AtomItem item;

  ItemDetailPage({@required this.item});

  @override
  _ItemDetailPageState createState() => _ItemDetailPageState(item: item);
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  AtomItem item;

  _ItemDetailPageState({@required this.item});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(item.title),
      ),
      body: Center(child: Text(item.title)),
    );
  }
}
