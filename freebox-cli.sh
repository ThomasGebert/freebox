#!/bin/sh

################################################################################
# Global variables
################################################################################
# Freebox variables
FREEBOX_ADDRESS="192.168.1.254"
FREEBOX_API_VERSION="v15"

# Curl configuration
CURL="curl"
CURL_OPTIONS="--insecure --silent"
CURL_TIMEOUT="--max-time 3"
CURL_CMD="${CURL} ${CURL_OPTIONS} ${CURL_TIMEOUT}"

# jq configuration and basic returns
JQ="jq"
JSON_FAILED='{"success":false}'
JSON_SUCCESS='{"success":true}'

# Which tool used for calculating HMAC_MD5
HMAC_MD5="openssl"

# Tool that we need
TOOLS_NEEDED="${CURL} ${JQ} ${HMAC_MD5}"

################################################################################
# Functions
################################################################################

# Our help function
show_help() {
cat << HELP

Freebox API CLI

Usage: $(basename $0) [OPTIONS]

Mandatory options:
A command to execute
  -c|--commands COMMANDS        	The command(s) to execute.
	                                Possible commands are:
					- GET
                                        - PUT
					- POST
					- DELETE
					- get_dhcp_dynamic_lease_names
					- get_dhcp_static_lease_names

					The following commands are more useful for 
					debugging:
					- get_challenge
					- get_password
					- get_session_token
					- set_session_token
                	                - track_app_token

                                	Multiple commands can be comma separated
	                                  track_app_token,auth
  -p|--api-path		API_PATH	API path to GET/PUT/POST/DELETE. Without the /api/v15/ part.
                                        See freebox documentation for details
  -P|--json-content     JSON_CONTENT    JSON to PUT/POST

Autentication can be passed directly via:
  -i|--app-id		APP_ID		App id used during registration
  -a|--app-token	APP_TOKEN	App token to use
Or provide a json file containing these values
  -A|--auth-file	AUTH_FILE	json file containing app_id and app_token

Optional:
  -f|--freebox		FREEBOX_ADDRESS Address of the freebox (Default: ${FREEBOX_ADDRESS})
  -t|--track-id 	TRACK_ID        Track ID to use. Is assigned during registration.
                                        Only useful with the track_app_token command
  -o|--compact          	        Output JSON as compact instead of pretty
  -s|--session-token    SESSION_TOKEN	Session token for authentication. 
                                        Mainly useful for debugging

HELP
exit 0
}

# check the precense of the tools needed
check_tools() {
  for TOOL in ${TOOLS_NEEDED}; do
    if ! type "${TOOL}" &> /dev/null; then
      echo "${TOOL} is missing" 
      return 1 
    fi
  done
}

configure_authentication() {
  if [ -f "${AUTH_FILE}" ]; then
    APP_ID=$(${JQ} -r .app_id < "${AUTH_FILE}") 2> /dev/null
    APP_TOKEN=$(${JQ} -r .app_token < "${AUTH_FILE}") 2> /dev/null

    if [ "${APP_ID}" == "null" ]; then
      echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Cannot read app_id from ${AUTH_FILE}" '.result.status += $status'
      return 1
    fi

    if [ "${APP_TOKEN}" == "null" ]; then
      echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Cannot read app_token from ${AUTH_FILE}" '.result.status += $status'
      return 1
    fi

    return 0
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Provided authentication file missing: ${AUTH_FILE}" '.result.status += $status'
    return 1
  fi
}


get_challenge() {
  LOGIN_INFO=$(${CURL_CMD} ${FREEBOX_BASE}/login)

  if ! LOGIN_INFO_SUCCESS=$(echo "${LOGIN_INFO}" | jq -r '.success') 2> /dev/null; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Not able to get challange at ${FREEBOX_ADDRESS}" '.result.status += $status'
    return 1
  fi

  if [ "${LOGIN_INFO_SUCCESS}" == "true" ]; then
    echo "${LOGIN_INFO}" | ${JQ}
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Not able to get challenge at ${FREEBOX_ADDRESS}" '.result.status += $status'
    return 1
  fi
}

