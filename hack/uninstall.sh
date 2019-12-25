#!/usr/bin/env bash

export PROJECT_DIR=$(cd `dirname $0`; cd ../; pwd)

# serving
kubectl delete -f ${PROJECT_DIR}/deployment/serving/serving-cert-manager.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/monitoring.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/serving.yaml

# eventing
kubectl delete -f ${PROJECT_DIR}/deployment/eventing/release.yaml
