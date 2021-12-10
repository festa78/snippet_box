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

// This test depends on exportRssToStorage
// and use the stored results under Storage.
describe('ReadStorageForBigquery', () => {
  it('Integration test', async () => {
    // The target method only kick off the job and this tests
    // only ensures it starts job correctly.
    // TODO: also check if the bigquery job finished properly.
    const wrapped = test.wrap(sut.bigQueryImportStorageTrigger);
    const jobId = await wrapped({
      name:
        'rss_content_exports/dummyFeedUrl/' +
        'all_namespaces/kind_dummyFeedUrl/' +
        'all_namespaces_kind_dummyFeedUrl.export_metadata',
    });
    assert.isNotNull(jobId);
    assert.isDefined(jobId);
  });
});

// This should run after ReadStorageForBigquery
// otherwise it needs to wait for the operation.
describe('exportRssToStorage', () => {
  it('Integration test', async () => {
    // NOTE: exportDocuments command used in the
    // exportRssToStorage method explicitly uses
    // real firestore and storage regardless of
    // emulators' availability.
    // Thus here we use the real firebase services
    // for test purpose.

    // NOTE: This is just a dummy data for triggering method and will not
    // be exported to Storage.
    // Actual data to be exported should be already prepared in real
    // Firestore.
    const dummyData = {
      title: 'dummy title',
      content: 'dummy content',
      pubDate: 'dummy pubDate',
    };
    const snap = test.firestore.makeDocumentSnapshot(
      dummyData,
      'rss_contents_store/rss_content/dummyFeedUrl/dummyItemLink'
    );

    const wrapped = test.wrap(sut.exportRssToStorage);
    await wrapped(snap, {
      params: {
        feedUrl: 'dummyFeedUrl',
        itemLinx: 'dummyItemLink',
      },
    });
  }).timeout(4000);
});
