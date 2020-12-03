#!/bin/bash

# up42.sh --- A simple cURL based API connector for UP42.


# Copyright (C) 2020 UP42 GmbH

# Author: António P. P. Almeida <antonio.almeida@up42.com>

# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 3
# of the License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program. If not, see <http://www.gnu.org/licenses/>.

SCRIPTNAME=${0##*/}

## Token variable.
UP42_TOKEN=''

## Necessary programs.
CURL=$(command -v curl) || exit 1
JWT=$(command -v jwt) || exit 2
JQ=$(command -v jq) || exit 3
UUID=$(command -v uuid) || exit 4

## Check which OS we are in: Mac OS or Linux to decide where GNU core
## utils we need are located.
if [ "$(uname -s)" = "Darwin" ]; then
    DATECMD=gdate
    STATCMD=gstat
else
    DATECMD=date
    STATCMD=stat
fi

DATE=$(command -v $DATECMD) || exit 5
STAT=$(command -v $STATCMD) || exit 13

## Common cURL options.
CURLOPTS='-L -s'

## If UP42_BASE_URL is defined in the environment then use
## it. Otherwise use the default production server URL.
BASE_URL=${UP42_BASE_URL:-https://api.up42.com}

function print_usage() {
    echo "Usage: $SCRIPTNAME -o <operation> [-a <asset ID>] [-b <request body>] [-c <config file>] [-q <query string params> [-w <workspace ID>]]"
}

## Check the minimum number of arguments.
if [ $# -lt 2 ]; then
    print_usage
    exit 6
fi

## The configuration directory.
CONFIG_DIR=$HOME/.up42

## If the directory doesn't exist create it.
if [ ! -d $CONFIG_DIR ]; then
    mkdir $CONFIG_DIR
    SETUP_DIR=0
fi

## Check the permissions on the directory and fix them if needed.
if [ $($STAT -c '%a' $CONFIG_DIR) -ne 700 ]; then
    chmod 700 $CONFIG_DIR
    SETUP_DIR=0
fi

## The default configuration file.
CONFIG_FILE=$CONFIG_DIR/proj_default.conf

## Ask the user to re-rerun the program with the comfiguration files
## in place.
if [ ${SETUP_DIR-1} -eq  0 ]; then
    echo "$SCRIPTNAME: Setup configuration directory $CONFIG_DIR."
    echo "Please add a configuration file to it. Default: $CONFIG_FILE."
    print_usage
    exit 0
fi

## Read the options.
while getopts a:b:c:o:q:w: OPT; do
    case $OPT in
        a|+a)
            ASSET_ID="$OPTARG"
            ;;
        b|+b)
            REQ_BODY="$OPTARG"
            ;;
        c|+c)
            CONFIG_FILE="$OPTARG"
            ;;
        o|+o)
            OPERATION="$OPTARG"
            ;;
        q|+q)
            QUERY_PARAMS="$OPTARG"
            ;;
        w|+w)
            WORKSPACE_ID="$OPTARG"
            ;;
        *)
            print_usage
            exit 7
            ;;
    esac
done
shift $(( OPTIND - 1 ))
OPTIND=1

## Validates the UUID. UP42 uses v4 UUIDs.
## $1: The UUID to be validated.
function validate_uuid() {
    [ "$($UUID -d $1 | awk '/version/ {print $2}')" = "4" ]
    return $?
}

function get_configuration() {
    if  [ ! -r $CONFIG_FILE ]; then
        echo "$SCRIPTNAME: Cannot read configuration file $CONFIG_FILE."
        exit 8
    fi

    ## Read the configuration.
    if $JQ -e '.' $CONFIG_FILE > /dev/null; then
        PROJECT_ID=$(JQ -r '.project_id' $CONFIG_FILE)
        PROJECT_KEY=$(JQ -r '.project_api_key' $CONFIG_FILE)
    else
        echo "$SCRIPTNAME: Error parsing JSON in $CONFIG_FILE."
        exit 9
    fi

    ## Validate the project
    if  ! validate_uuid $PROJECT_ID; then
        printf '%s: given project ID %s is invalid\n' $SCRIPTNAME $PROJECT_ID
        exit 10
    fi
}

## Builds the URL for a given endpoint.
## $1: Endpoint.
function build_url() {
    printf '%s%s' $BASE_URL $1
}

