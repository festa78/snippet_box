"""Test for the bigquery IO."""

# pytype: skip-file

import logging
import unittest
from unittest import mock

import apache_beam as beam
from apache_beam.testing.test_pipeline import TestPipeline
from apache_beam.testing.util import assert_that
from apache_beam.testing.util import equal_to

from trends import bigquery_io

EXPECTED_RESULTS = set([('ghi', '1.txt', 0.3662040962227032),
                        ('abc', '1.txt', 0.0), ('abc', '3.txt', 0.0),
                        ('abc', '2.txt', 0.0),
                        ('def', '1.txt', 0.13515503603605478),
                        ('def', '2.txt', 0.2027325540540822)])

EXPECTED_LINE_RE = r'\(u?\'([a-z]*)\', \(\'.*([0-9]\.txt)\', (.*)\)\)'


class BigQueryIoTest(unittest.TestCase):

    @mock.patch('trends.bigquery_io.ReadFromBigQuery')
    def test_read_bigquery_documents(self, mock_read_from_bigquery):
        EXPECTED_RESULTS_BIGQUERY = set([
            ('1.com', ('abc def ghi', 'url1.rss')),
            ('2.com', ('abc def', 'url1.rss')),
            ('3.com', ('abc', 'url2.rss')),
        ])

        mock_read_from_bigquery.return_value = beam.Create([
            {
                'link': '1.com',
                'title': 'abc def ghi',
                'feedUrl': 'url1.rss'
            },
            {
                'link': '2.com',
                'title': 'abc def',
                'feedUrl': 'url1.rss'
            },
            {
                'link': '3.com',
                'title': 'abc',
                'feedUrl': 'url2.rss'
            },
        ])

        with TestPipeline() as p:
            assert_that(bigquery_io.read_rss_items(p),
                        equal_to(EXPECTED_RESULTS_BIGQUERY))

    def test_transform_word_to_feedurl_uri_and_tfidf_to_bqschema(self):
        TEST_INPUT = [
            ('abc', ('url1.rss', '1.txt', 0.0)),
            ('abc', ('url1.rss', '2.txt', 0.0)),
            ('abc', ('url1.rss', '3.txt', 0.0)),
            ('abc', ('url2.rss', '1.txt', 0.0)),
            ('abc', ('url2.rss', '2.txt', 0.0)),
            ('abc', ('url2.rss', '3.txt', 0.0)),
            ('def', ('url1.rss', '1.txt', 0.13515503603605478)),
            ('def', ('url1.rss', '2.txt', 0.2027325540540822)),
            ('ghi', ('url1.rss', '1.txt', 0.3662040962227032)),
        ]
        EXPECTED_RESULTS_TRANSFORM = [
            {
                'word': 'abc',
                'uri': '1.txt',
                'tfidf': 0.0,
                'feedUrl': 'url1.rss'
            },
            {
                'word': 'abc',
                'uri': '2.txt',
                'tfidf': 0.0,
                'feedUrl': 'url1.rss'
            },
            {
                'word': 'abc',
                'uri': '3.txt',
                'tfidf': 0.0,
                'feedUrl': 'url1.rss'
            },
            {
                'word': 'abc',
                'uri': '1.txt',
                'tfidf': 0.0,
                'feedUrl': 'url2.rss'
            },
            {
                'word': 'abc',
                'uri': '2.txt',
                'tfidf': 0.0,
                'feedUrl': 'url2.rss'
            },
            {
                'word': 'abc',
                'uri': '3.txt',
                'tfidf': 0.0,
                'feedUrl': 'url2.rss'
            },
            {
                'word': 'def',
                'uri': '1.txt',
                'tfidf': 0.13515503603605478,
                'feedUrl': 'url1.rss'
            },
            {
                'word': 'def',
                'uri': '2.txt',
                'tfidf': 0.2027325540540822,
                'feedUrl': 'url1.rss'
            },
            {
                'word': 'ghi',
                'uri': '1.txt',
                'tfidf': 0.3662040962227032,
                'feedUrl': 'url1.rss'
            },
        ]
        with TestPipeline() as p:
            result = (p
                      | beam.Create(TEST_INPUT)
                      | bigquery_io.TransformWordFeedUrlUriTfidfToBqSchema())
            result | beam.Map(print)
            assert_that(result, equal_to(EXPECTED_RESULTS_TRANSFORM))


if __name__ == '__main__':
    logging.getLogger().setLevel(logging.INFO)
    unittest.main()
