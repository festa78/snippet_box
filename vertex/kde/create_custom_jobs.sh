#!/bin/bash
set -xe

gcloud auth print-access-token | docker login -u oauth2accesstoken \
  --password-stdin https://gcr.io

gcloud ai custom-jobs create \
  --region=asia-northeast1 \
  --display-name=test \
  --worker-pool-spec=machine-type=e2-standard-4,replica-count=1,executor-image-uri=asia-docker.pkg.dev/vertex-ai/training/scikit-learn-cpu.0-23:latest,requirements=google-cloud-firestore,local-package-path=./,script=./task.py
