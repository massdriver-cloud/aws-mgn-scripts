#!/bin/bash

#############################################################
#                                                           #
# This script is for setting local environment variables    #
# for importing infrastructure into Massdriver.             #
# https://docs.massdriver.cloud/guides/managing-state       #
#                                                           #
#############################################################

export TF_HTTP_USERNAME=${MASSDRIVER_ORG_ID}
export TF_HTTP_PASSWORD=${MASSDRIVER_API_KEY}
export MASSDRIVER_PACKAGE_ID="package-id-here"
export MASSDRIVER_PACKAGE_STEP_NAME="step-name-here"
export TF_HTTP_ADDRESS="https://api.massdriver.cloud/state/${MASSDRIVER_PACKAGE_ID}/${MASSDRIVER_PACKAGE_STEP_NAME}"
export TF_HTTP_LOCK_ADDRESS=${TF_HTTP_ADDRESS}
export TF_HTTP_UNLOCK_ADDRESS=${TF_HTTP_ADDRESS}
