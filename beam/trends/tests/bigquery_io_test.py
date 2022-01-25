"""Test for the bigquery IO."""

# pytype: skip-file

import logging
import unittest
from unittest import mock

import apache_beam as beam
from apache_beam.testing.test_pipeline import TestPipeline
from apache_beam.testing.util import assert_that
from apache_beam.testing.util import equal_to

import bigquery_io

EXPECTED_RESULTS = set([
    ('ghi', '1.txt', 0.3662040962227032), ('abc', '1.txt', 0.0),
    ('abc', '3.txt', 0.0), ('abc', '2.txt', 0.0),
    ('def', '1.txt', 0.13515503603605478), ('def', '2.txt', 0.2027325540540822)
])

EXPECTED_LINE_RE = r'\(u?\'([a-z]*)\', \(\'.*([0-9]\.txt)\', (.*)\)\)'

class BigQueryIoTest(unittest.TestCase):
  @mock.patch('bigquery_io.ReadFromBigQuery')
  def test_read_bigquery_documents(self, mock_read_from_bigquery):
    EXPECTED_RESULTS_BIGQUERY = set([
        ('1.com', 'abc def ghi'),
        ('2.com', 'abc def'),
        ('3.com', 'abc'),
    ])

    mock_read_from_bigquery.return_value = beam.Create(
        [
          {'link': '1.com', 'title': 'abc def ghi'},
          {'link': '2.com', 'title': 'abc def'},
          {'link': '3.com', 'title': 'abc'},
        ])

    with TestPipeline() as p:
      assert_that(bigquery_io.read_rss_items(p),
        equal_to(EXPECTED_RESULTS_BIGQUERY))

  def test_transform_word_uri_tfidf_to_bqschema(self):
    TEST_INPUT = [
      ('abc', ('1.txt', 0.0)),
      ('def', ('1.txt', 0.13515503603605478)),
      ('ghi', ('1.txt', 0.3662040962227032)),
      ('abc', ('2.txt', 0.0)),
      ('def', ('2.txt', 0.2027325540540822)),
      ('abc', ('3.txt', 0.0)),
    ]
    EXPECTED_RESULTS_TRANSFORM = [
      {'word': 'abc', 'uri': '1.txt', 'tfidf': 0.0},
      {'word': 'def', 'uri': '1.txt', 'tfidf': 0.13515503603605478},
      {'word': 'ghi', 'uri': '1.txt', 'tfidf': 0.3662040962227032},
      {'word': 'abc', 'uri': '2.txt', 'tfidf': 0.0},
      {'word': 'def', 'uri': '2.txt', 'tfidf': 0.2027325540540822},
      {'word': 'abc', 'uri': '3.txt', 'tfidf': 0.0},
    ]
    with TestPipeline() as p:
      result = (p
        | beam.Create(TEST_INPUT)
        | bigquery_io.TransformWordUriTfidfToBqSchema())
      assert_that(result, equal_to(EXPECTED_RESULTS_TRANSFORM))

if __name__ == '__main__':
  logging.getLogger().setLevel(logging.INFO)
  unittest.main()