get_password() {
  if [ "${APP_TOKEN}" == "" ]; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "No app token provided" '.result.status += $status'
    return 1 
  fi

  CHALLENGE=$(get_challenge)
  CHALLENGE_SUCCESS=$(echo "${CHALLENGE}" | ${JQ} -r '.success')
  if [ "${CHALLENGE_SUCCESS}" == "false" ]; then
    echo "${CHALLENGE}" | ${JQ}
    return 1
  fi

  CHALLENGE=$(echo "${CHALLENGE}" | ${JQ} -r .result.challenge )
  if PASSWORD=$(echo -n "${CHALLENGE}" | ${HMAC_MD5} dgst -sha1 -hmac "${APP_TOKEN}" | sed 's/^SHA1(stdin)= //'); then 
    echo "${JSON_SUCCESS}" | ${JQ} ${JQ_COMPACT} --arg password "${PASSWORD}" '.result.password += $password'
    return 0
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Not able to get password" '.result.status += $status'
    return 1
  fi
}

get_session_token() {
  if [ "${APP_ID}" == "" ]; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "No app_id provided" '.result.status += $status'
    return 1 
  fi

  PASSWORD=$(get_password)
  PASSWORD_SUCCESS=$(echo "${PASSWORD}" | "${JQ}" -r '.success')
  if [ "${PASSWORD_SUCCESS}" == "true" ]; then
    PASSWORD=$(echo "${PASSWORD}" | ${JQ} -r '.result.password')
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Could not get password" '.result.status += $status'
    return 1 
  fi
  
  SESSION_REQUEST=$(echo "{}" | ${JQ} -c --arg app_id "${APP_ID}" --arg password "${PASSWORD}" '. +{app_id: $app_id, password: $password}')

  if ! SESSION_TOKEN_INFO=$(${CURL_CMD} --request POST --data "${SESSION_REQUEST}" ${FREEBOX_BASE}/login/session); then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Not able to get session token for ${APP_ID} at ${FREEBOX_ADDRESS}" '.result.status += $status'
    return 1
  fi

  if ! SESSION_TOKEN_SUCCESS=$(echo "${SESSION_TOKEN_INFO}" | jq -r .success) 2> /dev/null; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Not able to get session token for ${APP_ID} at ${FREEBOX_ADDRESS}" '.result.status += $status'
    return 1
  fi

  if [ "${SESSION_TOKEN_SUCCESS}" == "true" ]; then
    echo "${SESSION_TOKEN_INFO}" | ${JQ} 
    return 0
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Not able to get session token for ${APP_ID} at ${FREEBOX_ADDRESS}" '.result.status += $status'
    return 1
  fi
}

get_dhcp_dynamic_lease_names() {
  API_PATH="dhcp/dynamic_lease"
  GET
}

get_dhcp_static_lease_names() {
  API_PATH="dhcp/static_lease"
  GET
}

GET() {
  if [ "${API_PATH}" == "" ]; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "No API path provided" '.result.status += $status'
    return 1 
  fi

  if [ "${SESSION_TOKEN}" == "" ]; then
    set_session_token
  fi

  GET_INFO=$(${CURL_CMD} -H "X-Fbx-App-Auth:${SESSION_TOKEN}" ${FREEBOX_BASE}/${API_PATH})
  ERROR_CODE=$(echo "${GET_INFO}" | jq -r .error_code)
  if ! GET_INFO_SUCCESS=$(echo "${GET_INFO}" | jq -r .success) 2> /dev/null; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Could not curl ${FREEBOX_BASE}/${API_PATH}" '.result.status += $status'
    return 1
  fi

  if [ "${GET_INFO_SUCCESS}" == "true" ]; then
    echo "${GET_INFO}" | ${JQ}
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg error_code "${ERROR_CODE}" --arg status "Not able to GET ${FREEBOX_BASE}/${API_PATH}" '.result.status += $status | .result.error_code += $error_code'
    return 1
  fi
}


