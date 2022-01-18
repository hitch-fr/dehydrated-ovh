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
# set -x # print commands before exec (debug)
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

# Check if dns_ovh_endpoint has been
# found or fallback to default
if [[ -z ${dns_ovh_endpoint+x} ]]
then
  readonly dns_ovh_endpoint="$ovh_default_endpoint";
  echo "WARNING: The ovh endpoint was not found, the default endpoint $ovh_default_endpoint will be used";
fi

# Stop the script if dns_ovh_application_key
# was not found in OVH credentials file
if [[ -z ${dns_ovh_application_key+x} ]]
then
  echo "ERROR: The dns_ovh_application_key key is required";
  exit 1;
fi

# Stop the script if dns_ovh_application_secret
# was not found in OVH credentials file
if [[ -z ${dns_ovh_application_secret+x} ]]
then
  echo "ERROR: The dns_ovh_application_secret key is required";
  exit 1;
fi

# Stop the script if dns_ovh_consumer_key
# was not found in OVH credentials file
if [[ -z ${dns_ovh_consumer_key+x} ]]
then
  echo "ERROR: The dns_ovh_consumer_key key is required";
  exit 1;
fi

# Return the api url corresponding to
# the dns_ovh_endpoint variable
function api_url(){

  declare -A ENDPOINTS;
  ENDPOINTS['ovh-eu']="https://eu.api.ovh.com/$ovh_api_version";
  ENDPOINTS['ovh-ca']="https://ca.api.ovh.com/$ovh_api_version";
  ENDPOINTS['ovh-us']="https://api.us.ovhcloud.com/$ovh_api_version";
  ENDPOINTS['kimsufi-eu']="https://eu.api.kimsufi.com/$ovh_api_version";
  ENDPOINTS['kimsufi-ca']="https://ca.api.kimsufi.com/$ovh_api_version";
  ENDPOINTS['soyoustart-eu']="https://eu.api.soyoustart.com/$ovh_api_version";
  ENDPOINTS['soyoustart-ca']="https://ca.api.soyoustart.com/$ovh_api_version";
  ENDPOINTS['runabove-ca']="https://api.runabove.com/$ovh_api_version";

  echo "${ENDPOINTS[$dns_ovh_endpoint]}";
}

# Return OVH dns zone name of the
# given ${1} subdomain or domain
function dns_zone(){
  local DOMAIN="${1}";

  local parts=($(explode "." "${DOMAIN}"));
  echo "${parts[-2]}.${parts[-1]}";
}

# Return challenge record string as it should be in the
# ovh dns zone of the given ${1} subdomain or domain
function challenge_record(){
  local DOMAIN="${1}";

  local parts=($(explode "." "${DOMAIN}"))
  unset parts[-1];
  unset parts[-1];

  local record="";
  for part in ${parts[*]}
  do
    record+="$part."
  done

  if [[ ! -z ${challenge_record_name+x} ]]
  then
    record="$challenge_record_name.$record";
  fi

  # removing the trailing point
  record=${record::-1};
  echo $record;
}

# Wait till the given ${2} token is found
# in the given domain ${1} TXT records
function check_dns_propagation() {
  local DOMAIN="${1}" TOKEN="${2}";

  local dns_zone=$( dns_zone $DOMAIN );
  local record_name=$( challenge_record $DOMAIN );

  while [[ true ]]
  do
    sleep 5;
    local SOA=$( dig +short SOA $dns_zone| cut -d' ' -f1);
    local tokens=$( nslookup -type=TXT "$record_name.$dns_zone" $SOA );

    while IFS= read -r line
    do
      DEPLOYED_TOKEN=$( echo $line | cut -d ' ' -f4 | tr -d '"' );
      if [[ "$TOKEN" == "$DEPLOYED_TOKEN" ]]
      then
        return 0;
      fi
    done <<< "$tokens"

    echo " + The challenge token is not yet deployed, retrying in 5 secs";
  done
}

