#!/bin/bash

source utils.sh
source operator-funcs.sh
source kafka-funcs.sh

if isLoggedIn ; then
    printInfo "Creating Logging Infra . . ."
    installElasticSearchOperator
    installClusterLoggingOperator
    installAMQStreamsOperator
    installKafkaCluster
    installClusterLogForwarderApi
    tput bold
    printInfo "Wait for the Logging Infra pods to be Running to proceed further"
    tput sgr0
fi