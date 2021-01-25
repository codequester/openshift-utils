#!/bin/bash
./bin/kafka-console-consumer.sh \
 --bootstrap-server amq-cluster-kafka-tls-bootstrap-kafka.apps.cluster-6a14.6a14.example.opentlc.com:443 \
 --topic infra-logs-topic \
 --consumer.config client-ssl-consumer.properties
