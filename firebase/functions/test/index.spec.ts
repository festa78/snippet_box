import { assert, expect } from 'chai';
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import firebaseFunctionsTest from 'firebase-functions-test';
import { describe, it } from 'mocha';

import * as sut from '../src/index';

process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';

const test = firebaseFunctionsTest(
  {
    projectId: 'flutter-myapp-test',
  },
  './test/flutter-myapp-test-559e258b7bd5.json'
);

describe('getRssContent', () => {
  it('Throw error with un-authorized request', () => {
    const wrapped = test.wrap(sut.getRssContent);
    assert.throws(
      () => wrapped('example.com', {}),
      functions.https.HttpsError,
      'Auth Error'
    );
  });
});

describe('updateRssContent', () => {
  it('Throw error with un-authorized request', () => {
    const wrapped = test.wrap(sut.updateRssContent);
    assert.throws(
      () => wrapped('example.com', {}),
      functions.https.HttpsError,
      'Auth Error'
    );
  });

  it('Parse and update rss feed contents', async () => {
    const wrapped = test.wrap(sut.updateRssContent);
    const testUris = [
      { uri: 'https://hnrss.org/frontpage' },
      { uri: 'https://www.reddit.com/.rss' },
    ];

    await Promise.all(
      testUris.map((doc) =>
        admin
          .firestore()
          .collection('user_data')
          .doc('dummy_user')
          .collection('feed_uris')
          .add(doc)
      )
    );

    await wrapped({ auth: true });

    const rssContentDocRef = admin
      .firestore()
      .collection('rss_contents_store')
      .doc('rss_content');

    await Promise.all(
      testUris.map((doc) =>
        rssContentDocRef
          .collection(doc['uri'].replace(/\//g, '_'))
          .listDocuments()
      )
    ).then((docs) => {
      return Promise.all(docs.map((doc) => expect(doc.length > 0)));
    });
  });
});
