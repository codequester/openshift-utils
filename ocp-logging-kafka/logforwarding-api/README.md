# Openshift Commands to setup Log-Fowarding
These commands can only be run after cluster-logging and Amq Streams have been installed.

## Steps
1. Extract the Kafka certificate for tls communication. Create 2 secrets in the openshift-logging project, one for the infra topic and a second one for the audit topic. You cannot use the same secret for both topics.
```
$ oc extract secret/amq-cluster-cluster-ca-cert --keys=ca.crt --to=- > ca.crt -n kafka

$ oc create secret generic infra --from-file=ca-bundle.crt=ca.crt -n openshift-logging

$ oc create secret generic audit --from-file=ca-bundle.crt=ca.crt -n openshift-logging
```

2. Run the log-forwarder-kafka template in the openshift-logging project space
```
$ oc process -f log-forwarder-kafka-template.yaml | oc create -f - -n openshift-logging
```
