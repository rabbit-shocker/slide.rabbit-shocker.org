# -*- ruby -*-
#
# Copyright (C) 2014-2015  Kouhei Sutou <kou@cozmixng.org>
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

source "https://rubygems.org/"

gem "rack"

gem "less"
gem "therubyracer"

gem "gettext"
gem "poppler"
gem "rroonga"

local_rabbit_dir = File.join(File.dirname(__FILE__), "..", "rabbit")
if File.exist?(local_rabbit_dir)
  gem "rabbit", :path => local_rabbit_dir
else
  gem "rabbit"
end
