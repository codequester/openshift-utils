#!/bin/bash

source utils.sh

createNameSpaceForElasticSearchOperator() {
    oc projects | grep "${ES_OPERATOR_NAMESPACE}" >/dev/null 2>&1
    OUT=$?
    if [[ ${OUT} -ne 0 ]]; then
        printError "-- Namespace [${ES_OPERATOR_NAMESPACE}] - Does not exist. Creating it . . . "
        #oc apply -f ./logging-infra/elasticsearch-operator-namespace.yaml >/dev/null 2>&1
        oc create namespace ${ES_OPERATOR_NAMESPACE} >/dev/null 2>&1
        OUT=$?
        if [ ${OUT} -ne 0 ]; then
            printError "-- Error while creating the Namespace - ${ES_OPERATOR_NAMESPACE}"
            exit 1
        fi
        oc label namespace ${ES_OPERATOR_NAMESPACE} openshift.io/cluster-monitoring=true >/dev/null 2>&1
        printInfo "-- Namespace - ${ES_OPERATOR_NAMESPACE}, Created Successfully !"
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
    oc get sub elasticsearch-operator -n ${ES_OPERATOR_NAMESPACE} >/dev/null 2>&1 
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        promptYesNo "Elasticsearch Operator is Not Installed. Do you want to Install it ?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            createNameSpaceForElasticSearchOperator
            printInfo "-- Installing Elasticsearch Operator in ${ES_OPERATOR_NAMESPACE} Namespace . . ."
            oc apply -f ./logging-infra/elasticsearch-operator-group.yaml -f ./logging-infra/elasticsearch-operator-sub.yaml >/dev/null 2>&1
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

waitForRunningOperatorPods() {
    # Make sure that The AMQStreams Operator POD is fully up and running before proceeding!
    AMQ_CLUSTER_OP_NAME=$(oc get deployments --no-headers -o custom-columns=DEPLOYMENT:.metadata.name -n ${AMQ_OPERATOR_NAMESPACE} | grep 'amq-streams-cluster-operator')
    printInfo "-- Checking if ${AMQ_CLUSTER_OP_NAME} pods are ready!"
    if [ "$AMQ_CLUSTER_OP_NAME" != "" ]; then
        while : ; do
            printInfo "-- Checking if AMQStreams Operator is Ready . . ."
            AVAILABLE_REPLICAS=$(oc get deployment ${AMQ_CLUSTER_OP_NAME} -n ${AMQ_OPERATOR_NAMESPACE} -o=jsonpath='{.status.availableReplicas}')
            if [[ "$AVAILABLE_REPLICAS" == "1" ]]; then
                printInfo "-- AMQStreams Operator is Ready.! ! !"
                break
            fi
            printWarn "-- AMQStreams Operator Not Ready. Please Wait!"
            sleep 5
        done
    fi
}

installAMQStreamsOperator() {
    printInfo "Checking if AMQStreams Operator is Installed . . ."
    oc get sub amq-streams -n ${AMQ_OPERATOR_NAMESPACE} >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        promptYesNo "AMQStreams Operator is Not Installed. Do you want to Install it ?" 
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            printInfo "-- Installing AMQStreams Operator in ${AMQ_OPERATOR_NAMESPACE} Namespace . . ."
            oc apply -f ./logging-infra/amqstreams-operator-sub.yaml -n ${AMQ_OPERATOR_NAMESPACE} >/dev/null
            OUT=$?
            if [ ${OUT} -ne 0 ]; then
                printError "-- Error occured while installing the Operator"
                exit 1
            fi
            sleep 25
            printInfo "-- AMQStreams Operator Installed Successfully!" 
            waitForRunningOperatorPods        
        else
            printError "-- Cannot proceed without installing AMQStreams Operator."
            exit 0
        fi
    else
        printWarn "-- AMQStreams Operator is already Installed!"
    fi
}

extractKafkaCertsAsSecrets() {
    oc extract secret/amq-cluster-cluster-ca-cert --to=. -n ${KAFKA_CLUSTER_NAMESPACE} --confirm > /dev/null
    oc extract secret/amq-cluster-cluster-ca --to=. -n ${KAFKA_CLUSTER_NAMESPACE} --confirm > /dev/null
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "-- Error while extracting the Kafka Certs"
    fi
}

installClusterLogging() {
    oc get ClusterLogging instance -n openshift-logging >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printInfo "-- Cluster Logging in openshift-logging Namespace is not Installed. Installing . . ."
        oc apply -f ./logging-infra/clusterlogging-instance.yaml > /dev/null 
        OUT=$?
        if [ ${OUT} -ne 0 ]; then
            printError "-- Error occured while installing the Cluster Logging Instance "
            exit 1
        fi
        printInfo "-- Cluster Logging Installed Successfully!!"
    fi
}

installClusterLogForwarderApi() {
    printInfo "Checking if Log Forwarder API to Kafka is Installed . . ."
    installClusterLogging
    oc get clusterlogforwarder instance -n openshift-logging >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        promptYesNo "Log Forwarder API to Kafka is Not Installed. Do you want to Install it ?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            printInfo "-- Creating Certs as Secrets for Log Forwarder API to Kafka in openshift-logging Namespace . . ."
            sleep 10
            extractKafkaCertsAsSecrets
            oc create secret generic infra --from-file=ca-bundle.crt=ca.crt --from-file=tls.crt=ca.crt --from-file=tls.key=ca.key -n openshift-logging > /dev/null 
            oc create secret generic audit --from-file=ca-bundle.crt=ca.crt --from-file=tls.crt=ca.crt --from-file=tls.key=ca.key -n openshift-logging > /dev/null
            oc create secret generic app --from-file=ca-bundle.crt=ca.crt --from-file=tls.crt=ca.crt --from-file=tls.key=ca.key -n openshift-logging > /dev/null
            KAFA_BOOTSTRAP_ROUTE="$(oc get route amq-cluster-kafka-tls-bootstrap --no-headers -o custom-columns=ROUTE:.spec.host -n ${KAFKA_CLUSTER_NAMESPACE})"        
            oc process -f ./logforwarding-api/log-forwarder-kafka-template.yaml -p KAFKA_BOOTSTRAP=${KAFA_BOOTSTRAP_ROUTE}  | oc create -f - -n openshift-logging >/dev/null
            printInfo "-- Log Forwarder API to kafka Installed Successfully!"
        else
            printError "-- Log Forwarder API to kafka in Required for the Logging Infra!"
            exit 0
        fi
    else
        printWarn "-- Log Forwarder API to Kafka is already installed in openshift-logging Namespace!"
    fi
}