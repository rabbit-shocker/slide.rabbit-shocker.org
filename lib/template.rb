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

require "erb"
require "pathname"
require "digest/md5"

require "gettext"

require_relative "environment"

module Template
  module Renderer
    def template_dir_path
      Pathname(__FILE__).dirname.parent + "templates"
    end

    def template(name, base_path)
      path = template_dir_path + base_path
      erb = ERB.new(path.read, nil, "%-")
      erb.def_method(self, name, path.to_s)
    end

    def define_common_templates
      template("layout", "layout.html.erb")
      template("html_head", "html-head.html.erb")
      template("layout", "layout.html.erb")
      template("thumbnail_link(slide, author_path)",
               "slide-thumbnail-link.html.erb")
    end
  end

  module HTMLHelper
    include Environment
    include ERB::Util

    def base_url
      "https://slide.rabbit-shocker.org/"
    end

    def logo_url
      image_url("logo-square.png")
    end

    def gravatar_url(email)
      if email.nil?
        hash = "00000000000000000000000000000000"
      else
        hash = Digest::MD5.hexdigest(email.downcase)
      end
      "//www.gravatar.com/avatar/#{hash}"
    end

    def image_url(path)
      "#{base_url}images/#{path}"
    end

    def image_path(path)
      "#{top_path}images/#{path}"
    end

    def format_presentation_date(date)
      h(date.strftime(_("%Y-%m-%d")))
    end

    def current_query
      ""
    end

    def current_tags
      []
    end

    def html_tag(name, attributes, content=nil)
      open_tag = "<#{name}"
      attributes.each do |key, value|
        open_tag << " #{key}=\"#{h(value)}\""
      end
      open_tag << ">"
      if content.nil? and block_given?
        content = yield
      end
      close_tag = "</#{name}>"
      "#{open_tag}#{content}#{close_tag}"
    end

    def site_name
      "Rabbit Slide Show"
    end
  end
end
