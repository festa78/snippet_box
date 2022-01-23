"""BigQuery tables to read / write data.
"""

import apache_beam as beam
from apache_beam.io import ReadFromBigQuery, WriteToBigQuery

def read_rss_items(pipeline):
  """Read the documents from bigquery and returns (uri, line) pairs."""
  # TODO: insert project id by value.
  QUERY = '''
  SELECT DISTINCT title,link
  FROM `flutter-myapp-test.rss_contents_store.rss-items`
  LIMIT 1000
  '''

  return (
    pipeline
    | 'ReadTable' >> ReadFromBigQuery(query=QUERY, use_standard_sql=True)
    | 'WithPair (link, title)' >> beam.Map(lambda v: (v['link'], v['title']))
  )

def write_word_uri_tfidf(pipeline):
  """Write the results from pipeline to destinations.
  """
  TABLE_SPEC = 'flutter-myapp-test:rss_contents_store.tf-idf'
  TABLE_SCHEMA = 'word:STRING, uri:STRING, tfidf:FLOAT'
  
  (pipeline
    | "Write to Big Query" >> WriteToBigQuery(
      TABLE_SPEC,
      schema=TABLE_SCHEMA,
      write_disposition=beam.io.BigQueryDisposition.WRITE_TRUNCATE,
      create_disposition=beam.io.BigQueryDisposition.CREATE_IF_NEEDED))