PUT() {
  if [ "${API_PATH}" == "" ]; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "No API path provided" '.result.status += $status'
    return 1 
  fi

  if [ "${JSON_CONTENT}" == "" ]; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "No JSON content to PUT provided." '.result.status += $status'
    return 1 
  fi

  if [ "${SESSION_TOKEN}" == "" ]; then
    set_session_token
  fi

  PUT_INFO=$(${CURL_CMD} -X PUT --data "${JSON_CONTENT}" -H "X-Fbx-App-Auth:${SESSION_TOKEN}" ${FREEBOX_BASE}/${API_PATH})
  ERROR_CODE=$(echo "${PUT_INFO}" | jq -r .error_code)
  if ! PUT_INFO_SUCCESS=$(echo "${PUT_INFO}" | jq -r .success) 2> /dev/null; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Could not curl ${FREEBOX_BASE}/${API_PATH}" '.result.status += $status'
    return 1
  fi

  if [ "${PUT_INFO_SUCCESS}" == "true" ]; then
    echo "${PUT_INFO}" | ${JQ}
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg error_code "${ERROR_CODE}" --arg status "Not able to PUT ${FREEBOX_BASE}/${API_PATH}" '.result.status += $status | .result.error_code += $error_code'
    return 1
  fi
}


POST() {
  if [ "${API_PATH}" == "" ]; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "No API path provided" '.result.status += $status'
    return 1 
  fi

  if [ "${JSON_CONTENT}" == "" ]; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "No JSON content to POST provided." '.result.status += $status'
    return 1 
  fi

  if [ "${SESSION_TOKEN}" == "" ]; then
    set_session_token
  fi

  POST_INFO=$(${CURL_CMD} -X POST --data "${JSON_CONTENT}" -H "X-Fbx-App-Auth:${SESSION_TOKEN}" ${FREEBOX_BASE}/${API_PATH})
  ERROR_CODE=$(echo "${POST_INFO}" | jq -r .error_code)
  if ! POST_INFO_SUCCESS=$(echo "${POST_INFO}" | jq -r .success) 2> /dev/null; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Could not curl ${FREEBOX_BASE}/${API_PATH}" '.result.status += $status'
    return 1
  fi

  if [ "${POST_INFO_SUCCESS}" == "true" ]; then
    echo "${POST_INFO}" | ${JQ}
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg error_code "${ERROR_CODE}" --arg status "Not able to POST ${FREEBOX_BASE}/${API_PATH}" '.result.status += $status | .result.error_code += $error_code'
    return 1
  fi
}

DELETE() {
  if [ "${API_PATH}" == "" ]; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "No API path provided" '.result.status += $status'
    return 1 
  fi

  if [ "${SESSION_TOKEN}" == "" ]; then
    set_session_token
  fi

  DELETE_INFO=$(${CURL_CMD} -X DELETE -H "X-Fbx-App-Auth:${SESSION_TOKEN}" ${FREEBOX_BASE}/${API_PATH})
  ERROR_CODE=$(echo "${DELETE_INFO}" | jq -r .error_code)
  if ! DELETE_INFO_SUCCESS=$(echo "${DELETE_INFO}" | jq -r .success) 2> /dev/null; then
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Could not curl ${FREEBOX_BASE}/${API_PATH}" '.result.status += $status'
    return 1
  fi

  if [ "${DELETE_INFO_SUCCESS}" == "true" ]; then
    echo "${DELETE_INFO}" | ${JQ}
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg error_code "${ERROR_CODE}" --arg status "Not able to DELETE ${FREEBOX_BASE}/${API_PATH}" '.result.status += $status | .result.error_code += $error_code'
    return 1
  fi
}

