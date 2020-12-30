#!/bin/bash

source utils.sh

KAFKA_CLUSTER_NAMESPACE=kafka

createNameSpaceForKafkaCluster() {
    oc project ${KAFKA_CLUSTER_NAMESPACE} >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "-- Namespace [${KAFKA_CLUSTER_NAMESPACE}] - Does not exist. Creating it . . . "
        oc new-project ${KAFKA_CLUSTER_NAMESPACE} --display-name="Kafka(AMQStreams)" >/dev/null 2>&1
        OUT=$?
        if [ ${OUT} -ne 0 ]; then
            printError "-- Error while creating the Namespace - ${KAFKA_CLUSTER_NAMESPACE}"
            exit 1
        fi
        printInfo "-- Namespace - ${KAFKA_CLUSTER_NAMESPACE}, Created Successfully!"
    else
        printWarn "-- Namespace - ${KAFKA_CLUSTER_NAMESPACE} already exists!"
    fi
    resetContext    
}

installKafkaCluster() {
    printInfo "Checking if Kafka Cluster is Installed . . ."
    createNameSpaceForKafkaCluster
    oc get kafka amq-cluster -n ${KAFKA_CLUSTER_NAMESPACE} >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printInfo "-- Creating Kafaka Cluster in Namespace - ${KAFKA_CLUSTER_NAMESPACE}"
        oc apply -f ./logging-infra/kafka-cluster.yaml -n ${KAFKA_CLUSTER_NAMESPACE} >/dev/null
        OUT=$?
        if [ ${OUT} -ne 0 ]; then
            printError "-- Error occured while installing the Kafka Cluster"
            exit 1
        fi
        printInfo "-- Kafka Cluster Installed successfully!"
    else
        printWarn "-- Kafka Cluster is already Installed!"
    fi
    createTopics
}

createTopics() {
    printInfo "-- Creating Topics for Logging . . ."
    if [ $(oc get kafkatopics -lgid=logs -o custom-columns=NAME:.metadata.name -n ${KAFKA_CLUSTER_NAMESPACE} | wc -l) -lt 4 ]; then
        oc apply -f ./logging-infra/kafka-topics.yaml -n ${KAFKA_CLUSTER_NAMESPACE} >/dev/null
        OUT=$?
        if [ ${OUT} -ne 0 ]; then
            printError "-- Error occured while Creating Topics for Logging"
            exit 1
        fi
        printInfo "-- Topics for Logging Created successfully!"  
    else
        printWarn "-- Topics for Logging already Exists!"
    fi  
}