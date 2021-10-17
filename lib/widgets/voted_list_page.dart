import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_web_view/easy_web_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/feed.dart';
import 'package:myapp/models/user.dart';
import 'package:myapp/widgets/feed_list/up_down_vote_buttons.dart';

class VotedListPage extends StatelessWidget {
  final String title = 'Voted feed page';

  VotedListPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(this.title),
      ),
      body: VotedList(
        firestoreInstance: FirebaseFirestore.instance,
      ),
    );
  }
}

class VotedList extends StatelessWidget {
  final FirebaseFirestore firestoreInstance;

  VotedList({@required this.firestoreInstance});

  _navigate(BuildContext context, VotedUri votedUri) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) {
        return Scaffold(
          appBar: AppBar(title: Text(votedUri.uri)),
          body: EasyWebView(
            key: Key(votedUri.uri),
            src: votedUri.uri,
            onLoaded: () => print('loaded uri ${votedUri.uri}'),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userData = Provider.of<SnippetBoxUser>(context);

    return StreamBuilder<QuerySnapshot>(
        stream: this
            .firestoreInstance
            .collection('user_data')
            .doc(userData.uid)
            .collection('votes')
            .orderBy('uriCreatedAt')
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
              List<VotedUri> votedUris =
                  snapshot.data.docs.map((DocumentSnapshot document) {
                return VotedUri(
                    uri: document['uri'],
                    title: document['title'],
                    state: document['state'],
                    uriCreatedAt: document['uriCreatedAt'].toDate(),
                    docId: document.id);
              }).toList();

              return ListView.builder(
                  shrinkWrap: true,
                  itemCount: votedUris.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _navigate(context, votedUris[index]),
                      child: ListTile(
                        contentPadding: EdgeInsets.all(10.0),
                        title: Text(votedUris[index].uri),
                        subtitle:
                            Text(votedUris[index].uriCreatedAt.toString()),
                        trailing: Container(
                          width: 200,
                          child: UpDownVoteButtons(
                              firestoreInstance: this.firestoreInstance,
                              initialVotedUri: votedUris[index]),
                        ),
                      ),
                    );
                  });
          }
        });
  }
}
