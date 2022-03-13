#!/usr/bin/python3 -B

from collections import defaultdict
from logging import getLogger

from google.cloud import bigquery, firestore
from sklearn import decomposition, model_selection, neighbors, preprocessing
import numpy as np
import pandas as pd

logger = getLogger(__name__)


class TfidfBqTable:

    def __init__(self):
        QUERY = """
        SELECT word,uri,tfidf,feedUrl
        FROM `flutter-myapp-test.rss_contents_store.tf-idf`
        WHERE feedUrl IS NOT NULL
        """

        self.data = bigquery.Client(project="flutter-myapp-test").query(QUERY)

    def unique_words(self):
        return sorted(list(set(row['word'] for row in self.data)))

    def uri_to_word_and_tfidf_list(self):
        uri_to_word_and_tfidf_list = defaultdict(list)
        for row in self.data:
            uri_to_word_and_tfidf_list[row['uri']].append(
                (row['word'], row['tfidf']))
        return uri_to_word_and_tfidf_list

    def uris(self):
        return sorted(list(self.uri_to_word_and_tfidf_list().keys()))

    def uri_to_feedurl_list(self):
        uri_to_feedurl_list = defaultdict(list)
        for row in self.data:
            if row['feedUrl'] not in uri_to_feedurl_list[row['uri']]:
                uri_to_feedurl_list[row['uri']].append(row['feedUrl'])

        return uri_to_feedurl_list

    def read_as_dataframe(self):
        tfidf_matrix = []
        uri_to_word_and_tfidf_list = self.uri_to_word_and_tfidf_list()
        unique_words = self.unique_words()
        uris = self.uris()
        for uri in uris:
            word_to_tfidf_dict = {
                row[0]: row[1]
                for row in uri_to_word_and_tfidf_list[uri]
            }
            tfidf_vector = [
                word_to_tfidf_dict[word]
                if word in word_to_tfidf_dict.keys() else 0.0
                for word in unique_words
            ]
            tfidf_matrix.append(tfidf_vector)

        return pd.DataFrame(tfidf_matrix, columns=unique_words, index=uris)

    def read_as_numpy(self):
        return self.read_as_dataframe().to_numpy()


class Kde:

    def __init__(self, input_data):
        self.input_data = input_data

    def standardized_input(self):
        return preprocessing.StandardScaler().fit_transform(self.input_data)

    def pca_input(self, n_components=5):
        return decomposition.PCA(n_components=n_components).fit_transform(
            self.standardized_input())

    def grid_search_bandwidth(self):
        params = {"bandwidth": np.logspace(-1, 1, 20)}
        grid = model_selection.GridSearchCV(neighbors.KernelDensity(), params)
        grid.fit(self.pca_input())
        print("best bandwidth: {0}".format(grid.best_estimator_.bandwidth))
        return grid.best_estimator_.bandwidth

    def score_samples(self, bandwidth=1.):
        pca_input = self.pca_input()
        return neighbors.KernelDensity(
            kernel="gaussian",
            bandwidth=bandwidth).fit(pca_input).score_samples(pca_input)


class TrendScoreFirestore:

    def __init__(self, input_data):
        self.input_data = input_data

    def write(self):
        document_ref = firestore.Client(
            project="flutter-myapp-test").collection(
                "rss_contents_store").document("rss_content")

        for _, row in self.input_data.reset_index().iterrows():
            feed_url_replace = row["feed_url"].replace('/', '_')
            uri_replace = row["uri"].replace('/', '_')
            feed_url_ref = document_ref.collection(feed_url_replace)
            uri_ref = feed_url_ref.document(uri_replace)
            if not uri_ref.get().exists:
                logger.info(
                    f"document does not exist: ({feed_url_replace}, {uri_replace})"
                )
                continue
            uri_ref.set({"trend_score": row["trend_score"]}, merge=True)


if __name__ == '__main__':
    tfidf_bq = TfidfBqTable()
    input_data = tfidf_bq.read_as_dataframe()
    uri_and_trend_scores = pd.DataFrame(np.array([
        input_data.index,
        Kde(input_data.to_numpy()).score_samples(
            Kde(input_data.to_numpy()).grid_search_bandwidth()).tolist(),
    ]).transpose(),
                                        columns=["uri", "trend_score"])

    uris = []
    feedurls = []
    for uri, feedurl_list in tfidf_bq.uri_to_feedurl_list().items():
        uris.extend([uri] * len(feedurl_list))
        feedurls.extend(feedurl_list)
    uri_and_feedurls = pd.DataFrame(np.array([
        uris,
        feedurls,
    ]).transpose(),
                                    columns=["uri", "feed_url"])

    uri_feedurl_and_trend_scores = uri_and_feedurls.merge(uri_and_trend_scores)

    TrendScoreFirestore(uri_feedurl_and_trend_scores).write()
