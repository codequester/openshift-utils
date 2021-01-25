#!/bin/bash

 source utils.sh
 source kafka-funcs.sh

 isUserWorkloadMonitoringEnabled() {
    printInfo "-- Checking if user workload monitoring is enabled in cluster-monitoring-config . . ."
    oc get configmap cluster-monitoring-config -n openshift-monitoring -o yaml | grep "enableUserWorkload: true"  >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printWarn "-- User Workload Monitoring Not enabled! - Enabling it"
        oc apply -f ../monitor/cluster-monitoring-config.yaml >/dev/null 2>&1
    fi
    printInfo "-- User workload monitoring is enabled in cluster-monitoring-config!"
}

installMonitoringConfig() {
    printInfo "-- Configuring Cluster Monitoring Config for Log Monitoring . . ."
    oc apply -f ../monitor/cluster-monitoring-config.yaml >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "-- Error occured while configuring Cluster Monitoring Config for Log Monitoring!"
    fi
    printInfo "-- Cluster Monitoring Config for Log Monitoring configured Successfully!"
}

installUserWorkloadMonitoringConfig() {
    printInfo "-- Configuring User Workload Monitoring Config . . ."
    oc apply -f ../monitor/user-workload-monitoring-config.yaml >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "-- Error occured while configuring User Workload Monitoring!"
    fi
    printInfo "-- User Workload Monitoring Config configured Successfully!"
}

installPodMonitors() {
    printInfo "-- Installing Pod Montitors for Monitoring Logging Infra . . ."
    #Apply metric config before starting the pod monitors
    oc apply -f ./logging-infra/kafka-cluster-metrics.yaml -n ${KAFKA_CLUSTER_NAMESPACE} >/dev/null
    oc process -f ./metrics-infra/strimzi-pod-monitor.yaml -p KAFKA_CLUSTER_NAMESPACE=${KAFKA_CLUSTER_NAMESPACE} | oc apply -f - -n ${KAFKA_CLUSTER_NAMESPACE}>/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "-- Error occured while Installing Pod Monitors!"
    fi
    printInfo "-- Pod Monitors for Monitoring Logging Infra Installed Successfully!"    
}

installPrometheusAlerts() {
    printInfo "-- Installing Prometheus Alert Rultes for Logging Infra . ."    
    oc apply -f ./alerting-infra/prometheus-rules.yaml -n ${KAFKA_CLUSTER_NAMESPACE} >/dev/null 2>&1
    printInfo "-- Prometheus Alert Rules Install Successfully!"
}

configureAlertReceivers() {
    printInfo "-- Configuring Alert Receivers  . ." 
    oc -n openshift-monitoring create secret generic alertmanager-main --from-file=./alerting-infra/alertmanager.yaml --dry-run -o=yaml |  oc -n openshift-monitoring replace secret --filename=- >/dev/null 2>&1
    printInfo "-- Alert Receivers Configured Successfully!"    
}

installGrafana() {
    printInfo "-- Installing Service Account For Grafana . . ."
    oc process -f ./metrics-infra/grafana-sa.yaml -p KAFKA_CLUSTER_NAMESPACE=${KAFKA_CLUSTER_NAMESPACE} | oc apply -f - -n ${KAFKA_CLUSTER_NAMESPACE} >/dev/null 2>&1
    printInfo "-- Deploying Grafana . . ."
    SA_TOKEN="$(oc serviceaccounts get-token grafana-serviceaccount  -n ${KAFKA_CLUSTER_NAMESPACE})"  
    oc process -f ./metrics-infra/grafana.yaml -p SA_TOKEN=${SA_TOKEN} | oc apply -f -  -n ${KAFKA_CLUSTER_NAMESPACE} > /dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "-- Error occured while Deploying Grafana!"
    fi
    printInfo "-- Grafana Installed Successfully!"       
}

configureAlerts() {
    installPrometheusAlerts
    configureAlertReceivers
}

configureMonitoringInfra() {
    printInfo "Checking for Cluster Monitoring Config - [cluster-monitoring-config] . . ."
    oc get configmap cluster-monitoring-config -n openshift-monitoring >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        promptYesNo "Cluster Monitoring Config not Configure for Log Monitoring. Do you want to Configure ?"
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            installMonitoringConfig
        else
            printError "-- Configuring Cluster Monitoring Config for Log Monitoring is Required for the Logging Infra!"
            exit 0
        fi
    else
        printWarn "-- Cluster Monitoring Config is already installed in openshift-Monitoring Namespace!"
        isUserWorkloadMonitoringEnabled
    fi    
    installUserWorkloadMonitoringConfig
    installPodMonitors
    installGrafana
    printWarn "-- Kafka Cluster is being Restarted after Applying metrics config!"
    waitForRunningKafkaCluster
    configureAlerts
}