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
      "http://slide.rabbit-shocker.org/"
    end

    def logo_url
      "#{base_url}images/logo-square.png"
    end

    def gravatar_url(email)
      hash = Digest::MD5.hexdigest(email.downcase)
      "http://www.gravatar.com/avatar/#{hash}"
    end

    def format_presentation_date(date)
      h(date.strftime(_("%Y-%m-%d")))
    end

    def site_name
      "Rabbit Slide Show"
    end
  end
end
