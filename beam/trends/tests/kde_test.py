"""Test for the kernel density estimator pipeline.
"""

# pytype: skip-file

import logging
import unittest

import apache_beam as beam
from apache_beam.testing.test_pipeline import TestPipeline
from apache_beam.testing.util import assert_that
from apache_beam.testing.util import equal_to

import kde

class TfIdfTest(unittest.TestCase):
  def test_kde_transform(self):
    TEST_INPUT = [
      ('ghi', ('1.txt', 0.3662040962227032)),
      ('def', ('1.txt', 0.13515503603605478)),
      ('abc', ('1.txt', 0.0)),
      ('abc', ('2.txt', 0.0)),
      ('def', ('2.txt', 0.2027325540540822)),
      ('abc', ('3.txt', 0.0)),
    ]
    EXPECTED_RESULTS = [
      ('1.txt', [
        0.3662040962227032,
        0.13515503603605478,
        0.0,
      ]),
      ('2.txt', [
        0.0,
        0.2027325540540822,
        0.0,
      ]),
      ('3.txt', [
        0.0,
        0.0,
        0.0,
      ]),
    ]

    with TestPipeline() as p:
      result = (p
        | beam.Create(TEST_INPUT)
        | kde.KernelDensityEstimationByTfidf())
      assert_that(result, equal_to(EXPECTED_RESULTS))
      # Run the pipeline. Note that the assert_that above adds to the pipeline
      # a check that the result PCollection contains expected values.
      # To actually trigger the check the pipeline must be run (e.g. by
      # exiting the with context).

if __name__ == '__main__':
  logging.getLogger().setLevel(logging.INFO)
  unittest.main()
