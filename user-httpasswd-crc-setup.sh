#!/bin/bash
TMPHTPASS=$(mktemp)

htpasswd -b ${TMPHTPASS} opentlc-mgr 'r3dh4t1!'
htpasswd -b ${TMPHTPASS} shankar 'redhat'
htpasswd -b ${TMPHTPASS} sal 'redhat'
htpasswd -b ${TMPHTPASS} dani 'redhat'
htpasswd -b ${TMPHTPASS} adrian 'redhat'
htpasswd -b ${TMPHTPASS} justin 'redhat'

oc -n openshift-config delete secret htpass-secret

oc -n openshift-config create secret generic htpass-secret --from-file=htpasswd=${TMPHTPASS}