# Send the given ${2} request of the given ${1} method
# with an optionally given ${3} json to the OVH api
function send(){
  local method="${1}" query="${2}";

  if [[ -z ${3+x} ]]
  then
      local json='{}\n';
      body=$( printf "$json" );
  else
      body="${3}"
  fi

  local endpoint=$( api_url );

  query="$endpoint/$query";

  local auth_time=$(curl -s $endpoint/auth/time);
  local signature=$dns_ovh_application_secret"+"$dns_ovh_consumer_key"+"$method"+"$query"+"$body"+"$auth_time;
  signature='$1$'$(echo -n $signature | openssl dgst -sha1 -hex | cut -f 2 -d ' ' );

  # curl --connect-timeout 2.37 https://example.com/
  curl --silent --request $method $query \
        --header "Content-Type: application/json" \
        --header "X-Ovh-Application: $dns_ovh_application_key" \
        --header "X-Ovh-Timestamp: $auth_time" \
        --header "X-Ovh-Signature: $signature" \
        --header "X-Ovh-Consumer: $dns_ovh_consumer_key" \
        --data "$body";
}

# Delete the record of the given ${2} ID in the OVH
# dns zone corresponding to the given ${1} domain
function delete_record() {
  local DOMAIN="${1}" ID="${2}"

  local dns_zone=$( dns_zone $DOMAIN );

  # SEND REQUEST
  local query="domain/zone/$dns_zone/record/$ID";
  send "DELETE" $query &> /dev/null;

  # REFRESH ZONE
  query="domain/zone/$dns_zone/refresh";
  send "POST" $query &> /dev/null;
}

# Create a challenge record with the value of the given ${3} token
# in the OVH dns zone corresponding to the given ${1} domain
function deploy_challenge() {
  local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

  local dns_zone=$( dns_zone $DOMAIN );
  local dns_record=$( challenge_record $DOMAIN );

  local query="domain/zone/$dns_zone/record";
  local field_type="TXT";
  local record_value=$TOKEN_VALUE;

  local json='{"fieldType":"%s","subDomain":"%s","target":"%s"}\n';
  local body=$( printf "$json" "$field_type" "$dns_record" "$record_value");

  # SEND REQUEST
  local response=$( send "POST" $query $body );
  local id=$( echo $response | grep -zoP '"id":\s*\K[^\s,]*(?=\s*[,}])' | tr -d "\0" );

  if [[ $id == "" ]]
  then
    echo " + ERROR: Bad http response. your credentials may be wrong.";
    echo " + $response";
    return 1;
  fi

  # STORE RESPONSE ID IN FILE
  echo $id >> "$ovh_record_ids_dir/$DOMAIN.ids";

  mkdir -p $ovh_record_ids_dir;

  # REFRESH ZONE
  query="domain/zone/$dns_zone/refresh";
  send "POST" $query &>/dev/null;

  # CHECK RECORD
  check_dns_propagation $DOMAIN $TOKEN_VALUE;
  return 0;
}

# Clean all challenges record for the given ${1} domain
# with the ids previously registered in the ids file
function clean_challenge() {
  local DOMAIN="${1}" TOKEN_FILENAME="${2}" TOKEN_VALUE="${3}"

  if [[ -f "$ovh_record_ids_dir/$DOMAIN.ids" ]]
  then
    local ids=$( cat "$ovh_record_ids_dir/$DOMAIN.ids" );

    while IFS= read -r id
    do
      if [[ $id =~ [0-9] ]]
      then
        delete_record $DOMAIN $id;
        sed -i "/$id/d" "$ovh_record_ids_dir/$DOMAIN.ids";
      fi
    done <<< "$ids"

    sed -i '/^[[:space:]]*$/d' "$ovh_record_ids_dir/$DOMAIN.ids";
    if [[ ! -s "$ovh_record_ids_dir/$DOMAIN.ids" ]]
    then
      rm -f "$ovh_record_ids_dir/$DOMAIN.ids";
    fi
  fi
  return 0;
}

# Return the CA response
function invalid_challenge() {
  local DOMAIN="${1}" RESPONSE="${2}";
  echo "$RESPONSE";
}

# Call the given ${1} hook
# if it is available
HANDLER="$1"; shift
if [[ "${HANDLER}" =~ ^(deploy_challenge|clean_challenge|invalid_challenge)$ ]]; then
  "$HANDLER" "$@"
fi