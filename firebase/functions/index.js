// The Cloud Functions for Firebase SDK to create Cloud Functions and setup triggers.
const firebase = require("firebase");
// Required for side-effects
require("firebase/firestore");


// The Firebase Admin SDK to access Cloud Firestore.
const admin = require('firebase-admin');
const functions = require('firebase-functions');
admin.initializeApp(functions.config().firebase)

const busboy = require('busboy')
const fetch = require('node-fetch');
const { JSDOM } = require('jsdom');

var fireStore = admin.firestore()

const algoliasearch = require('algoliasearch');

const ALGOLIA_ID = functions.config().algolia.app_id;
const ALGOLIA_ADMIN_KEY = functions.config().algolia.api_key;
const ALGOLIA_SEARCH_KEY = functions.config().algolia.search_key;

const ALGOLIA_INDEX_NAME = 'snippets';
const client = algoliasearch(ALGOLIA_ID, ALGOLIA_ADMIN_KEY);

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

exports.snippetsOnCreated = functions.firestore
  .document('user_data/{userId}/snippets/{docId}')
  .onCreate((snap, context) => {
    // Get the note document
    const snippet = snap.data();

    // Add an 'objectID' field which Algolia requires
    snippet.objectID = context.params.docId;

    // Write to the algolia index
    const index = client.initIndex(ALGOLIA_INDEX_NAME);
    return index.saveObject(snippet)
      .then(() => console.log('Add snippet to Algoria'))
      .catch(error => {
        console.error('Error to add snippet to Algoria', error);
        process.exit(1);
      });
});

exports.snippetsOnUpdate = functions.firestore
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

    // Add an 'objectID' field which Algolia requires
    newValue.objectID = context.params.docId;

    // Write to the algolia index
    const index = client.initIndex(ALGOLIA_INDEX_NAME);
    return index.saveObject(newValue)
      .then(() => console.log('Update snippet on Algoria'))
      .catch(error => {
        console.error('Error to update snippet to Algoria', error);
        process.exit(1);
      });
  })

exports.snippetsOnDelete = functions.firestore
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

    // Get Algolia's objectID from the Firebase object key
    const objectID = context.params.docId;

    // Remove the object from Algolia
    const index = client.initIndex(ALGOLIA_INDEX_NAME);
    index
      .deleteObject(objectID)
      .then(() => {
        console.log('Firebase object deleted from Algolia', objectID);
        return;
      })
      .catch(error => {
        console.error('Error when deleting contact from Algolia', error);
        process.exit(1);
      });
  })

function getHtmlTitle(url) {
  return new Promise((resolve, reject) => {
    fetch(url)
      .then(response => response.text())
      .then(data => {
        const dom = new JSDOM(data);
        return resolve(dom.window.document.title);
      })
      .catch(error => reject(error));
  });
}

exports.sendUrlToDb = functions.https.onCall((data, context) => {
  functions.logger.info("send URL to DB!", { structuredData: true });
  const userId = data.uid;
  const uri = data.uri;

  if (!context.auth) {
    throw new functions.https.HttpsError('permission-denied', 'Auth Error');
  }

  return getHtmlTitle(uri)
    .then(title => fireStore.collection('user_data/' + userId + '/snippets').doc().set({
      tags: ['__all__'],
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      uri: uri,
      title: title
  }, { merge: true }))
    .then(() => console.log('added uri'))
    .catch((error) => console.log('error adding uri:', error));
});

async function getFirebaseUser(req, res, next) {
  functions.logger.log('Check if request is authorized with Firebase ID token');

  if (!req.headers.authorization || !req.headers.authorization.startsWith('Bearer ')) {
    functions.logger.error(
      'No Firebase ID token was passed as a Bearer token in the Authorization header.',
      'Make sure you authorize your request by providing the following HTTP header:',
      'Authorization: Bearer <Firebase ID Token>'
    );
    return res.sendStatus(403);
  }

  let idToken;
  if (req.headers.authorization && req.headers.authorization.startsWith('Bearer ')) {
    functions.logger.log("Found 'Authorization' header");
    idToken = req.headers.authorization.split('Bearer ')[1];
  }

  try {
    const decodedIdToken = await admin.auth().verifyIdToken(idToken);
    functions.logger.log('ID Token correctly decoded', decodedIdToken);
    req.user = decodedIdToken;
    return next();
  } catch(error) {
    functions.logger.error('Error while verifying Firebase ID token:', error);
    return res.status(403).send('Unauthorized');
  }
}

// This complex HTTP function will be created as an ExpressJS app:
// https://expressjs.com/en/4x/api.html
const app = require('express')();

// We'll enable CORS support to allow the function to be invoked
// from our app client-side.
app.use(require('cors')({origin: true}));

// Then we'll also use a special 'getFirebaseUser' middleware which
// verifies the Authorization header and adds a `user` field to the
// incoming request:
// https://gist.github.com/abeisgoat/832d6f8665454d0cd99ef08c229afb42
app.use(getFirebaseUser);

// Add a route handler to the app to generate the secured key
app.get('/', (req, res) => {
  // @ts-ignore
  const uid = req.user.uid;

  // Create the params object as described in the Algolia documentation:
  // https://www.algolia.com/doc/guides/security/api-keys/#generating-api-keys
  const params = {
    // This filter ensures that only documents where author == uid will be readable
    // filters: `author:${uid}`,
    // We also proxy the uid as a unique token for this key.
    userToken: uid,
  };

  // Call the Algolia API to generate a unique key based on our search key
  const key = client.generateSecuredApiKey(ALGOLIA_SEARCH_KEY, params);

  // Then return this key as {key: '...key'}
  res.json({key});
});

// Finally, pass our ExpressJS app to Cloud Functions as a function
// called 'getSearchKey';
exports.getSearchKey = functions.https.onRequest(app);