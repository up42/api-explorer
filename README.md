# UP42 API Explorer

##  Introduction

The API explorer is a Bash script used by devrel/customer support team
at UP42 for two things mainly:

 1. Streamline customer support requests.
 2. Be the main tool to help us document the raw API (reference,
    tutorials and howtos).

## Disclaimer

As stated above this is mostly an _internal_ tool. We made it public
in the hopes if helping customers that:

 1. Want to explore the raw API because, for example, they are working
    on a product integration that is not written in Python and
    therefore they cannot use the [Python SDK](https://sdk.up42.com).

 2. It can be used for automating workflows with UP42 with almost 0
    code.

 However IT IS NOT a free software tool that is officially supported
 by UP42 for system integrations or UP42 API usage. This means that we
 welcome pull requests, but don't expect us to solve issues or features
 development that do not fall into one of the main goals described
 above.

 In a nutshell we hope this is useful for you, but YMMV.

For a complete UP42 SDK please refer to our [Python SDK](https://sdk.up42.com).

## Requirements

 + [Bash](https://en.wikipedia.org/wiki/Bash_(Unix_shell)).
 + [cURL](https://curl.haxx.se).
 + [jq](https://stedolan.github.io/jq/).
 + [jwt-cli](https://github.com/mike-engel/jwt-cli).
 + [GNU core utilities](https://www.gnu.org/software/coreutils/coreutils.html).
 + [uuid](http://www.ossp.org/pkg/lib/uuid/).

It assumes the presence of standard UNIX tools like `sed` and `AWK`.

## Usage

The real documentation for this tool is the [API
reference](https://docs.up42.com/api/index.html). There is a minimal
built-in helper functionality that can be invoked with:

```bash
./up42.sh -h
```

There are examples of request bodies for the POST/PUT requests in the
examples directory.

## Documentation

Please see the `tutorial.md` file for examples of script usage.

## Support

Please let us know at [support@up42.com](mailto:support@up42.com) if
you find any issue in using this tool to explore the UP42 API.