## Obtains the token for a given project.
function get_token() {
    local token_url='/oauth/token'
    ## Get the token.
    UP42_TOKEN=$(CURL $CURLOPTS -X POST -u "$PROJECT_ID:$PROJECT_KEY" \
                      -H 'Content-Type: application/x-www-form-urlencoded' \
                      -d 'grant_type=client_credentials' $(build_url $token_url) | $JQ -r '.data.accessToken')
    ## If the token is empty something failed while trying to obtain it.
    if [ -z "$UP42_TOKEN" ]; then
        echo "$SCRIPTNAME: Cannot obtain token. Check the given values and try again."
        exit 11
    else
        echo $UP42_TOKEN > $TOKEN_FILE
    fi
}

## Handles the token depending its is set or has expired based
## on the value of the exp field in the token payload.
function handle_token() {
    local dt
    ## Try to source the token first.
    if [ -r $TOKEN_FILE ]; then
        UP42_TOKEN=$(cat $TOKEN_FILE)
    else
        get_token
    fi
    ## Get the token expiration date.
    dt=$($JWT decode -j -A HS512 $UP42_TOKEN | $JQ -r '.payload.exp')
    ## If the token has alread expired then get a new one.
    if [ $($DATE +'%s') -gt $dt ]; then
        get_token
    fi
}

## Performs a catalog search given a request body containing the STAC
## parameters.
## $1: request body (JSON document).
## Returns: a JSON document with the response or an error.
function do_search() {
    ## Get the search URL.
    local search_url=$(build_url "/catalog/stac/search")
    # Issue the request.
    $CURL $CURLOPTS -X POST -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" -d @$1 $search_url
}

## $1: request body (JSON document).
## $2: workspace ID.
function do_order_placement() {
    ## Get the order placement URL.
    local place_order_url=$(build_url "/workspaces/$2/orders")
    # Issue the request.
    $CURL $CURLOPTS -X POST -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" -d @$1 $place_order_url
}

## $1: request body (JSON document).
## $2: workspace ID.
function do_order_estimation() {
    ## Get the order estimation URL.
    local estimate_order_url=$(build_url "/workspaces/$2/orders/estimate")
    ## Issue the request.
    $CURL $CURLOPTS -X POST -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" -d @$1 $estimate_order_url
}

## $1: workspace ID.
function do_order_list() {
    ## Get the order list URL.
    local order_list_url=$(build_url "/workspaces/$1/orders/")
    ## Issue the request.
    $CURL $CURLOPTS -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" $order_list_url
}

## $1: workspace ID.
function do_asset_list() {
    ## Get the asset list URL.
    local asset_list_url=$(build_url "/workspaces/$1/assets/")
    ## Issue the request.
    $CURL $CURLOPTS -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" $asset_list_url
}

## $1: workspace ID.
## $2: asset ID.
function do_asset_info() {
    ## Get the asset list URL.
    local asset_url=$(build_url "/workspaces/$1/assets/$2")
    ## Issue the request.
    $CURL $CURLOPTS -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" $asset_url
}

## $1: request body (JSON document).
## $2: workspace ID.
## $3: asset ID.
function do_asset_download_url() {
    ## Download URL information for an asset endpoint.
    local download_asset_url=$(build_url "/workspaces/$2/assets/$3/downloadUrl")
    ## Issue the request.
    $CURL $CURLOPTS -X POST -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" -d @$1 $download_asset_url
}

## Read the configuration.
get_configuration

TOKEN_FILE="$(pwd)/${PROJECT_ID}_UP42_token.txt"

## Perform the API operation,
case "$OPERATION" in
    "search")# do a catalog search
        handle_token
        do_search "$REQ_BODY"
        ;;
    "list-orders") # get all orders
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_order_list "$WORKSPACE_ID"
        ;;
    "estimate-order") # estimate an order cost
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_order_estimation "$REQ_BODY" "$WORKSPACE_ID"
        ;;
    "place-order") # place an order
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_order_placement "$REQ_BODY" "$WORKSPACE_ID"
        ;;
    "list-assets") # get all assets
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_asset_list "$WORKSPACE_ID"
        ;;
    "get-asset-info") # list the information about a given asset
        validate_uuid "$ASSET_ID"
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_asset_info "$WORKSPACE_ID" "$ASSET_ID"
        ;;
    "get-asset-download-url")
        validate_uuid "$ASSET_ID"
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_asset_download_url "$REQ_BODY" "$WORKSPACE_ID" "$ASSET_ID"
        ;;
    *)
        print_usage
        exit 12
esac