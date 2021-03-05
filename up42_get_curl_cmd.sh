#!/bin/bash
#!/bin/bash

# up42_get_curl_cmd.sh --- Wrapper script to echo cURL commands ocurring in the API explorer.

# Copyright (C) 2021 UP42 GmbH

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

## Please set the environment variable UP42SH_PATH to point to the
## location of the up42.sh script with:
## export UP42SH_PATH=/path/to/your/up42.sh
UP42_SCRIPT=${UP42SH_PATH:-$HOME/up42/api-explorer/up42.sh}

$UP42_SCRIPT "$@" -D 2>&1 | sed -n 's/'"'"'Authorization: Bearer [[:alnum:][:punct:]]*/"Authorization: Bearer $UP42_TOKEN"/p' | sed 's#/usr/bin/##'
