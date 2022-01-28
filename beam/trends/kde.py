"""Compute kernel density estimation value of each document
given TF-IDF scores.
"""

import apache_beam as beam
from apache_beam.pvalue import AsIter

class KernelDensityEstimationByTfidf(beam.PTransform):
  """Compute kernel density estimation value of each document
  given TF-IDF scores.
  """
  def expand(self, word_uri_and_tfidf):
    def transform_to_uri_word_and_tfidf(word_uri_and_tfidf):
      """Transform from word_uri_and_tfidf to
      {uri: (word, tfidf)} format, so that it can
      group by uri.
      """
      (word, uri_and_tfidf) = word_uri_and_tfidf
      return (uri_and_tfidf[0], (word, uri_and_tfidf[1]))

    uri_word_and_tfidf = (
      word_uri_and_tfidf
      | 'Uri to WordTfidf map' >> beam.Map(transform_to_uri_word_and_tfidf)
      | 'Group by uri' >> beam.GroupByKey()
    )

    def transform_to_vector_repr(uri_word_and_tfidf_list, unique_words):
      """Form a vector whose element represents each unique word and
      its tf-idf.
      """
      (uri, word_and_tfidf_list) = uri_word_and_tfidf_list
      word_and_tfidf_dict = {word: tfidf for (word, tfidf) in word_and_tfidf_list}
      tfidf_vector = [
        word_and_tfidf_dict[word] if word in word_and_tfidf_dict.keys() else 0.0
        for word in unique_words
      ]

      return (uri, tfidf_vector)

    # NOTE: unique_words are not sorted.
    # Does not matter unless we incrementally update the KDE values.
    unique_words = (
      word_uri_and_tfidf
      | 'Get word list' >> beam.Keys()
      | 'Get unique words' >> beam.Distinct()
    )

    tfidf_vector = (
      uri_word_and_tfidf
      | 'Compute tfidf vector by unique words' >> beam.Map(
        transform_to_vector_repr, AsIter(unique_words))
    )

    return tfidf_vector
