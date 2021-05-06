// The Cloud Functions for Firebase SDK to create Cloud Functions and setup triggers.
const firebase = require("firebase");
// Required for side-effects
require("firebase/firestore");

const functions = require('firebase-functions');
const busboy = require('busboy')

// The Firebase Admin SDK to access Cloud Firestore.
const admin = require('firebase-admin');
admin.initializeApp(functions.config().firebase)

var fireStore = admin.firestore()

function firebaseGetUserByEmail(email) {
  return admin.auth().getUserByEmail(email)
    .then((userRecord) => {
      // See the UserRecord reference doc for the contents of userRecord.
      console.log('Successfully fetched user data:', userRecord.toJSON());
      return userRecord.uid;
    })
    .catch((error) => {
      console.log('Error fetching user data:', error);
      throw error;
    });
}

function addMessageToFireStore(userId, req) {
  const busboy_parser = new busboy({ headers: req.headers })

  let docRef = fireStore.collection('user_data/' + userId + '/snippets').doc();
  docRef.set({
      tags: ['__all__'],
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true})
    .then(() => console.log('added tags'))
    .catch((error) => console.log('error tags:', error));

  busboy_parser.on("field", (field, val) => {
    console.log(`Processed field ${field}: ${val}.`);
    if (field === 'subject') {
      console.log('find subject')
      docRef.set({title: val}, {merge: true})
        .then(() => console.log('added subject'))
        .catch((error) => console.log('error subject:', error));
    } else if (field === 'html') {
      console.log('find html')
      docRef.set({html: val}, {merge: true})
        .then(() => console.log('added html'))
        .catch((error) => console.log('error html:', error));
    } else if (field === 'text') {
      console.log('find text')
      docRef.set({text: val}, {merge: true})
        .then(() => console.log('added text'))
        .catch((error) => console.log('error text:', error));
    }
  })

  busboy_parser.end(req.rawBody)
}

// Take the text parameter passed to this HTTP endpoint and insert it into
// Cloud Firestore under the path /messages/:documentId/original
exports.addMessage = functions.https.onRequest(async (req, res) => {
  try {
    console.log('Email recieved')

    const busboy_parser = new busboy({ headers: req.headers })

    busboy_parser.on("field", async (field, val) => {
      console.log(`Processed field ${field}: ${val}.`);
      if (field === 'envelope') {
        firebaseGetUserByEmail(JSON.parse(val).from)
            .then((userId) => {
              console.log('get uid', userId);
              addMessageToFireStore(userId, req);
              return;
            })
          .catch((error) => {
            console.log('Error adding message for user:', error);
            throw error;
          });
      }
    })

    busboy_parser.end(req.rawBody)
  } finally {
    res.send(200);
  }
});

exports.tagListOnUpdate = functions.firestore
  .document('user_data/{userId}/snippets/{docId}')
  .onUpdate((change, context) => {
    const newValue = change.after.data();
    const previousValue = change.before.data();

    const newTags = new Set(newValue['tags']);
    const previousTags = new Set(previousValue['tags']);

    const removedTags = new Set([...previousTags].filter(x => !newTags.has(x)));
    const addedTags = new Set([...newTags].filter(x => !previousTags.has(x)));

    console.log('removedTags: ', removedTags);
    console.log('addedTags: ', addedTags);

    const tagListRef = fireStore.collection('user_data/' + context.params.userId + '/tags');

    removedTags.forEach((tag) => {
      tagListRef.doc(tag).get()
        .then((tagDoc) => {
          if (tagDoc.exists) {
            console.log('doc exists when removing: ', tagDoc.data()['documents']);

            const tagDocuments = tagDoc.data()['documents'].filter(
              v => v !== context.params.docId);

            console.log('setting docs ', tagDocuments, 'from tag ', tag, 'after removal of ', context.params.docId);

            if (tagDocuments.length) {
              console.log('After removal, doc should still exist.');
              tagListRef.doc(tag).set({
                documents: tagDocuments,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
              });
            } else {
              console.log('No documents belong to this tag. remove tag document itself');
              tagListRef.doc(tag).delete();
            }
          }
          return;
        })
        .catch((error) => console.log('error tag update:', error));
      });

    addedTags.forEach((tag) => {
      tagListRef.doc(tag).get()
        .then((tagDoc) => {
          let tagDocuments = [];
          if (tagDoc.exists) {
            console.log('doc exists when adding: ', tagDoc.data()['documents']);
            tagDocuments = tagDocuments.concat(tagDoc.data()['documents']);
          }

          if (!tagDocuments.includes(context.params.docId)) {
            tagDocuments.push(context.params.docId);
          }

          console.log('setting docs ', tagDocuments, 'to tag ', tag, 'after addition of ', context.params.docId);

          return tagListRef.doc(tag).set({
            documents: tagDocuments,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        })
        .catch((error) => console.log('error tag update:', error));
      });
  })

exports.testListOnDelete = functions.firestore
  .document('user_data/{userId}/snippets/{docId}')
  .onDelete((snapshot, context) => {
    const tagListRef = fireStore.collection('user_data/' + context.params.userId + '/tags');

    const data = snapshot.data();
    data['tags']
      .filter((tag) => tag !== '__all__')
      .forEach((tag) => {
        tagListRef.doc(tag).get()
          .then((tagDoc) => {
            if (tagDoc.exists) {
              console.log('doc exists when removing: ', tagDoc.data()['documents']);

              const tagDocuments = tagDoc.data()['documents'].filter(
                v => v !== context.params.docId);

              console.log('setting docs ', tagDocuments, 'from tag ', tag, 'after removal of ', context.params.docId);

              if (tagDocuments.length) {
                console.log('After removal, doc should still exist.');
                tagListRef.doc(tag).set({
                  documents: tagDocuments,
                  timestamp: admin.firestore.FieldValue.serverTimestamp(),
                });
              } else {
                console.log('No documents belong to this tag. remove tag document itself');
                tagListRef.doc(tag).delete();
              }
            }
            return;
          })
          .catch((error) => console.log('error tag update:', error));
    });
  })

// TODO: Parse URL to get more information.
exports.sendUrlToDb = functions.https.onCall((data, context) => {
    functions.logger.info("send URL to DB!", { structuredData: true });
    const userId = data.uid;
    const uri = data.uri;

    return fireStore.collection('user_data/' + userId + '/snippets').doc().set({
        tags: ['__all__'],
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        uri: uri,
        title: uri
    }, { merge: true })
        .then(() => console.log('added uri'))
        .catch((error) => console.log('error adding uri:', error));

});
