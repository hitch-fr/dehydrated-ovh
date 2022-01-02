#!/usr/bin/env bash

# dehydrated-ovh by hitch.fr
# Version : 0.1
# website: https://hitch.fr
#
# This script is licensed under The GNU AFFERO GENERAL PUBLIC LICENSE.

# Bash failsafe
set -f # disable globbing
set -e # exit on script fail
set -E # ERR trap not fire in certain scenarios with -e only
set -u # exit on var error
set -x # print commands before exec (debug)
set -o pipefail

# OVH api version to use. Currently only 1.0 is available
readonly ovh_api_version='1.0';

# DNS challenge record prefix (subdomain)
readonly challenge_record_name='_acme-challenge';

# Path of the directory that contains this script
readonly rootdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )";

# Directory path to store the identifiers of the DNS records to be cleaned
readonly ovh_record_ids_dir="$rootdir/.record_ids";

# Loading utility functions
source "$rootdir/utils.sh";

# Check the credentials file existence
if [[ ! -z ${OVH_HOOK_CREDENTIALS+x} ]]
then
  if ! is_file $OVH_HOOK_CREDENTIALS
  then
    echo "ERROR: OVH credentials file not found. Please create the file $OVH_HOOK_CREDENTIALS";
    exit 1;
  fi
else
  local_ovh_credentials="$rootdir/ovh-credentials";
  if ! is_file $local_ovh_credentials
  then
    echo "ERROR: OVH credentials file not found. Please create the file $local_ovh_credentials";
    exit 1;
  else
    OVH_HOOK_CREDENTIALS="$local_ovh_credentials";
  fi
fi

# Store the list of expected keys
# in the OVH credentials file
ovh_expected_keys=(
  'dns_ovh_endpoint'
  'dns_ovh_application_key'
  'dns_ovh_application_secret'
  'dns_ovh_consumer_key'
);

# Store the amount of expected keys
# in the OVH credentials file
ovh_expected_keys_len=${#ovh_expected_keys[@]};

# Store the content of the
# OVH credentials file
lines=$( cat $OVH_HOOK_CREDENTIALS );

# Loop through the credentials file and
# create variables from expected keys
while IFS= read -r line
do
  line=$( echo "${line}" | sed 's/[[:space:]]//g' );

  if [[ $line == "" ]] || [ ${line::1} == "#" ]
  then
    continue;
  fi

  for (( i=0; i<$ovh_expected_keys_len; i++ ));
  do
    expected_key=${ovh_expected_keys[ $i ]};

    if [[ "${line}" == "$expected_key=" ]]
    then
      echo "WARNING: Empty value found in the credentials file; KEY: $expected_key";
      break;
    fi

    if [[ $line == "$expected_key="* ]]
    then
      parts=($(explode "=" "${line}"));
      key="$( echo ${parts[0]} | tr '[:upper:]' '[:lower:]' )";
      value="${parts[1]}";

      readonly "${key}"="$value";
      
      if [[ "${value}" == *"OVH_"* ]]
      then
        echo "WARNING: $expected_key is probably wrong you have to replace it with your own key";
      fi
    fi

  done

done <<< "$lines"

# Clear variables that are
# no longer needed
unset -v lines;
unset -v ovh_expected_keys;
unset -v ovh_expected_keys_len;