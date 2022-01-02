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

# DNS record prefix (subdomain)
readonly challenge_record_name='_acme-challenge';

# Path of the directory that contains this script
readonly rootdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -P )";

# Directory path to store the identifiers of the DNS records to be cleaned
readonly ovh_record_ids_dir="$rootdir/.record_ids";