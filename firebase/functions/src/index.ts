import * as admin from 'firebase-admin';
import * as functions from 'firebase-functions';
import fetch from 'node-fetch';
import { BigQuery } from '@google-cloud/bigquery';
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
              return rssContent.items
                .filter((rssItem) => rssItem.link != undefined)
                .map((rssItem) => {
                  const titleTermFrequency: { [key: string]: number } = {};
                  rssItem.title?.match(/\b(\w+)\b/g)?.forEach((term) => {
                    if (term in titleTermFrequency) {
                      titleTermFrequency[term] += 1;
                    } else {
                      titleTermFrequency[term] = 1;
                    }
                  });

                  const bigQuery = new BigQuery();

                  return bigQuery
                    .dataset('rss_contents_store')
                    .table('rss-items')
                    .insert({
                      title: rssItem.title ?? null,
                      link: rssItem.link ?? null,
                      pubDate: rssItem.pubDate ?? null,
                      creator: rssItem.creator ?? null,
                      content: rssItem.content ?? null,
                      contentSnippet: rssItem.contentSnippet ?? null,
                      guid: rssItem.guid ?? null,
                      isoDate: rssItem.isoDate ?? null,
                      feedUrl: rssContent.feedUrl ?? null,
                    })
                    .catch((error) => {
                      console.log(error);
                      if (error.name === 'PartialFailureError') {
                        for (const err of error.errors as {
                          errors: { message: string; reason: string }[];
                          row: any;
                        }[]) {
                          console.log(err);
                        }
                      }
                    });
                });
            })
        );
      });
  });
