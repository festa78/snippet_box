"""Schema transformations.
"""

import apache_beam as beam

class TransformWordUriTfidfToBqSchema(beam.PTransform):
  """Convert (word, (uri, tfidf)) elements to bq table format."""
  def expand(self, word_uri_and_tfidf):
    def transform_to_bq_schema(word_uri_and_tfidf):
      """Transform from word_uri_and_tfidf to BQ query schema"""
      (word, uri_and_tfidf) = word_uri_and_tfidf
      yield {
        'word': word,
        'uri': uri_and_tfidf[0],
        'tfidf': uri_and_tfidf[1],
      }

    return ( 
      word_uri_and_tfidf | 'Transform to BigQuery schema' >> beam.FlatMap(
        transform_to_bq_schema)
    )