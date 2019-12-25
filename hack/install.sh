#!/usr/bin/env bash

export PROJECT_DIR=$(cd `dirname $0`; cd ../; pwd)

# serving
kubectl apply -f ${PROJECT_DIR}/deployment/serving/serving.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/monitoring.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/serving-cert-manager.yaml

# eventing
kubectl apply -f ${PROJECT_DIR}/deployment/eventing/release.yaml
