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

require "json"

class WebHookReceiver
  def initialize
  end

  def call(env)
    request = Rack::Request.new(env)
    process(request) if request.post?
    [200, {"Content-Type" => "text/plain"}, [""]]
  end

  private
  def process(request)
    gem_info = JSON.parse(request.body.read)
    return unless rabbit_slide_gem?(gem_info)
    update_html
  end

  def rabbit_slide_gem?(gem_info)
    gem_info["name"].start_with?("rabbit-slide-")
  end

  def update_html
    env = {}
    options = {
      :in => "/dev/null",
      [:out, :err] => [log_path, "w"],
    }
    Process.spawn(env, update_sh, options)
  end

  def base_dir
    File.dirname(__FILE__)
  end

  def update_sh
    File.join(base_dir, "..", "update.sh")
  end

  def log_path
    File.join(base_dir, "tmp", "log")
  end
end

use Rack::ShowExceptions
use Rack::ContentType, "text/plain"
use Rack::ContentLength

run WebHookReceiver.new
