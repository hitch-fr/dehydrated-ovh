#!/usr/bin/env bash

# dehydrated-ovh by hitch.fr
# website: https://hitch.fr
#
# This script is licensed under The GNU AFFERO GENERAL PUBLIC LICENSE.

# Fail safe
set -f # disable globbing
set -e # exit on script fail
set -E # ERR trap not fire in certain scenarios with -e only
set -u # exit on var error
set -x # print commands before exec (debug)
set -o pipefail