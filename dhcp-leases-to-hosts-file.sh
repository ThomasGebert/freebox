#!/bin/bash

COMMANDS="get_dhcp_dynamic_lease_names get_dhcp_static_lease_names"
AUTH_FILE="${HOME}/.config/freebox"

for COMMAND in ${COMMANDS}; do
  ./freebox-cli.sh --auth-file "${AUTH_FILE}" -c "${COMMAND}" | jq -r '.result[] | "\(.ip)\t\(.hostname)"'
done
