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

## Common cURL options.
CURLOPTS='-L -s'

## If UP42_BASE_URL is defined in the environment then use
## it. Otherwise use the default production server URL.
BASE_URL=${UP42_BASE_URL:-https://api.up42.com}

function print_usage() {
    echo "Usage: $SCRIPTNAME -f <operation> [-a <asset ID>] [-b <request body>] [-c <config file>] [-h <operation>] [-g <workflow ID>] [-i <image ID>] [-j <job ID>] [-o <order ID>] [-p <provider>] [-q <query string params>] [-w <workspace ID>]"
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

## $1: operation.
function do_display_help() {
    case "$1" in
        "search")
            echo "Usage: $SCRIPTNAME -f search -b <request body>"
            exit 0
            ;;
        "get-quicklook")
            echo "Usage: $SCRIPTNAME -f get-quicklook -p <data provider> -i <image ID>"
            exit 0
            ;;
        "run-job")
            echo "Usage: $SCRIPTNAME -f run-job -g <workflow ID> -b <request body> [-n <job name>]"
            exit 0
            ;;
        "get-job-status")
            echo "Usage: $SCRIPTNAME -f get-job-status -j <job ID>"
            exit 0
            ;;
        "get-job-info")
            echo "Usage: $SCRIPTNAME -f get-job-info -j <job ID>"
            exit 0
            ;;
        "cancel-job")
            echo "Usage: $SCRIPTNAME -f cancel-job -j <job ID>"
            exit 0
            ;;
        "rerun-job")
            echo "Usage: $SCRIPTNAME -f rerun-job -g <workflow ID> -j <job ID>"
            exit 0
            ;;
        "rename-job")
            echo "Usage: $SCRIPTNAME -f rename-job -g <workflow ID> -j <job ID> -n <job name>"
            exit 0
            ;;
        "get-job-tasks")
            echo "Usage: $SCRIPTNAME -f get-job-tasks -j <job ID>"
            exit 0
            ;;
        "get-job-results-json")
            echo "Usage: $SCRIPTNAME -f get-job-results-json -j <job ID>"
            exit 0
            ;;
        "get-job-results-download-url")
            echo "Usage: $SCRIPTNAME -f get-job-results-download-url -j <job ID>"
            exit 0
            ;;
        "get-job-results")
            echo "Usage: $SCRIPTNAME -f get-job-results -j <job ID> [-n <name>]"
            exit 0
            ;;
        "list-orders")
            echo "Usage: $SCRIPTNAME -f list-orders -w <workspace ID>"
            exit 0
            ;;
        "get-order-info")
            echo "Usage: $SCRIPTNAME -f get-order-info -w <workspace ID>  -o <order ID>"
            exit 0
            ;;
        "get-order-metadata")
            echo "Usage: $SCRIPTNAME -f get-order-metadata -w <workspace ID>  -o <order ID>"
            exit 0
            ;;
        "estimate-order")
            echo "Usage: $SCRIPTNAME -f estimate-order -w <workspace ID>  -b <request body>"
            exit 0
            ;;
        "place-order")
            echo "Usage: $SCRIPTNAME -f place-order -w <workspace ID>  -b <request body>"
            exit 0
            ;;
        "list-assets")
            echo "Usage: $SCRIPTNAME -f list-assets -w <workspace ID>"
            exit 0
            ;;
        "get-asset-info")
            echo "Usage: $SCRIPTNAME -f get-asset-info -a <asset ID> -w <workspace ID>  -b <request body>"
            exit 0
            ;;
        "get-asset-download-url")
            echo "Usage: $SCRIPTNAME -f get-asset-download-url -a <asset ID> -w <workspace ID>"
            exit 0
            ;;
        "download-asset")
            echo "Usage: $SCRIPTNAME -f download-asset -a <asset ID> -w <workspace ID>"
            exit 0
            ;;
        *)
            print_usage
            exit 14
    esac
}
## Read the options.
while getopts Da:b:c:f:g:h:i:j:n:o:p:q:w: OPT; do
    case $OPT in
        D|+D)
            DEBUG=1
            ;;
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
        g|+g)
            WORKFLOW_ID="$OPTARG"
            ;;
        h|h+)
            do_display_help "$OPTARG"
            ;;
        i|+i)
            IMAGE_ID="$OPTARG"
            ;;
        j|+j)
            JOB_ID="$OPTARG"
            ;;
        n|+n)
            NAME="$OPTARG"
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

## Encodes a string in a URL.
## Taken from: https://stackoverflow.com/questions/296536/how-to-urlencode-data-for-curl-command.
## $1: string to be encoded in the URL.
function encode_url() {
    local string="${1}"
    local strlen=${#string}
    local encoded=""
    local pos c o

    ## Loop on the string to encode.
    for (( pos=0 ; pos<strlen ; pos++ )); do
        c=${string:$pos:1}
        case "$c" in
            [-_.~a-zA-Z0-9]) # URL safe characters
                o="${c}"
                ;;
            *) # non URL safe characters: needs to be escaped
                printf -v o '%%%02x' "'$c"
                ;;
        esac
        encoded+="${o}"
    done
    echo "${encoded}"
}

