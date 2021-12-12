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

describe('exportRssToRecommendationAi', () => {
  it('Integration test', async () => {
    const dummyData = {
      title: 'dummy title',
      content: 'dummy content',
      pubDate: '2020-01-01T03:33:33.000001Z',
    };
    const beforeSnap = test.firestore.makeDocumentSnapshot(
      {},
      'rss_contents_store/rss_content/dummyFeedUrl/dummyItemLink'
    );
    const afterSnap = test.firestore.makeDocumentSnapshot(
      dummyData,
      'rss_contents_store/rss_content/dummyFeedUrl/dummyItemLink'
    );
    const change = test.makeChange(beforeSnap, afterSnap);

    const wrapped = test.wrap(sut.exportRssToRecommendationAi);
    await wrapped(change, {
      params: {
        feedUrl: 'dummyFeedUrl',
        itemLink: 'dummyItemLink',
      },
    });
  });
});
