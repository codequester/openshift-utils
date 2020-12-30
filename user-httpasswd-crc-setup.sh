#!/bin/bash

#Ref: https://developers.redhat.com/blog/2020/07/03/automate-workshop-setup-with-ansible-playbooks-and-codeready-workspaces/

TMPHTPASS=$(mktemp)

htpasswd -b ${TMPHTPASS} opentlc-mgr 'r3dh4t1!'
htpasswd -b ${TMPHTPASS} shankar 'redhat'
htpasswd -b ${TMPHTPASS} sal 'redhat'
htpasswd -b ${TMPHTPASS} dani 'redhat'
htpasswd -b ${TMPHTPASS} adrian 'redhat'
htpasswd -b ${TMPHTPASS} justin 'redhat'

oc -n openshift-config delete secret htpasswd-secret

oc -n openshift-config create secret generic htpasswd-secret --from-file=htpasswd=${TMPHTPASS}

#After this edit the OAuth CR - To refer to the secret create above instead of the default one
#  oc edit oauth cluster -n openshift-config

#The above will cause the oauth operator to get updates
sleep 60s

oc adm policy add-cluster-role-to-user cluster-admin shankar
oc adm policy add-cluster-role-to-user cluster-admin sal
oc adm policy add-cluster-role-to-user cluster-admin dani
oc adm policy add-cluster-role-to-user cluster-admin adrian
oc adm policy add-cluster-role-to-user cluster-admin justin

