import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_web_view/easy_web_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/feed.dart';
import 'package:myapp/models/user.dart';
import 'package:myapp/widgets/feed_list/up_down_vote_buttons.dart';

class FeedListPage extends StatelessWidget {
  final String title = 'News feed page';
  final RssUriStore rssUriStore;

  FeedListPage({@required this.rssUriStore});

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
                  await this.rssUriStore.saveToFirestore(
                      Provider.of<SnippetBoxUser>(context, listen: false).uid,
                      contentController.text);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(this.title),
      ),
      body: FeedList(
        firestoreInstance: FirebaseFirestore.instance,
        rssUrlParser: RssUriParser(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          this._saveUrlToFirestore(context);
        },
        child: Icon(Icons.add),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

class FeedList extends StatelessWidget {
  final FirebaseFirestore firestoreInstance;
  final RssUriParser rssUrlParser;

  FeedList({@required this.firestoreInstance, this.rssUrlParser});

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<SnippetBoxUser>(context);

    return StreamBuilder<QuerySnapshot>(
        stream: this
            .firestoreInstance
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
              return new Text('Loading contents');
            default:
              return SortedFeedList(
                xmlDataList:
                    snapshot.data.docs.map((DocumentSnapshot document) {
                  return this.rssUrlParser.getRssContent(document['uri']);
                }).toList(),
                firestoreInstance: this.firestoreInstance,
              );
          }
        });
  }
}

class SortedFeedList extends StatelessWidget {
  final List<Future<String>> xmlDataList;
  final FirebaseFirestore firestoreInstance;

  SortedFeedList(
      {@required this.xmlDataList, @required this.firestoreInstance});

  @override
  Widget build(BuildContext context) {
    List<Future<List<FeedItemAndTime>>> feedItemFutureList = [];
    this.xmlDataList.map((Future<String> xmlDataFuture) {
      return xmlDataFuture.then((xmlData) {
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
              return Text('Sorting contents');
            default:
              List<FeedItemAndTime> feedItemAndTimes =
                  snapshot.data.expand((x) => x).toList();
              feedItemAndTimes.sort((a, b) => b.dateTime.compareTo(a.dateTime));
              return SortedFeedListWithVote(
                  feedItemAndTimes: feedItemAndTimes,
                  firestoreInstance: this.firestoreInstance);
          }
        });
  }
}

class SortedFeedListWithVote extends StatelessWidget {
  final List<FeedItemAndTime> feedItemAndTimes;
  final FirebaseFirestore firestoreInstance;

  SortedFeedListWithVote(
      {@required this.feedItemAndTimes, @required this.firestoreInstance});

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<SnippetBoxUser>(context);
    final startDate =
        this.feedItemAndTimes[this.feedItemAndTimes.length - 1].dateTime;

    return FutureBuilder<QuerySnapshot>(
        future: this
            .firestoreInstance
            .collection('user_data')
            .doc(userData.uid)
            .collection('votes')
            .where('uriCreatedAt', isGreaterThanOrEqualTo: startDate)
            .get(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            print(snapshot.error);
            return new Text('Error: ${snapshot.error}');
          }
          switch (snapshot.connectionState) {
            case ConnectionState.waiting:
              return Text('Retrieving votes');
            default:
              List<VotedUri> votedUris =
                  snapshot.data.docs.map((DocumentSnapshot document) {
                return VotedUri(
                    uri: document['uri'],
                    state: document['state'],
                    uriCreatedAt: document['uriCreatedAt'].toDate(),
                    docId: document.id);
              }).toList();

              return ListView.builder(
                shrinkWrap: true,
                itemCount: this.feedItemAndTimes.length,
                itemBuilder: (context, index) {
                  bool comparator(element) =>
                      element.uri == this.feedItemAndTimes[index].uri &&
                      element.uriCreatedAt ==
                          this.feedItemAndTimes[index].dateTime;

                  final votedUriIndex = votedUris.indexWhere(comparator);

                  // Make sure no duplication.
                  assert(votedUris.indexWhere(comparator, votedUriIndex + 1) ==
                      -1);

                  if (votedUriIndex == -1) {
                    return FeedListTile(
                      feedItemAndTime: this.feedItemAndTimes[index],
                      initialVotedUri: VotedUri(
                          uri: this.feedItemAndTimes[index].uri,
                          state: 0,
                          uriCreatedAt: this.feedItemAndTimes[index].dateTime),
                      firestoreInstance: this.firestoreInstance,
                    );
                  }
                  return FeedListTile(
                    feedItemAndTime: this.feedItemAndTimes[index],
                    initialVotedUri: votedUris[votedUriIndex],
                    firestoreInstance: this.firestoreInstance,
                  );
                },
              );
          }
        });
  }
}

class FeedListTile extends StatelessWidget {
  final FeedItemAndTime feedItemAndTime;
  final VotedUri initialVotedUri;
  final FirebaseFirestore firestoreInstance;

  FeedListTile(
      {@required this.feedItemAndTime,
      @required this.initialVotedUri,
      @required this.firestoreInstance});

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
        trailing: Container(
          width: 200,
          child: UpDownVoteButtons(
              firestoreInstance: this.firestoreInstance,
              initialVotedUri: this.initialVotedUri),
        ),
      ),
    );
  }
}
