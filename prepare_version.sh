#!/bin/bash -x

# Export variables
export ARTEFACT=`file gs-spring-boot* | cut -d':' -f1`
export VERSION=`echo "${ARTEFACT%%.jar*}" | cut -d'-' -f4`

# Prepare artefact version
echo "VERSION=$VERSION" > variables.properties
cp variables.properties /tmp
