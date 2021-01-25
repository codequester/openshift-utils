#!/bin/bash


HELP="
How to use this script:
-i  --interactive   | Setup logging using interactive mode
-y  --yestoall      | Setup logging using install all mode
-h  --help          | Show help menu
"


greenTxt=`tput setaf 2`
yellowTxt=`tput setaf 3`
redTxt=`tput setaf 1`
cyanTxt=`tput setaf 6`
resetTxtColor=`tput sgr0`
bold=`tput bold`



printInfo() {
    echo "${greenTxt}[INFO]: ${1} ${resetTxtColor}"
}

printWarn() {
    echo "${yellowTxt}[WARN]: ${1} ${resetTxtColor}"
}

printError() {
    echo "${redTxt}[ERROR]: ${1} ${resetTxtColor}"
}

promptYesNo() { 
    if [[ $INTERACTIVE_MODE == "true" ]]; then
        while true; do
            read -p "${bold}${cyanTxt} --> ${1} - (Y/N) : ${resetTxtColor}" 
            if [[ $REPLY =~ ^[Yy|Nn]$ ]]; then
                break
            fi
        done
    else
        echo "${bold}${cyanTxt} --> ${1} - (Y/N) : ${resetTxtColor} Y"
        REPLY=y
    fi
}

isLoggedIn() {
    printInfo "Checking for Active OC Session . . ."
    oc whoami -t >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "No Active OC Session. Log in to Cluser: oc login --server=<server-url>"
        exit 1
    else
        OC_TOKEN=$(oc whoami -t)
        OC_CONTEXT=$(oc whoami -c)
        OCP_API_URI=$(oc whoami --show-server)
        ORIG_OC_CONTEXT=${OC_CONTEXT}
        printInfo "Active OC Session found. Your current context is: ${OC_CONTEXT}"
        return 0
    fi
}

resetContext() {
    oc config use-context ${ORIG_OC_CONTEXT} >/dev/null 2>&1
    OUT=$?
    if [ ${OUT} -ne 0 ]; then
        printError "Error while Resetting to Original Context"
        exit 1
    fi
}