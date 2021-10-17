import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:myapp/models/user.dart';
import 'package:myapp/models/feed.dart';

class UpDownVoteButtons extends StatefulWidget {
  final FirebaseFirestore firestoreInstance;
  final VotedUri initialVotedUri;

  UpDownVoteButtons({@required this.firestoreInstance, this.initialVotedUri});

  @override
  UpDownVoteButtonsState createState() =>
      UpDownVoteButtonsState(votedUri: this.initialVotedUri);
}

class UpDownVoteButtonsState extends State<UpDownVoteButtons> {
  VotedUri votedUri;

  UpDownVoteButtonsState({this.votedUri});

  @override
  Widget build(BuildContext context) {
    return ButtonBar(
      children: [
        IconButton(
          icon: Icon(Icons.thumb_up),
          color: this.votedUri.state > 0 ? Colors.blueAccent : Colors.grey,
          onPressed: () {
            final userData =
                Provider.of<SnippetBoxUser>(context, listen: false);

            final collectionRef = this
                .widget
                .firestoreInstance
                .collection('user_data')
                .doc(userData.uid)
                .collection('votes');

            switch (votedUri.state) {
              case 1:
                collectionRef.doc(this.votedUri.docId).delete().then((value) {
                  setState(() {
                    this.votedUri = VotedUri(
                        docId: null,
                        state: 0,
                        uri: this.votedUri.uri,
                        title: this.votedUri.title,
                        uriCreatedAt: this.votedUri.uriCreatedAt);
                  });
                }).catchError((error) =>
                    print('Failed to delete docId on unvote: $error'));
                break;
              case 0:
                assert(this.votedUri.docId == null);
                collectionRef.add({
                  'state': 1,
                  'uri': this.votedUri.uri,
                  'title': this.votedUri.title,
                  'uriCreatedAt': this.votedUri.uriCreatedAt,
                }).then((DocumentReference docRef) {
                  setState(() {
                    this.votedUri = VotedUri(
                        docId: docRef.id,
                        state: 1,
                        uri: this.votedUri.uri,
                        title: this.votedUri.title,
                        uriCreatedAt: this.votedUri.uriCreatedAt);
                  });
                });
                break;
              case -1:
                collectionRef
                    .doc(this.votedUri.docId)
                    .update({'state': 1}).then((value) {
                  setState(() {
                    this.votedUri = VotedUri(
                        docId: this.votedUri.docId,
                        uri: this.votedUri.uri,
                        title: this.votedUri.title,
                        state: 1,
                        uriCreatedAt: this.votedUri.uriCreatedAt);
                  });
                }).catchError((error) =>
                        print('Failed to update docId on upvote: $error'));
                break;
              default:
                throw "Unknown state ${votedUri.state}";
            }
          },
        ),
        IconButton(
          icon: Icon(Icons.thumb_down),
          color: this.votedUri.state < 0 ? Colors.blueAccent : Colors.grey,
          onPressed: () {
            final userData =
                Provider.of<SnippetBoxUser>(context, listen: false);

            final collectionRef = this
                .widget
                .firestoreInstance
                .collection('user_data')
                .doc(userData.uid)
                .collection('votes');

            switch (votedUri.state) {
              case 1:
                collectionRef
                    .doc(this.votedUri.docId)
                    .update({'state': -1}).then((value) {
                  setState(() {
                    this.votedUri = VotedUri(
                        docId: this.votedUri.docId,
                        uri: this.votedUri.uri,
                        title: this.votedUri.title,
                        state: -1,
                        uriCreatedAt: this.votedUri.uriCreatedAt);
                  });
                }).catchError((error) =>
                        print('Failed to update docId on downvote: $error'));
                break;
              case 0:
                assert(this.votedUri.docId == null);
                collectionRef.add({
                  'state': -1,
                  'uri': this.votedUri.uri,
                  'title': this.votedUri.title,
                  'uriCreatedAt': this.votedUri.uriCreatedAt,
                }).then((DocumentReference docRef) {
                  setState(() {
                    this.votedUri = VotedUri(
                        docId: docRef.id,
                        state: -1,
                        uri: this.votedUri.uri,
                        title: this.votedUri.title,
                        uriCreatedAt: this.votedUri.uriCreatedAt);
                  });
                });
                break;
              case -1:
                collectionRef.doc(this.votedUri.docId).delete().then((value) {
                  setState(() {
                    this.votedUri = VotedUri(
                        docId: null,
                        state: 0,
                        uri: this.votedUri.uri,
                        title: this.votedUri.title,
                        uriCreatedAt: this.votedUri.uriCreatedAt);
                  });
                }).catchError((error) =>
                    print('Failed to delete docId on unvote: $error'));
                break;
              default:
                throw "Unknown state ${votedUri.state}";
            }
          },
        ),
      ],
    );
  }
}