## Reads the configuration.
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

    ## Validate the project.
    if  ! validate_uuid $PROJECT_ID; then
        printf '%s: given project ID %s is invalid.\n' $SCRIPTNAME $PROJECT_ID
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

## Handles the token depending if is set or has expired based
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

## Validates the job parameters passed in the request body.
## $1: project ID.
## $2: workflow ID.
## $3: request body (JSON document).
function do_validate_job_params() {
    local validate_job_url=$(build_url "/projects/$1/workflows/$2/jobs/validate")
    ## Issue the request.
    $CURL $CURLOPTS -X POST -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" -d @$3 $validate_job_url
}

## Names a job according to a given string.
## $1: name string.
function name_job() {
    echo $(encode_url "$SCRIPTNAME: $1@$($DATE +'%Y.%m.%d:%H:%M:%S')")
}

## Runes a job given project and workflow ID.
## $1: project ID.
## $2: workflow ID.
## $3: request body (JSON document).
## $4: job name (optional).
function do_run_job() {
    local create_job_url=$(build_url "/projects/$1/workflows/$2/jobs")
    ## Create random job name.
    local job_name=$(name_job "$RANDOM")
    ## Check if the job name is given. Is so name it accordingly.
    [ $# -eq 4 ] && job_name=$(name_job "$4")
    ## Issue the request.
    $CURL $CURLOPTS -X POST -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" -d @$3 "$create_job_url?name=$job_name"
}

## Gets the metadata of a given job in a given project.
## $1: project ID.
## $2: job ID.
function do_job_info() {
    local job_info_url=$(build_url "/projects/$1/jobs/$2")
    ## Issue the request.
    $CURL $CURLOPTS -H "Authorization: Bearer $UP42_TOKEN" \
          -H 'Content-Type: application/json' $job_info_url
}

## Gets the job status of a given job in a given project.
## $1: project ID.
## $2: job ID.
function do_job_status() {
    echo $(do_job_info "$1" "$2" | $JQ -r '.data.status')
}

## Cancels a given job.
## $1: project ID.
## $2: job ID.
function do_job_cancel() {
    local job_cancel_url=$(build_url "/projects/$1/jobs/$2/cancel")
    ## Issue the request.
    $CURL $CURLOPTS -X POST -H "Authorization: Bearer $UP42_TOKEN" \
          $job_cancel_url
}

## Reruns a given job.
## $1: project ID.
## $2: workflow ID.
## $3: job ID.
## $4: job name (optional).
function do_job_rerun() {
    local job_rerun_url=$(build_url "/projects/$1/workflows/$2/jobs/$3")
    local job_name=$(name_job "$RANDOM")
    ## Check if the job name is given. Is so name it accordingly.
    [ $# -eq 4 ] && job_name=$(name_job "$4")
    ## Issue the request.
    $CURL $CURLOPTS -X POST -H "Authorization: Bearer $UP42_TOKEN" \
          $job_rerun_url?name="$job_name"
}

## Renames a given job.
## $1: project ID.
## $2: workflow ID.
## $3: job ID.
## $4: job name.
function do_job_rename() {
    local job_rename_url=$(build_url "/projects/$1/workflows/$2/jobs/$3")
    local data=$(printf '{"name": "%s"}' "$4")
    ## Issue the request.
    $CURL $CURLOPTS -X PUT -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" \
          -d "$data" $job_rename_url
}

## Gets a given job tasks.
## $1: project ID.
## $2: job ID.
function do_job_tasks() {
    ## Get the job tasks URL.
    local job_tasks_url=$(build_url "/projects/$1/jobs/$2/tasks")
    ## Issue the request.
    $CURL $CURLOPTS -H "Authorization: Bearer $UP42_TOKEN" \
          -H 'Content-Type: application/json' $job_tasks_url
}

## Gets a the GeoJSON output of a job (metadata).
## $1: project ID.
## $2: job ID.
function do_job_results_json() {
    ## Get the job GeoJSON output URL.
    local job_results_json_url=$(build_url "/projects/$1/jobs/$2/outputs/data-json")
    ## Issue the request.
    $CURL $CURLOPTS -H "Authorization: Bearer $UP42_TOKEN" \
          -H 'Content-Type: application/json' $job_results_json_url
}

## Gets the JSON with a signed URL to download the job results.
## $1: project ID.
## $2: job ID.
function do_job_results_download_url() {
    ## Get the job GeoJSON output URL.
    local job_results_download_url=$(build_url "/projects/$1/jobs/$2/downloads/results")
    ## Issue the request.
    $CURL $CURLOPTS -H "Authorization: Bearer $UP42_TOKEN" \
          -H 'Content-Type: application/json' $job_results_download_url
}

# Gets the job results as a tarball.
## $1: project ID.
## $2: job ID.
## $3: output archive name (optional)
function do_job_results() {
    ## Get the results signed download URL.
    local job_results_url=$(do_job_results_download_url $1 $2 | $JQ -r '.data.url')
    ## Default output archive name.
    local out_fn=$(printf 'output_%s_%s.tar.gz' "$1" "$2")
    ## Check if the job name is given. Is so name it accordingly.
    [ -n "$3" ] && out_fn=$(printf 'output_%s.tar.gz' "$3")
    ## Issue the request.
    $CURL -L -H "Authorization: Bearer $UP42_TOKEN" \
          -o $out_fn "$job_results_url"
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

## $1: request body (JSON document).
## $2: workspace ID.
function do_order_placement() {
    ## Get the order placement URL.
    local place_order_url=$(build_url "/workspaces/$2/orders")
    # Issue the request.
    $CURL $CURLOPTS -X POST -H 'Content-Type: application/json' \
          -H "Authorization: Bearer $UP42_TOKEN" -d @$1 $place_order_url
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
    local asset_list_url=$(build_url "/workspaces/$1/assets/?direction=DESC")
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
                            | awk -F '&' '{split($3, a, "="); print a[2]}')
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

## Lists the available operations.
function do_list_operations() {
    echo "$SCRIPTNAME: Available operations."
    echo -e "run-job\nget-job-status\nget-job-info\ncancel-job\nrerun-job\nrename-job\nget-job-tasks"
    echo -e "get-job-results-json\nget-job-results-download-url\nget-job-results"
    echo -e "search\nget-quicklook\nlist-orders"
    echo -e "get-order-info\nget-order-metadata\nestimate-order"
    echo -e "place-order\nlist-assets\nget-asset-info"
    echo -e "get-asset-download-url\ndownload-asset"
}

## Read the configuration.
get_configuration

TOKEN_FILE="$(pwd)/${PROJECT_ID}_UP42_token.txt"

## Trace the Bash execution from here id DEBUG is set.
[ -n "$DEBUG" ] && set -x

## Perform the API operation,
case "$OPERATION" in
    "list-operations") # list all the operations
        do_list_operations
        exit 0
        ;;
    "search") # do a catalog search
        handle_token
        do_search "$REQ_BODY"
        ;;
    "get-quicklook") # do a catalog search
        handle_token
        do_quicklook "$PROVIDER" "$IMAGE_ID"
        ;;
    "run-job") # run a job
        validate_uuid "$WORKFLOW_ID"
        handle_token
        do_validate_job_params "$PROJECT_ID" "$WORKFLOW_ID" "$REQ_BODY"
        do_run_job "$PROJECT_ID" "$WORKFLOW_ID" "$REQ_BODY" "$NAME"
        ;;
    "get-job-status") # get a job status
        validate_uuid "$JOB_ID"
        handle_token
        do_job_status "$PROJECT_ID" "$JOB_ID"
        ;;
    "get-job-info") # get a job metadata
        validate_uuid "$JOB_ID"
        handle_token
        do_job_info "$PROJECT_ID" "$JOB_ID"
        ;;
    "cancel-job") # cancels a job
        validate_uuid "$JOB_ID"
        handle_token
        do_job_cancel "$PROJECT_ID" "$JOB_ID" "NAME"
        ;;
    "rerun-job") # reruns a job
        validate_uuid "$JOB_ID"
        handle_token
        do_job_rerun "$PROJECT_ID" "$WORKFLOW_ID" "$JOB_ID" "$NAME"
        ;;
    "rename-job") # reruns a job
        validate_uuid "$JOB_ID"
        handle_token
        do_job_rename "$PROJECT_ID" "$WORKFLOW_ID" "$JOB_ID" "$NAME"
        ;;
    "get-job-tasks")# get a job tasks
        validate_uuid "$JOB_ID"
        handle_token
        do_job_tasks "$PROJECT_ID" "$JOB_ID"
        ;;
    "get-job-results-json")# get a job GeoJSON output
        validate_uuid "$JOB_ID"
        handle_token
        do_job_results_json "$PROJECT_ID" "$JOB_ID"
        ;;
    "get-job-results-download-url")# get a job output download URL
        validate_uuid "$JOB_ID"
        handle_token
        do_job_results_download_url "$PROJECT_ID" "$JOB_ID"
        ;;
    "get-job-results")# get a job output
        validate_uuid "$JOB_ID"
        handle_token
        do_job_results "$PROJECT_ID" "$JOB_ID" "$NAME"
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

## Untrace Bash execution if DEBUG is set.
[ -n "$DEBUG" ] && set +x
