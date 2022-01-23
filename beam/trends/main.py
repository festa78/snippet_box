"""Compute document trends based on 
kernel density estimation and TF-IDF
"""

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.options.pipeline_options import SetupOptions

import bigquery_io
import schema_transform
import tfidf

def run(argv=None, save_main_session=True):
  """Main entry point; defines and runs the tfidf pipeline."""
  # We use the save_main_session option because one or more DoFn's in this
  # workflow rely on global context (e.g., a module imported at module level).
  pipeline_options = PipelineOptions(argv)
  pipeline_options.view_as(SetupOptions).save_main_session = save_main_session
  with beam.Pipeline(options=pipeline_options) as p:
    # Read documents specified by the uris command line option.
    pcoll = bigquery_io.read_rss_items(p)
    # Compute TF-IDF information for each word.
    word_to_uri_and_tfidf = pcoll | tfidf.TfIdf()
    # Write the output using a "Write" transform that has side effects.
    bq_schema_data = (
        word_to_uri_and_tfidf |
        schema_transform.TransformWordUriTfidfToBqSchema())
    bigquery_io.write_word_uri_tfidf(bq_schema_data)
    # Execute the pipeline and wait until it is completed.


if __name__ == '__main__':
  run()