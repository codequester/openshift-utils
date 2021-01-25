#!/bin/bash

source utils.sh
source operator-funcs.sh
source kafka-funcs.sh
source monitoring-funcs.sh

ARGS=$@
ARGS_COUNT=$#
KAFKA_CLUSTER_NAMESPACE=ocp-kafka
AMQ_OPERATOR_NAMESPACE=openshift-operators
ES_OPERATOR_NAMESPACE=openshift-operators-redhat
INTERACTIVE_MODE=true

if [[ $ARGS_COUNT -eq 0 ]] ; then
    echo -e "$HELP"
    exit 0
fi
for arg in $ARGS
do
    case $arg in
        -i | --interactive)
            INTERACTIVE_MODE=true
            ;;
        -y | --yestoall)
            INTERACTIVE_MODE=false
            ;;
        -h | --help)
            echo -e "$HELP"
            exit 0
            ;;
        *)
            echo "Unknown argument passed: '$arg'"
            echo -e "$HELP"
            exit 1
            ;;
    esac
done
if isLoggedIn ; then
    printInfo "Creating Logging Infra . . ."
    installElasticSearchOperator
    installClusterLoggingOperator
    installAMQStreamsOperator
    installKafkaCluster
    configureMonitoringInfra
    installClusterLogForwarderApi
    tput bold
    printInfo "Wait for the Logging Infra pods to be Running to proceed further"
    tput sgr0
fi