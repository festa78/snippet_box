#!/usr/bin/python3 -B

from collections import defaultdict

from google.cloud import bigquery, firestore
from sklearn import decomposition, model_selection, neighbors, preprocessing
import numpy as np
import pandas as pd


class TfidfBqTable:
  QUERY = """
  SELECT *
  FROM `flutter-myapp-test.rss_contents_store.tf-idf`
  """

  def __init__(self):
    self.data = bigquery.Client(project="flutter-myapp-test").query(self.QUERY)

  def unique_words(self):
    return sorted(
        list(set(row['word'] for row in self.data)))

  def uri_to_word_and_tfidf_list(self):
    uri_to_word_and_tfidf_list = defaultdict(list) 
    for row in self.data:
      uri_to_word_and_tfidf_list[row['uri']].append((row['word'], row['tfidf']))
    return uri_to_word_and_tfidf_list

  def uris(self):
    return sorted(list(self.uri_to_word_and_tfidf_list().keys()))

  def read_as_dataframe(self):
    tfidf_matrix = []
    uri_to_word_and_tfidf_list = self.uri_to_word_and_tfidf_list()
    unique_words = self.unique_words()
    uris = self.uris()
    for uri in uris:
      word_to_tfidf_dict = {
        row[0]: row[1] for row in uri_to_word_and_tfidf_list[uri]
      }
      tfidf_vector = [
        word_to_tfidf_dict[word] if word in word_to_tfidf_dict.keys() else 0.0
        for word in unique_words
      ]
      tfidf_matrix.append(tfidf_vector)

    return pd.DataFrame(
      tfidf_matrix, columns=unique_words, index=uris
    )

  def read_as_numpy(self):
    return self.read_as_dataframe().to_numpy()


class Kde:
  def __init__(self, input_data):
    self.input_data = input_data

  def standardized_input(self):
    return preprocessing.StandardScaler().fit_transform(self.input_data)

  def pca_input(self, n_components=5):
    return decomposition.PCA(n_components=n_components).fit_transform(
      self.standardized_input()
    )

  def grid_search_bandwidth(self):
    params = {"bandwidth": np.logspace(-1, 1, 20)}
    grid = model_selection.GridSearchCV(neighbors.KernelDensity(), params)
    grid.fit(self.pca_input())
    print("best bandwidth: {0}".format(grid.best_estimator_.bandwidth))
    return grid.best_estimator_.bandwidth

  def score_samples(self, bandwidth=1.):
    pca_input = self.pca_input()
    return neighbors.KernelDensity(
      kernel="gaussian", bandwidth=bandwidth).fit(
        pca_input).score_samples(pca_input)


class TrendScoreFirestore:
  def __init__(self, input_data):
    self.input_data = input_data

  def input_data_as_bq_schema_json(self):
    return [
      {"uri": row["uri"], "trend_score": row["trend_score"]}
      for _, row in self.input_data.reset_index().iterrows()
    ]

  def write(self):
    collection_ref = firestore.Client(project="flutter-myapp-test").collection(
      "rss_trend_scores")
    for _, row in self.input_data.reset_index().iterrows():
      collection_ref.document(row["uri"].replace('/', '_')
        ).set({"trend_score": row["trend_score"]})


if __name__ == '__main__':
  tfidf_bq = TfidfBqTable()
  input_data = tfidf_bq.read_as_numpy()

  scores_pd = pd.DataFrame(
    np.array(
      [
        tfidf_bq.uris(),
        Kde(input_data).score_samples(
          Kde(input_data).grid_search_bandwidth()
        ).tolist(),
      ]
    ).transpose(),
    columns=["uri", "trend_score"],
  ).sort_values(by="trend_score")

  TrendScoreFirestore(scores_pd).write()