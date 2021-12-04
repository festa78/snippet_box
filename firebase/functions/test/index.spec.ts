import { assert, expect } from 'chai';
import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import firebaseFunctionsTest from 'firebase-functions-test';
import { describe, it } from 'mocha';

import * as sut from '../src/index';

process.env.FIRESTORE_EMULATOR_HOST = 'localhost:8080';
process.env.GOOGLE_APPLICATION_CREDENTIALS = './flutter-myapp-test.json';

const test = firebaseFunctionsTest(
  {
    projectId: 'flutter-myapp-test',
  },
  './test/flutter-myapp-test.json'
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

describe('updateRssContentOnSchedule', () => {
  it('Parse and update rss feed contents', async () => {
    const wrapped = test.wrap(sut.updateRssContentOnSchedule);
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

    await wrapped({});

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
  }).timeout(4000);
});

describe('exportRssForBigquery', () => {
  it('exportRssToStorage', async () => {
    // NOTE: exportDocuments command used in the
    // exportRssToStorage method explicitly uses
    // real firestore and storage regardless of
    // emulators' availability.
    // Thus here we use the real firebase services
    // for test purpose.
    const snap = test.firestore.makeDocumentSnapshot(
      {
        title: 'dummy title',
        content: 'dummy content',
        pubDate: 'dummy pubDate',
      },
      'rss_contents_store/rss_content/dummyFeedUrl/dummyItemLink'
    );

    const wrapped = test.wrap(sut.exportRssToStorage);
    await wrapped(snap, {
      params: {
        feedUrl: 'dummyFeedUrl',
        itemLinx: 'dummyItemLink',
      },
    });
  });
});
