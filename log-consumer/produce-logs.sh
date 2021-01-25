#!/bin/bash
./bin/kafka-console-producer.sh \
 --bootstrap-server amq-cluster-kafka-tls-bootstrap-kafka.apps.cluster-6a14.6a14.example.opentlc.com:443 \
 --topic infra-logs-topic \
 --producer.config client-ssl.properties