set_session_token() {
  SESSION_TOKEN_INFO=$(get_session_token)
  SESSION_TOKEN_SUCCESS=$(echo ${SESSION_TOKEN_INFO} | ${JQ} -r .success)

  if [ "${SESSION_TOKEN_SUCCESS}" == "true" ]; then
    SESSION_TOKEN=$(echo "${SESSION_TOKEN_INFO}" | ${JQ} -r .result.session_token)
    return 0
  else
    SESSION_TOKEN=""
    return 1
  fi
}

# Track our app token, check the status.
track_app_token() {
  if [ "${TRACK_ID}" == "" ]; then
    echo "TRACK_ID is empty."
    exit 1
  fi
  if INFO=$(${CURL_CMD} ${FREEBOX_BASE}/login/authorize/"${TRACK_ID}"); then
    echo "${INFO}" | ${JQ}
    return 0
  else
    echo "${JSON_FAILED}" | ${JQ} ${JQ_COMPACT} --arg status "Not able to track ${TRACK_ID} at ${FREEBOX_ADDRESS}" '.result.status += $status'
    return 1
  fi
}


################################################################################
# Argument parser
################################################################################
die() {
  printf '%s\n' "$1" >&2
  exit 1
}

while :; do
  case $1 in
    -h|-\?|--help)
        show_help    # Display a usage synopsis.
        exit
        ;;
    -a|--app-token)
        if [ "$2" ]; then
            APP_TOKEN="$2"
            shift
        else
            die 'ERROR: "ac|--app-token" requires a non-empty option argument.'
        fi
        ;;
    -A|--auth-file)
        if [ "$2" ]; then
            AUTH_FILE="$2"
            shift
        else
            die 'ERROR: "-A|--auth-file" requires a non-empty option argument.'
        fi
        ;;
    -c|--command)
        if [ "$2" ]; then
            COMMANDS="$2"
            shift
        else
            die 'ERROR: "-c|--command" requires a non-empty option argument.'
        fi
        ;;
    -f|--freebox)
        if [ "$2" ]; then
            FREEBOX_ADDRESS="$2"
            shift
        else
            die 'ERROR: "-p|--brick-path" requires a non-empty option argument.'
        fi
        ;;
    -i|--app-id)
        if [ "$2" ]; then
            APP_ID="$2"
            shift
        else
            die 'ERROR: "-i|--app-id" requires a non-empty option argument.'
        fi
        ;;
    -o|--compact)
        JQ="jq -c"
        shift
        ;;
    -p|--api-path)
        if [ "$2" ]; then
            API_PATH="$2"
            shift
        else
            die 'ERROR: "-c|--compact" requires a non-empty option argument.'
        fi
        ;;
    -P|--json-content)
        if [ "$2" ]; then
            JSON_CONTENT="$2"
            shift
        else
            die 'ERROR: "-P|--json-content" requires a non-empty option argument.'
        fi
        ;;
    -s|--session-token)
        if [ "$2" ]; then
            SESSION_TOKEN="$2"
            shift
        else
            die 'ERROR: "-s|--session-token" requires a non-empty option argument.'
        fi
        ;;
    -t|--track-id)
        if [ "$2" ]; then
            TRACK_ID="$2"
            shift
        else
            die 'ERROR: "-t|--track-id" requires a non-empty option argument.'
        fi
        ;;
    --)              # End of all options.
        shift
        break
        ;;
    *)               # Default case: No more options, so break out of the loop.
        break
  esac

  shift
done


################################################################################
# Main Main Main
################################################################################
FREEBOX_BASE="https://"${FREEBOX_ADDRESS}"/api/${FREEBOX_API_VERSION}"

if [ "${COMMANDS}" == "" ]; then
  show_help
  exit 0
fi

if ! check_tools; then
  exit 1
fi


if ! configure_authentication; then
  exit 1
fi

COMMANDS=$(echo ${COMMANDS} | tr ',' ' ')
for COMMAND in ${COMMANDS}; do
  ${COMMAND}
done

