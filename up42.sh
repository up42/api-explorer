#!/bin/bash

# up42.sh --- Script to explore the UP42 API, mostly for support
# questions.

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

## Common cURL options.>
CURLOPTS='-L -s'

## If UP42_BASE_URL is defined in the environment then use
## it. Otherwise use the default production server URL.
BASE_URL=${UP42_BASE_URL:-https://api.up42.com}

function print_usage() {
    echo "Usage: $SCRIPTNAME -f <operation> [-a <asset ID>] [-b <request body>] [-c <config file>] [-i <image ID>] [-o <order ID>] [-p <provider>] [-q <query string params>] [-w <workspace ID>]"
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
while getopts a:b:c:f:i:o:p:q:w: OPT; do
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
        f|f+)
            OPERATION="$OPTARG"
            ;;
        h|h+)
            do_display_help "$OPTARG"
            ;;
        i|+i)
            IMAGE_ID="$OPTARG"
            ;;
        o|+o)
            ORDER_ID="$OPTARG"
            ;;
        p|+p)
            PROVIDER="$OPTARG"
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

## Obtains the token for a given project.g
function get_token() {
    local token_url=$(build_url '/oauth/token')
    ## Get the token.
    UP42_TOKEN=$($CURL $CURLOPTS -u "$PROJECT_ID:$PROJECT_KEY" \
                       -H 'Content-Type: application/x-www-form-urlencoded' \
                       -d 'grant_type=client_credentials' $token_url | $JQ -r '.data.accessToken')
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

## $1: operation.
function do_display_help() {
    case "$1" in
        "search")
            echo "Usage: $SCRIPTNAME  -f search -b <request body>"
            ;;
        "get-quicklook")
            echo "Usage: $SCRIPTNAME  -g get-quicklook <data provider> -i <image ID>"
            ;;
        "list-orders")
            echo "Usage: $SCRIPTNAME -f list-orders -w <workspace ID>"
            ;;
        "get-order-info")
            echo "Usage: $SCRIPTNAME -f get-order-info -w <workspace ID>  -o <order ID>"
            ;;
        "get-order-metadata")
            echo "Usage: $SCRIPTNAME -f get-order-metadata -w <workspace ID>  -o <order ID>"
            ;;
        "estimate-order")
            echo "Usage: $SCRIPTNAME -f estimate-order -w <workspace ID>  -b <request body>"
            ;;
        "place-order")
            echo "Usage: $SCRIPTNAME -f place-order -w <workspace ID>  -b <request body>"
            ;;
        "list-assets")
            echo "Usage: $SCRIPTNAME -f list-assets -w <workspace ID>"
            ;;
        "get-asset-info")
            echo "Usage: $SCRIPTNAME -f get-asset-info -a <asset ID> -w <workspace ID>  -b <request body>"
            ;;
        "get-asset-download-url")
            echo "Usage: $SCRIPTNAME -f get-asset-download-url -a <asset ID> -w <workspace ID>"
            ;;
        "get-asset-download-url")
            echo "Usage: $SCRIPTNAME -f download-asset -a <asset ID> -w <workspace ID>"
            ;;
        *)
            print_usage
            exit 14
    esac
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

## $1: imagery provider.
## $2: image ID (provider specific).
function do_quicklook() {
    ## The URL for getting the quicklook.
    local quicklook_url=$(build_url "/catalog/$1/image/$2/quicklook")
    ## Get the content type to be returned.
    local content_type=$($CURL $CURLOPTS -I -H "Authorization: Bearer $UP42_TOKEN" \
                               -H 'Accept: image/webp; q=0.9, image/png; q=0.8, image/jpeg; q=0.7' \
                               -w "%{content_type}" \
                               -o /dev/null $quicklook_url | cut -f 2 -d '/' | sed 's/jpeg/jpg/')
    ## Create the quicklook_filename.
    local quicklook_fn=quicklook_$1_$2.$content_type
    ## Get the quicklook filename.
    echo "$SCRIPTNAME: Getting $quicklook_fn..."
    $CURL -L -H "Authorization: Bearer $UP42_TOKEN" \
          -H 'Accept: image/webp; q=0.9, image/png; q=0.8, image/jpeg; q=0.7' \
          -o  "$quicklook_fn" $quicklook_url
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
    $CURL $CURLOPTS -H "Authorization: Bearer $UP42_TOKEN" $order_list_url
}

