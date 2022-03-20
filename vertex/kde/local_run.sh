#!/bin/bash
set -xe

KEY_FILE="$(pwd)/../../flutter-myapp-test-559e258b7bd5.json"
IMAGE_URI="asia.gcr.io/flutter-myapp-test/kde-for-trend-scores:0.0.2"

gcloud ai custom-jobs local-run \
  --executor-image-uri=asia-docker.pkg.dev/vertex-ai/training/scikit-learn-cpu.0-23:latest \
  --local-package-path=./ \
  --script=./task.py \
  --requirements=google-cloud-firestore \
  --output-image-uri="${IMAGE_URI}" \
  --service-account-key-file="${KEY_FILE}"
