#!/bin/bash
set -ex

export GOOGLE_APPLICATION_CREDENTIALS="../../flutter-myapp-test.json"

python trends/main.py --runner DirectRunner --project flutter-myapp-test --region asia-northeast1 --temp_location gs://flutter-myapp-test.appspot.com/beam/temp
