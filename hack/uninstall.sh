#!/usr/bin/env bash

export PROJECT_DIR=$(cd `dirname $0`; cd ../; pwd)

# serving
kubectl delete -f ${PROJECT_DIR}/deployment/serving/monitoring.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/monitoring-logs-elasticsearch.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/monitoring-metrics-prometheus.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/monitoring-tracing-jaeger.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/monitoring-tracing-jaeger-in-mem.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/monitoring-tracing-zipkin.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/monitoring-tracing-zipkin-in-mem.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/serving-cert-manager.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/serving/serving.yaml

# eventing
kubectl delete -f ${PROJECT_DIR}/deployment/eventing/in-memory-channel.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/eventing/release.yaml
kubectl delete -f ${PROJECT_DIR}/deployment/eventing/eventing.yaml
