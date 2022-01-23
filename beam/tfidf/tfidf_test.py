#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

"""Test for the TF-IDF example."""

# pytype: skip-file

import logging
import unittest
from unittest import mock

import apache_beam as beam
from apache_beam.testing.test_pipeline import TestPipeline
from apache_beam.testing.util import assert_that
from apache_beam.testing.util import equal_to

import tfidf

EXPECTED_RESULTS = set([
    ('ghi', '1.txt', 0.3662040962227032), ('abc', '1.txt', 0.0),
    ('abc', '3.txt', 0.0), ('abc', '2.txt', 0.0),
    ('def', '1.txt', 0.13515503603605478), ('def', '2.txt', 0.2027325540540822)
])

EXPECTED_LINE_RE = r'\(u?\'([a-z]*)\', \(\'.*([0-9]\.txt)\', (.*)\)\)'

class TfIdfTest(unittest.TestCase):
  def create_file(self, path, contents):
    logging.info('Creating temp file: %s', path)
    with open(path, 'wb') as f:
      f.write(contents.encode('utf-8'))

  def test_tfidf_transform(self):
    with TestPipeline() as p:

      def re_key(word_uri_and_tfidf):
        (word, uri_and_tfidf) = word_uri_and_tfidf
        return (
          word, uri_and_tfidf[0], uri_and_tfidf[1])

      uri_to_line = p | 'create sample' >> beam.Create(
          [('1.txt', 'abc def ghi'), ('2.txt', 'abc def'), ('3.txt', 'abc')])
      result = (
        uri_to_line |
        tfidf.TfIdf() |
        beam.Map(re_key))
      assert_that(result, equal_to(EXPECTED_RESULTS))
      # Run the pipeline. Note that the assert_that above adds to the pipeline
      # a check that the result PCollection contains expected values.
      # To actually trigger the check the pipeline must be run (e.g. by
      # exiting the with context).

  @mock.patch('tfidf.ReadFromBigQuery')
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
      assert_that(tfidf.read_bigquery_documents(p),
        equal_to(EXPECTED_RESULTS_BIGQUERY))

  @mock.patch('tfidf.WriteToBigQuery')
  def test_write_to_destination(self, mock_write_to_bigquery):
    with TestPipeline() as p:
      tfidf.write_to_destination(p)
      mock_write_to_bigquery.assert_called_once()

if __name__ == '__main__':
  logging.getLogger().setLevel(logging.INFO)
  unittest.main()
