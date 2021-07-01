// The Cloud Functions for Firebase SDK to create Cloud Functions and setup triggers.
const firebase = require("firebase");
// Required for side-effects
require("firebase/firestore");

// The Firebase Admin SDK to access Cloud Firestore.
const admin = require('firebase-admin');
const functions = require('firebase-functions');
admin.initializeApp({credential: admin.credential.applicationDefault()})

const busboy = require('busboy')
const fetch = require('node-fetch');
const { JSDOM } = require('jsdom');

var fireStore = admin.firestore()

const algoliasearch = require('algoliasearch');

exports.getAlgoliaIndex = () => {
  console.log('called real');
  const ALGOLIA_ID = functions.config().algolia.app_id;
  const ALGOLIA_ADMIN_KEY = functions.config().algolia.api_key;
  const ALGOLIA_SEARCH_KEY = functions.config().algolia.search_key;
  ALGOLIA_INDEX_NAME = functions.config().algolia.index_name;
  const client = algoliasearch(ALGOLIA_ID, ALGOLIA_ADMIN_KEY);
  return client.initIndex(ALGOLIA_INDEX_NAME);
}

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

// Take the text parameter passed to this HTTP endpoint and insert it into
// Cloud Firestore under the path /messages/:documentId/original
exports.addMessage = functions.https.onRequest(async (req, res) => {
  try {
    await new Promise((resolve, reject) => {
      console.log('Email recieved')

      let email_data = {};

      const busboy_parser = new busboy({ headers: req.headers })

      busboy_parser.on("field", (field, val) => {
        console.log(`Processed field ${field}: ${val}.`);
        if (field === 'envelope') {
          console.log('find envelope')
          email_data['email'] = JSON.parse(val).from;
        } else if (field === 'subject') {
          console.log('find subject')
          email_data['title'] = val;
        } else if (field === 'html') {
          console.log('find html')
          email_data[field] = val;
        } else if (field === 'text') {
          console.log('find text')
          email_data[field] = val;
        }
      })

      busboy_parser.on("error", () => {
        console.log('busboy error');
        reject(new Error('busboy error'));
      });

      busboy_parser.on("finish", () => {
        email_data['tags'] = ['__all__'];
        email_data['timestamp'] = admin.firestore.FieldValue.serverTimestamp();
        console.log('busboy finished', email_data);

        firebaseGetUserByEmail(email_data['email'])
          .then((userId) => {
            console.log('get uid', userId);
            return fireStore.collection('user_data/' + userId + '/snippets')
              .doc()
              .set(email_data);
          })
          .then(() => {
            console.log('added tags');
            resolve();
            return;
          })
          .catch((error) => {
            console.log('error tags:', error);
            reject(error);
          });
        });

      busboy_parser.end(req.rawBody);
    });
  } catch (error) {
    console.log(error);
    res.send(400);
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
    const index = exports.getAlgoliaIndex();
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

    const removedTags = [...previousTags].filter(x => !newTags.has(x));
    const addedTags = [...newTags].filter(x => !previousTags.has(x));

    console.log('removedTags: ', removedTags);
    console.log('addedTags: ', addedTags);

    const tagListRef = fireStore.collection('user_data/' + context.params.userId + '/tags');

    const removedTagsPromise = removedTags.map((tag) => {
      return tagListRef.doc(tag).get()
        .then((tagDoc) => {
          if (tagDoc.exists) {
            console.log('doc exists when removing: ', tagDoc.data()['documents']);

            const tagDocuments = tagDoc.data()['documents'].filter(
              v => v !== context.params.docId);

            console.log('setting docs ', tagDocuments, 'from tag ', tag, 'after removal of ', context.params.docId);

            if (tagDocuments.length) {
              console.log('After removal, doc should still exist.');
              return tagListRef.doc(tag).set({
                documents: tagDocuments,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
              });
            } else {
              console.log('No documents belong to this tag. remove tag document itself');
              return tagListRef.doc(tag).delete();
            }
          }
          // eslint-disable-next-line consistent-return
          return;
        })
        .then(() => console.log('removed tag', tag))
        .catch((error) => console.log('error tag remove:', error));
      });

    const addedTagsPromise = addedTags.map((tag) => {
      return tagListRef.doc(tag).get()
        .then((tagDoc) => {
          let tagDocuments = [];
          if (tagDoc.exists) {
            console.log('doc exists when adding: ', tagDoc.data()['documents']);
            tagDocuments = tagDocuments.concat(tagDoc.data()['documents']);
          }

          if (!tagDocuments.includes(context.params.docId)) {
            tagDocuments.push(context.params.docId);
          }

          console.log('setting docs', tagDocuments, 'to tag', tag, 'after addition of', context.params.docId);

          return tagListRef.doc(tag).set({
            documents: tagDocuments,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
        })
        .then(() => console.log('added tag', tag))
        .catch((error) => console.log('error tag add:', error));
      });

    // Add an 'objectID' field which Algolia requires
    newValue.objectID = context.params.docId;

    // Write to the algolia index
    const index = exports.getAlgoliaIndex();
    const saveObjectPromise = index.saveObject(newValue)
      .then(() => console.log('Update snippet on Algoria'))
      .catch(error => {
        console.error('Error to update snippet to Algoria', error);
        process.exit(1);
      });
    
    promises = removedTagsPromise.concat(addedTagsPromise);
    promises.push(saveObjectPromise);
    return Promise.all(promises);
  })

exports.snippetsOnDelete = functions.firestore
  .document('user_data/{userId}/snippets/{docId}')
  .onDelete((snapshot, context) => {
    const tagListRef = fireStore.collection('user_data/' + context.params.userId + '/tags');

    const data = snapshot.data();
    const promises = data['tags']
      .filter((tag) => tag !== '__all__')
      .map((tag) => {
        return tagListRef.doc(tag).get()
          .then((tagDoc) => {
            if (tagDoc.exists) {
              console.log('doc exists when removing: ', tagDoc.data()['documents']);

              const tagDocuments = tagDoc.data()['documents'].filter(
                v => v !== context.params.docId);

              console.log('setting docs ', tagDocuments, 'from tag ', tag, 'after removal of ', context.params.docId);

              if (tagDocuments.length) {
                console.log('After removal, doc should still exist.');
                return tagListRef.doc(tag).set({
                  documents: tagDocuments,
                  timestamp: admin.firestore.FieldValue.serverTimestamp(),
                });
              } else {
                console.log('No documents belong to this tag. remove tag document itself');
                return tagListRef.doc(tag).delete();
              }
            }
            // eslint-disable-next-line consistent-return
            return;
          })
          .then(() => console.log('tag delete done'))
          .catch((error) => console.log('error tag delete:', error));
    });

    // Get Algolia's objectID from the Firebase object key
    const objectID = context.params.docId;

    // Remove the object from Algolia
    const index = exports.getAlgoliaIndex();
    const deleteAlgoliaIndexPromise = index
      .deleteObject(objectID)
      .then(() => {
        console.log('Firebase object deleted from Algolia', objectID);
        return;
      })
      .catch(error => {
        console.error('Error when deleting contact from Algolia', error);
        process.exit(1);
      });

    promises.push(deleteAlgoliaIndexPromise);
    return Promise.all(promises);
  });

exports.getHtmlTitle = (url) => {
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

  return exports.getHtmlTitle(uri)
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
  const ALGOLIA_ID = functions.config().algolia.app_id;
  const ALGOLIA_ADMIN_KEY = functions.config().algolia.api_key;
  const ALGOLIA_SEARCH_KEY = functions.config().algolia.search_key;
  const client = algoliasearch(ALGOLIA_ID, ALGOLIA_ADMIN_KEY);
  const key = client.generateSecuredApiKey(ALGOLIA_SEARCH_KEY, params);

  // Then return this key as {key: '...key'}
  res.json({key});
});

// Finally, pass our ExpressJS app to Cloud Functions as a function
// called 'getSearchKey';
exports.getSearchKey = functions.https.onRequest(app);
