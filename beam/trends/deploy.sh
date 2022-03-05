#!/bin/bash
set -ex

export GOOGLE_APPLICATION_CREDENTIALS="../../flutter-myapp-test.json"

python trends/main.py \
  --runner DataflowRunner \
  --project flutter-myapp-test \
  --region asia-northeast1 \
  --temp_location gs://flutter-myapp-test.appspot.com/beam/temp \
  --template_location gs://flutter-myapp-test.appspot.com/beam/templates/trends \
  --setup_file ./setup.py