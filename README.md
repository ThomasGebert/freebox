# freebox
## CLI for freebox API
Intention is to use the Freebox API from openWRT devices, which normally do not ship with
Python or any other sophisticated programming language. 

Therefore good old shell code. =0)

```
Freebox API CLI

Usage: freebox-cli.sh [OPTIONS]

Mandatory options:
A command to execute
  -c|--commands COMMANDS        	The command(s) to execute.
	                                Possible commands are:
					- GET
					- POST
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
  -p|--api-path		API_PATH	API path to GET/POST. Without the /api/v15/ part.
                                        See freebox documentation for details

Autentication can be passed directly via:
  -i|--app-id		APP_ID		App id used during registration
  -a|--app-token	APP_TOKEN	App token to use
Or provide a json file containing these values
  -A|--auth-file	AUTH_FILE	json file containing app_id and app_token

Optional:
  -f|--freebox		FREEBOX_ADDRESS Address of the freebox (Default: 192.168.1.254)
  -t|--track-id 	TRACK_ID        Track ID to use. Is assigned during registration.
                                        Only useful with the track_app_token command
  -o|--compact          	        Output JSON as compact instead of pretty
  -s|--session-token    SESSION_TOKEN	Session token for authentication. 
                                        Mainly useful for debugging
```
