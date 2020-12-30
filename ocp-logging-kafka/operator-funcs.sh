#!/bin/bash

source utils.sh

createNameSpaceForElasticSearchOperator() {
    oc projects | grep "openshift-operators-redhat" >/dev/null 2>&1
    OUT=$?
    if [[ ${OUT} -ne 0 ]]; then
        printError "-- Namespace [openshift-operators-redhat] - Does not exist. Creating it . . . "
        oc apply -f ./logging-infra/elasticsearch-operator-namespace.yaml >/dev/null 2>&1
        OUT=$?
        if [ ${OUT} -ne 0 ]; then
            printError "-- Error while creating the Namespace - openshift-operators-redhat"
            exit 1
        fi
        printInfo "-- Namespace - openshift-operators-redhat, Created Successfully !"
    fi
}

createNameSpaceForClusterLoggingOperator() {
    oc projects | grep "openshift-logging" >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "-- Namespace [openshift-logging] - Does not exist. Creating it . . . "
        oc apply -f ./logging-infra/clusterlogging-operator-namespace.yaml >/dev/null 2>&1
        OUT=$?
        if [ ${OUT} -ne 0 ]; then
            printError "-- Error while creating the Namespace - openshift-logging"
            exit 1
        fi
        printInfo "-- Namespace - openshift-logging, Created Successfully !"
    fi 
}



installElasticSearchOperator() {
    printInfo "Checking if Elasticsearch Operator is Installed . . ."
    oc get sub elasticsearch-operator -n openshift-operators-redhat >/dev/null 2>&1 
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        promptYesNo "Elasticsearch Operator is Not Installed. Do you want to Install it ?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            createNameSpaceForElasticSearchOperator
            printInfo "-- Installing Elasticsearch Operator in openshift-operators-redhat Namespace . . ."
            oc apply -f ./logging-infra/elasticsearch-operator-group.yaml -f ./logging-infra/elasticsearch-operator-sub.yaml >/dev/null
            OUT=$?
            if [ ${OUT} -ne 0 ]; then
                printError "-- Error occured while installing the Operator"
                exit 1
            fi
            printInfo "-- Elasticsearch Operator Installed Successfully!"
        else
            printError " -- Cannot proceed without installing Elasticsearch Operator."
            exit 0
        fi
    else
        printWarn "-- Elasticsearch Operator is already Installed!"
    fi
}

installClusterLoggingOperator() {
    printInfo "Checking if Cluster Logging Operator is Installed . . ."
    oc get sub cluster-logging -n openshift-logging >/dev/null 2>&1 
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        promptYesNo "Cluster Logging Operator is Not Installed. Do you want to Install it ?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            createNameSpaceForClusterLoggingOperator
            printInfo "-- Installing Cluster Logging Operator in openshift-logging Namespace . . ."
            oc apply -f ./logging-infra/openshift-logging-operatorgroup.yaml -f ./logging-infra/clusterlogging-operator-sub.yaml >/dev/null
            OUT=$?
            if [ ${OUT} -ne 0 ]; then
                printError "-- Error occured while installing the Operator"
                exit 1
            fi
            printInfo "-- Cluster Logging Operator Installed Successfully!"        
        else
            printError " -- Cannot proceed without installing Cluster Logging Operator."
            exit 0
        fi
    else
        printWarn "-- Cluster Logging Operator is alredy Installed!"
    fi
}

installAMQStreamsOperator() {
    printInfo "Checking if AMQStreams Operator is Installed . . ."
    oc get sub amq-streams -n openshift-operators >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        promptYesNo "AMQStreams is Not Installed. Do you want to Install it ?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            printInfo "-- Installing AMQStreams Operator in openshift-operators Namespace . . ."
            oc apply -f ./logging-infra/amqstreams-operator-sub.yaml >/dev/null
            OUT=$?
            if [ ${OUT} -ne 0 ]; then
                printError "-- Error occured while installing the Operator"
                exit 1
            fi
            printInfo "-- AMQStreams Operator Installed Successfully!"         
        else
            printError "-- Cannot proceed without installing AMQStreams Operator."
            exit 0
        fi
    else
        printWarn "-- AMQStreams Operator is already Installed!"
    fi
}

extractKafkaCertsAsSecrets() {
    oc extract secret/amq-cluster-cluster-ca-cert --keys=ca.crt --to=. -n ${KAFKA_CLUSTER_NAMESPACE} > /dev/null
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "-- Error while extracting the Kafka Certs"
    fi
}

installClusterLogForwarderApi() {
    printInfo "Checking if Log Forwarder API to Kafka is Installed . . ."
    oc get clusterlogforwarder instance -n openshift-logging >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        promptYesNo "Log Forwarder API to Kafka is Not Installed. Do you want to Install it ?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            printInfo "-- Creating Certs as Secrets for Log Forwarder API to Kafka in openshift-logging Namespace . . ."
            sleep 10
            extractKafkaCertsAsSecrets
            oc create secret generic infra --from-file=ca-bundle.crt=ca.crt -n openshift-logging > /dev/null 
            oc create secret generic audit --from-file=ca-bundle.crt=ca.crt -n openshift-logging > /dev/null
            oc process -f ./logforwarding-api/log-forwarder-kafka-template.yaml | oc create -f - -n openshift-logging >/dev/null
            printInfo "-- Log Forwarder API to kafka Installed Successfully!"
        else
            printError "-- Log Forwarder API to kafka in Required for the Logging Infra!"
            exit 0
        fi
    else
        printWarn "-- Log Forwarder API to Kafka is already installed in openshift-logging Namespace!"
    fi
}