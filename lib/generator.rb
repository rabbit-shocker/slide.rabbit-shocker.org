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

require "date"
require "pathname"

require "poppler"

require "rabbit/author-configuration"
require "rabbit/slide-configuration"

require_relative "loader"
require_relative "environment"
require_relative "template"

class Generator
  include Rake::DSL
  include Environment

  def initialize(html_dir_path)
    @assets_dir_path = Pathname("assets")
    @html_dir_path = Pathname(html_dir_path)
    loader = Loader.new
    loader.load
    @authors = loader.authors
  end

  def generate
    copy_assets
    generate_author_html
    generate_index_html
    generate_robots_txt
  end

  private
  def copy_assets
    if production?
      cp_r("#{@assets_dir_path}/.", @html_dir_path.to_s)
    else
      mkdir_p(@html_dir_path.to_s)
      @assets_dir_path.each_child do |child|
        destination = @html_dir_path + child.basename
        rm_rf(destination.to_s)
        ln_s(child.relative_path_from(@html_dir_path).to_s,
             destination.to_s)
      end
    end
  end

  def generate_author_html
    @authors.each do |author|
      author_dir_path = @html_dir_path + "authors" + author.rubygems_user
      author.loading do
        author.generate_html(author_dir_path)
        author.slides.each do |slide|
          slide.generate_html(author_dir_path)
        end
      end
    end
  end

  def generate_index_html
    top_page = TopPage.new(@authors)
    begin
      @authors.each(&:load_pdf)
      top_page.generate_html(@html_dir_path)
    ensure
      @authors.each(&:unload_pdf)
    end
  end

  def generate_robots_txt
    (@html_dir_path + "robots.txt").open("w") do |robots_txt|
      robots_txt.puts(<<-ROBOTS)
User-agent: *
Disallow: /search/
      ROBOTS
    end
  end

  class TopPage
    include Rake::DSL
    include Template::HTMLHelper
    include GetText

    bindtextdomain("generator")

    extend Template::Renderer
    define_common_templates
    template("content", "top.html.erb")

    def initialize(authors)
      @authors = authors
    end

    def generate_html(html_dir_path)
      mkdir_p(html_dir_path.to_s)
      generate_index_html(html_dir_path)
    end

    def to_html
      layout do
        content
      end
    end

    def page_title
      site_name
    end

    def description
      _("Share your slides created by Rabbit! It's showtime! Love it?") # "
    end

    def slides
      @authors.inject([]) do |result, author|
        result + author.slides
      end
    end

    def new_slides
      sorted_slides = slides.sort_by do |slide|
        -slide.spec.date.to_i
      end
      sorted_slides[0, 9]
    end

    def top_path
      ""
    end

    def url
      base_url
    end

    def page_image_urls
      [logo_url]
    end

    private
    def generate_index_html(html_dir_path)
      (html_dir_path + "index.html").open("w") do |top_html|
        top_html.print(to_html)
      end
    end
  end
end
