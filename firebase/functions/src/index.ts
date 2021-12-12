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

export const exportRssToRecommendationAi = functions.firestore
  .document('rss_contents_store/rss_content/{feedUrl}/{itemLink}')
  .onWrite(async (snap, context) => {
    const productData = {
      id: context.params.itemLink,
      title: snap.after.data()?.title,
      categories: context.params.feedUrl,
      availableTime: snap.after.data()?.pubDate,
    };

    const auth = await google.auth.getClient({
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    });

    google
      .retail('v2')
      .projects.locations.catalogs.branches.products.import({
        auth,
        parent:
          'projects/flutter-myapp-test/locations/global/catalogs/default_catalog/branches/default_branch',
        requestBody: {
          inputConfig: {
            productInlineSource: {
              products: [productData],
            },
          },
        },
      })
      .then((res) => {
        console.log(res);
      })
      .catch((error) => {
        console.log(error);
      });
  });
