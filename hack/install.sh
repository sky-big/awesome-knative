#!/usr/bin/env bash

export PROJECT_DIR=$(cd `dirname $0`; cd ../; pwd)

# serving
kubectl apply -f ${PROJECT_DIR}/deployment/serving/serving.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/monitoring.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/monitoring-logs-elasticsearch.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/monitoring-metrics-prometheus.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/monitoring-tracing-jaeger.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/monitoring-tracing-jaeger-in-mem.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/monitoring-tracing-zipkin.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/monitoring-tracing-zipkin-in-mem.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/serving/serving-cert-manager.yaml

# eventing
kubectl apply -f ${PROJECT_DIR}/deployment/eventing/eventing.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/eventing/in-memory-channel.yaml
kubectl apply -f ${PROJECT_DIR}/deployment/eventing/release.yaml
