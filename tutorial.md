# Example on how to query and order using the UP42 API

## Introduction

This document presents an example top to bottom, how to query and
place orders for both immediately and cold storage (archived) images.

## 0. Installation


 0. Requirements

 + [Bash](https://en.wikipedia.org/wiki/Bash_(Unix_shell)).
 + [cURL](https://curl.haxx.se).
 + [jq](https://stedolan.github.io/jq/).
 + [jwt-cli](https://github.com/mike-engel/jwt-cli).
 + [GNU core utilities](https://www.gnu.org/software/coreutils/coreutils.html)
   &mdash; recommended, not mandatory.
 + [uuid](http://www.ossp.org/pkg/lib/uuid/).

 1. Clone the repository:
 ```bash
git clone https://github.com/up42/api-explorer.git
```
 2. Create an alias: add to your Bash aliases the alias.
```bash
alias up42='/path/to/api-explorer/up42.sh'
```
 3. Source the alias.
```bash
source ~/.bashrc
```
 4. Done.

## 1. Configuration: setup the project key and project ID

You need to setup a file with the project ID and project API key, like
this:

```js
{
  "project_id": "<projetc ID>",
  "project_api_key": "<project API key>"
}
```

You can create a **default** configuration file, named
`project_default.conf` at the `~/.up42/` directory. This directory
will be created by the script if doesn't exist. Alternatively you can
pass the configuration file as an argument to the script with the
option `-c`. E.g.,

```bash
up42.sh -f searcg -b search_params.json -c my_project.conf
```

Here we are passing a configuration file `my_project.conf`.

## 2. Getting help

To get an overview of all the available command options just do:

```bash
up42
```

To get a list of the available operations:

```bash
up42 -f list-operations
```

## 3. Perform a Pléiades full archive search

### 3.1 Searching

This search is made across immediately available images and also
images in cold storage that need to be warmed up to be obtained
(downloaded or streamed via WMTS).

```bash
up42 -f search -b search_params.json
```

Here is an example `search_params.json`:

```js
{
  "intersects": {
    "type": "Polygon",
    "coordinates":  [
          [
            [
              13.42855453491211,
              52.51261676798259
            ],
            [
              13.436279296875,
              52.51262982683484
            ],
            [
              13.436279296875,
              52.51525457735388
            ],
            [
              13.42855453491211,
              52.51525457735388
            ],
            [
              13.42855453491211,
              52.51261676798259
            ]
          ]
        ]
  },
  "limit": 100,
  "query": {
    "cloudCoverage": {
      "lte": 20
    },
    "processingLevel": {
      "IN": [
        "ALBUM",
        "SENSOR"
      ]
    },
    "dataBlock": {
      "in": [
        "oneatlas-pleiades-fullscene",
        "oneatlas-pleiades-aoiclipped"
      ]
    }
  },
  "datetime": "2016-01-01T00:00:00.000Z/.."
}
```

Where:

 * `processingLevel`: specifies **both** cold (`ALBUM`) and warm (immediately
   available images, `SENSOR`).

 * `dataBlock`: specifies which data blocks are targeted for the search. In this case
   only Pléiades data blocks.

The remainder fields in the JSON follow the
   [STAC](https://stacspec.org/STAC-api.html#operation/getSearchSTAC)
   specification.

If you want to have a nicely formatted output saved to a file do:

```bash
up42 -f search -b search_params.json | jq '.' > search_results.json
```

### 3.2 Inspect the search results

You can use `jq` to inspect the results.

 1. Get all scene IDs of `ARCHIVED` (cold storage images).
```bash
jq -r '.features[].properties.providerProperties as $p | if $p.productionStatus=="ARCHIVED" then $p.sourceIdentifier else empty end' search_results.json
```
 2. Get all images IDs that are `ARCHIVED` (col storage images): these IDs are used
    for ordering and getting the quicklooks.
```bash
jq -r '.features[].properties as $p | if $p.providerProperties.productionStatus=="ARCHIVED" then $p.id else empty end'
```
 3. Get all scene IDs of `ON_CLOUD` (immediately available) images.
```bash
jq -r '.features[].properties.providerProperties as $p | if $p.productionStatus=="IN_CLOUD" then $p.sourceIdentifier else empty end' search_results.json
```
 4. Get all images IDs that are `ON_CLOUD` (immediately available)
    images. These IDs are used for ordering and getting the quicklooks.
```bash
jq -r '.features[].properties as $p | if $p.providerProperties.productionStatus=="IN_CLOUD" then $p.id else empty end'
```

## Get the quicklooks for a given image

After obtaining the search results you can now get a low resolution
preview of an image listed in the search results. For that you need
the **image ID**. This is an unique identifier for a particular image.