## $1: workspace ID.
## $2: order ID.
function do_order_info() {
    ## Get the order list URL.
    local order_info_url=$(build_url "/workspaces/$1/orders/$2")
    ## Issue the request.
    $CURL $CURLOPTS -H "Authorization: Bearer $UP42_TOKEN" $order_info_url
}

## $1: workspace ID.
## $2: order ID.
function do_order_metadata() {
    ## Get the order list URL.
    local order_metadata_url=$(build_url "/workspaces/$1/orders/$2/metadata")
    ## Issue the request.
    $CURL $CURLOPTS -H "Authorization: Bearer $UP42_TOKEN" $order_metadata_url
}

## $1: workspace ID.
function do_asset_list() {
    ## Get the asset list URL.
    local asset_list_url=$(build_url "/workspaces/$1/assets/")
    ## Issue the request.
    $CURL $CURLOPTS -H "Authorization: Bearer $UP42_TOKEN" $asset_list_url
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

## $1: workspace ID.
## $2: asset ID.
function do_asset_download_url() {
    ## Download URL information for an asset endpoint.
    local download_asset_url=$(build_url "/workspaces/$1/assets/$2/downloadUrl")
    ## Issue the request.
    $CURL $CURLOPTS -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" $download_asset_url
}

## $1: workspace ID.
## $2: asset ID.
function do_download_asset() {
    ## Get the JSON that includes the download URL from GCP and also
    ## expiry date for it.
    local download_data_url=$(do_asset_download_url $1 $2 | $JQ -r '.data.url')
    local expire_date=$(echo "$download_data_url" \
                            | awk -F '&' '{split($2, a, "="); print a[2]}')
    ## Extract the asset filename from the download URL.
    local asset_fn=$(echo "$download_data_url" \
                         | awk -F '&' '{split($1, a, "/")
                            split(a[length(a)], b, "?")
                            print b[1]}')
    ## Check is the download URL is still valid.
    if [ $($DATE +'%s') -gt $expire_date ]; then
        echo "$SCRIPTNAME: Download link has expired."
        exit 14
    fi
    ## Get the asset.
    $CURL -L -H "Authorization: Bearer $UP42_TOKEN" \
          -o "output_${ASSET_ID}_${asset_fn}" "$download_data_url"
}

## Read the configuration.
get_configuration

TOKEN_FILE="$(pwd)/${PROJECT_ID}_UP42_token.txt"

## Perform the API operation,
case "$OPERATION" in
    "search") # do a catalog search
        handle_token
        do_search "$REQ_BODY"
        ;;
    "get-quicklook") # do a catalog search
        handle_token
        do_quicklook "$PROVIDER" "$IMAGE_ID"
        ;;
    "list-orders") # get all orders
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_order_list "$WORKSPACE_ID"
        ;;
    "get-order-info") # get the information for an order
        validate_uuid "$ORDER_ID"
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_order_info  "$WORKSPACE_ID" "$ORDER_ID"
        ;;
    "get-order-metadata") # get the information for an order
        validate_uuid "$ORDER_ID"
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_order_metadata  "$WORKSPACE_ID" "$ORDER_ID"
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
    "get-asset-download-url") # get the asset download URL
        validate_uuid "$ASSET_ID"
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_asset_download_url "$WORKSPACE_ID" "$ASSET_ID"
        ;;
    "download-asset") # download an asset
        validate_uuid "$ASSET_ID"
        validate_uuid "$WORKSPACE_ID"
        handle_token
        do_download_asset "$WORKSPACE_ID" "$ASSET_ID"
        ;;
    *)
        print_usage
        exit 12
esac
