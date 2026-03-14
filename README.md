# freebox

- [CLI for freebox API](#cli-for-freebox-api)
- [Authorization](#authorization)

## CLI for freebox API
Intention is to use the Freebox API from openWRT devices, which normally do not ship with
Python or any other sophisticated programming language. 

Therefore good old shell code. =0)

```
Freebox API CLI

Usage: freebox-cli.sh [OPTIONS]

Mandatory options:
A command to execute
  -c|--commands         COMMANDS        The command(s) to execute.
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
  -p|--api-path		    API_PATH	    API path to GET/PUT/POST/DELETE. Without the /api/v15/ part.
                                            See freebox documentation for details
  -P|--json-content     JSON_CONTENT    JSON to PUT/POST

Autentication can be passed directly via:
  -i|--app-id		    APP_ID		    App id used during registration
  -a|--app-token	    APP_TOKEN	    App token to use
                                        Or provide a json file containing these values
  -A|--auth-file	    AUTH_FILE	    json file containing app_id and app_token

Optional:
  -f|--freebox		    FREEBOX_ADDRESS Address of the freebox (Default: 192.168.1.254)
  -t|--track-id 	    TRACK_ID        Track ID to use. Is assigned during registration.
                                        Only useful with the track_app_token command
  -o|--compact              	        Output JSON as compact instead of pretty
  -s|--session-token    SESSION_TOKEN	Session token for authentication. 
                                        Mainly useful for debugging
```

## Authorization
A detailed description can be found in the API developer documentation which is available on every Freebox.

First you need a login for the API which contains an `app_id` and an `app_token`. Keep this information secure.

Following an example of the JSON and the POST address to request your login. Once the request was made you have to go to your Freebox to accept the request on the screen.
```
POST /api/v8/login/authorize/ HTTP/1.1

{
   "app_id": "fr.freebox.testapp",
   "app_name": "Test App",
   "app_version": "0.0.7",
   "device_name": "Pc de Xavier"
}
```
On success you get a token similar to the one below.
```
{
   "success": true,
   "result": {
      "app_token": "dyNYgfK0Ya6FWGqq83sBHa7TwzWo+pg4fDFUJHShcjVYzTfaRrZzm93p7OTAfH/0",
      "track_id": 42
   }
}
```
With the `app_id` and the `app_token` one can create the `auth-file` which looks as follows.
```
{
  "app_id": "fr.freebox.testapp",
  "app_token":"dyNYgfK0Ya6FWGqq83sBHa7TwzWo+pg4fDFUJHShcjVYzTfaRrZzm93p7OTAfH/0"
}
```
It is a good idea to keep all the information involved so far to keep track of different authentications and to query status with e.g. the `track_id`.
