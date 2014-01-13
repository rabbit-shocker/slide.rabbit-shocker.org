# -*- ruby -*-
#
# Copyright (C) 2014  Kouhei Sutou <kou@cozmixng.org>
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

require "pathname"

require "bundler/setup"

base_path = Pathname(__FILE__).dirname.parent.expand_path
$LOAD_PATH.unshift((base_path + "lib").to_s)

require "database"
require "environment"

$LOAD_PATH.unshift((base_path + "search" + "lib").to_s)

require "searcher"

use Rack::ShowExceptions
use Rack::ContentType, "text/plain"
use Rack::ContentLength

searcher = Searcher.new(Database.new)

if Environment.production?
  run searcher
else
  root_dir = File.expand_path("../html")
  use Rack::Static, :urls => {"/" => "index.html"},
                    :root => root_dir
  use Rack::Static, :urls => ["/a", "/f", "/i", "/j", "/st"],
                    :root => root_dir
  run Rack::URLMap.new("/search" => searcher)
end
