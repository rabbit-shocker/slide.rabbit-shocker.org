#!/bin/sh
#
# Copyright (C) 2012-2014  Kouhei Sutou <kou@cozmixng.org>
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

base_dir=`dirname $0`
cd $base_dir

delay=$1
if [ -n "$delay" ]; then
    sleep "$delay"
fi

git pull --rebase
(cd ../rabbit && git pull --rebase)

PATH="/var/lib/gems/1.9.1/bin:$PATH"

HTML_DIR=$(echo ~/public_html)

rm -f Gemfile.lock
xvfb-run --auto-servernum \
    ruby1.9.1 -I ../rabbit/lib -S \
    rake gems:fetch gems:clean
xvfb-run --auto-servernum \
    ruby1.9.1 -I ../rabbit/lib -S \
    rake HTML_DIR=${HTML_DIR}

rack_applications="search web-hook-receiver"
for rack_application in ${rack_applications}; do
    if [ -e "${HTML_DIR}/${rack_application}" ]; then
	continue;
    fi
    ln -s "${PWD}/${rack_application}/public" "${HTML_DIR}/${rack_application}"
done
