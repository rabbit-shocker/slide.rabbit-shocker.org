#!/bin/sh
#
# Copyright (C) 2012-2019  Sutou Kouhei <kou@cozmixng.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

set -e

cd "$(dirname "$0")"

delay=$1
if [ -n "$delay" ]; then
    sleep "$delay"
fi

git pull --rebase --autostash
(cd ../rabbit && git pull --rebase --autostash)

PATH="/usr/local/bin:$PATH"

HTML_DIR=$(echo ~/public_html)

rm -f Gemfile.lock
bundle install

xvfb-run --auto-servernum \
    ruby -I ../rabbit/lib -S \
    rake gems:fetch gems:clean
xvfb-run --auto-servernum \
    ruby -I ../rabbit/lib -S \
    rake HTML_DIR=${HTML_DIR}

rack_applications="search webhook-receiver"
for rack_application in ${rack_applications}; do
    if [ -e "${HTML_DIR}/${rack_application}" ]; then
	continue;
    fi
    ln -s "${PWD}/${rack_application}/public" "${HTML_DIR}/${rack_application}"
done
