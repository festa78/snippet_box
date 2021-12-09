import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import { google } from 'googleapis';
import fetch from 'node-fetch';
import Parser from 'rss-parser';

admin.initializeApp();

export const getRssContent = functions.https.onCall(
  (data: string, context: functions.https.CallableContext) => {
    if (!context.auth) {
      throw new functions.https.HttpsError('permission-denied', 'Auth Error');
    }

    return fetch(data).then((response) => {
      return response.text();
    });
  }
);

export const updateRssContentOnSchedule = functions.pubsub
  .schedule('every 24 hours')
  .onRun(() => {
    return admin
      .firestore()
      .collection('user_data')
      .listDocuments()
      .then((userRefs) => {
        return Promise.all(
          userRefs.map((userRef) => {
            return userRef.collection('feed_uris').listDocuments();
          })
        );
      })
      .then((uriRefs) => {
        return Promise.all(
          uriRefs.flat().map((uriRef) => {
            return uriRef.get();
          })
        );
      })
      .then((uriSnapshots) => {
        return Promise.all(
          uriSnapshots
            .filter((uriSnapshot) => uriSnapshot.exists)
            .map((uriSnapshot) => {
              const uriData = uriSnapshot.data();
              const parser = new Parser();
              return parser.parseURL(uriData?.['uri']);
            })
        );
      })
      .then((rssContents) => {
        return Promise.all(
          rssContents
            .filter((rssContent) => rssContent.feedUrl != undefined)
            .flatMap((rssContent) => {
              // Index name does not accept a slash.
              const uriCollectionRef = admin
                .firestore()
                .collection('rss_contents_store')
                .doc('rss_content')
                // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
                .collection(rssContent.feedUrl!.replace(/\//g, '_'));

              return rssContent.items
                .filter((rssItem) => rssItem.link != undefined)
                .map((rssItem) => {
                  return (
                    uriCollectionRef
                      // eslint-disable-next-line @typescript-eslint/no-non-null-assertion
                      .doc(rssItem.link!.replace(/\//g, '_'))
                      .set(
                        {
                          title: rssItem.title,
                          content: rssItem.content,
                          pubDate: rssItem.pubDate,
                        },
                        { merge: true }
                      )
                  );
                });
            })
        );
      });
  });

export const exportRssToStorage = functions.firestore
  .document('rss_contents_store/rss_content/{feedUrl}')
  .onWrite(async (snap, context) => {
    const auth = new admin.firestore.v1.FirestoreAdminClient();
    const projectId = admin.installations().app.options.projectId;

    await admin
      .storage()
      .bucket(`${projectId}-firestore`)
      .deleteFiles({
        prefix: `rss_content_exports/${context.params.feedUrl}`,
      });

    await auth
      .exportDocuments({
        name: `projects/${projectId}/databases/(default)`,
        collectionIds: [`${context.params.feedUrl}`],
        outputUriPrefix: `gs://${projectId}-firestore/rss_content_exports/${context.params.feedUrl}`,
      })
      .then((res) => {
        console.log('success export');
        console.log(res);
      })
      .catch((error) => {
        console.log('error export');
        console.log(error);
        throw new functions.https.HttpsError('unknown', error);
      });
  });

export const bigQueryImportStorageTrigger = functions.storage
  .bucket(`${admin.installations().app.options.projectId}-firestore`)
  .object()
  .onFinalize(async (object) => {
    const name = object.name!;
    const matched = name.match(/all_namespaces_kind_(.+)\.export_metadata/);
    if (!matched) {
      return console.log(`invalid object: ${name}`);
    }

    const collectionName = matched[1];
    const auth = await google.auth.getClient({
      scopes: ['https://www.googleapis.com/auth/bigquery'],
    });
    const projectId = admin.installations().app.options.projectId;
    const result = await google.bigquery('v2').jobs.insert({
      auth,
      projectId: projectId,
      requestBody: {
        configuration: {
          load: {
            destinationTable: {
              tableId: collectionName,
              datasetId: 'firestore',
              projectId: projectId,
            },
            sourceFormat: 'DATASTORE_BACKUP',
            writeDisposition: 'WRITE_TRUNCATE',
            sourceUris: [`gs://${projectId}-firestore/${name}`],
          },
        },
      },
    });

    console.log(result);
  });
