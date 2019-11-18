# -*- ruby -*-
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

require "exception_notification"
require "hashie"
require "json"
require "yaml"

class WebhookReceiver
  def initialize
  end

  def call(env)
    request = Rack::Request.new(env)
    process(request) if request.post?
    [200, {"Content-Type" => "text/plain"}, [""]]
  end

  private
  def process(request)
    data = request.body.read
    File.open(request_log_path, "w") do |request_log|
      request_log.puts(data)
    end
    gem_info = JSON.parse(data)
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
    Bundler.with_clean_env do
      pid = Process.spawn(env, update_sh, "60", options)
      Process.detach(pid)
    end
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

  def request_log_path
    File.join(base_dir, "tmp", "request.log")
  end
end

use Rack::ShowExceptions
use Rack::ContentType, "text/plain"
use Rack::ContentLength

email_yml = "email.yaml"
if File.exist?(email_yml)
  use ExceptionNotificatio::Rack,
      email: Hashie.symbolize_keys(YAML.load(File.read(email_yml)))
end

run WebhookReceiver.new
