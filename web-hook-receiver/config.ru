# -*- ruby -*-
#
# Copyright (C) 2012  Kouhei Sutou <kou@cozmixng.org>
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

class WebHookReceiver
  def initialize
  end

  def call(env)
    [200, {"Content-Type" => "text/plain"}, [""]]
  end
end

use Rack::ShowExceptions
use Rack::ContentType, "text/plain"
use Rack::ContentLength

run WebHookReceiver.new
