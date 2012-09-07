# Copyright (C) 2012  Kouhei Sutou <kou@cozmixng.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "erb"
require "pathname"
require "digest/md5"

require "rubygems/format"

require "poppler"

require "rabbit/slide-configuration"

class Generator
  include Rake::DSL

  def initialize
    @gems_dir_path = Pathname("gems")
    @assets_dir_path = Pathname("assets")
    @html_dir_path = Pathname("html")
  end

  def generate
    rm_rf(@html_dir_path.to_s)
    copy_assets
    generate_slide_html
  end

  private
  def copy_assets
    cp_r("#{@assets_dir_path}/.", @html_dir_path.to_s)
  end

  def generate_slide_html
    collect_slides
    @authors.each do |rubygems_user, author|
      author_dir_path = @html_dir_path + rubygems_user
      mkdir_p(author_dir_path.to_s)
      author.slides.each do |slide_id, slide|
        slide.generate_html(author_dir_path)
      end
      author_index_html_path = author_dir_path + "index.html"
    end
  end

  def collect_slides
    @authors = {}
    @gems_dir_path.children.each do |slide_gem_path|
      slide = Slide.new(slide_gem_path)
      next unless slide.available?

      rubygems_user = slide.config.author.rubygems_user
      @authors[rubygems_user] ||= Author.new(rubygems_user)
      author = @authors[rubygems_user]
      author.add_slide(slide)
    end
  end

  module TemplateRenderer
    def template_dir_path
      Pathname(__FILE__).dirname.parent + "templates"
    end

    def template(name, base_path)
      path = template_dir_path + base_path
      erb = ERB.new(path.read, "-")
      erb.def_method(self, name, path.to_s)
    end
  end

  module HTMLHelper
    include ERB::Util

    def gravatar_url(email)
      hash = Digest::MD5.hexdigest(email.downcase)
      "http://www.gravatar.com/avatar/#{hash}"
    end
  end

  class Author
    attr_reader :rubygems_user, :slides
    def initialize(rubygems_user)
      @rubygems_user = rubygems_user
      @slides = {}
    end

    def add_slide(slide)
      existing_slide = @slides[slide.config.id]
      if existing_slide and existing_slide.config.version >= slide.config.version
        return
      end
      @slides[slide.config.id] = slide
    end
  end

  class Slide
    include Rake::DSL
    include HTMLHelper

    extend TemplateRenderer
    template("layout", "layout.html.erb")
    template("content", "slide.html.erb")

    attr_reader :spec, :config
    def initialize(gem_path)
      @gem_path = gem_path
      @spec = nil
      @config = Rabbit::SlideConfiguration.new
      @pdf = nil
      @image_width = 640
      @image_height = 480
    end

    def available?
      load
      return false if @config.author.rubygems_user.nil?
      return false if @pdf.nil?
      true
    end

    def generate_html(author_dir_path)
      slide_dir_path = author_dir_path + id
      mkdir_p(slide_dir_path.to_s)
      generate_index_html(slide_dir_path)
      generate_pdf(slide_dir_path)
      generate_images(slide_dir_path)
    end

    def to_html
      layout do
        content
      end
    end

    def top_path
      "../../"
    end

    def id
      @config.id
    end

    def title
      @spec.summary
    end

    def pdf_base_name
      "#{id}.pdf"
    end

    private
    def load
      return unless @gem_path.exist?

      @format = Gem::Format.from_file_by_path(@gem_path.to_s)
      @spec = @format.spec

      @format.file_entries.each do |info, content|
        if info["path"] == "config.yaml"
          @config.merge!(YAML.load(content))
          break
        end
      end

      @pdf_content = nil
      @format.file_entries.each do |info, content|
        if info["path"] == "pdf/#{pdf_base_name}"
          @pdf_content = content
          break
        end
      end

      @pdf = Poppler::Document.new(@pdf_content) if @pdf_content
    end

    def generate_index_html(slide_dir_path)
      (slide_dir_path + "index.html").open("w") do |slide_html|
        slide_html.print(to_html)
      end
    end

    def generate_pdf(slide_dir_path)
      (slide_dir_path + pdf_base_name).open("w:ascii-8bit") do |slide_pdf|
        slide_pdf.print(@pdf)
      end
    end

    def generate_images(slide_dir_path)
      @pdf.each_with_index do |page, i|
        width, height = page.size
        Cairo::ImageSurface.new(:argb32,
                                @image_width, @image_height) do |surface|
          Cairo::Context.new(surface) do |context|
            context.set_source_rgb(1, 1, 1)
            context.rectangle(0, 0, @image_width, @image_height)
            context.fill

            scale = @image_width / width.to_f
            context.scale(scale, scale)
            context.render_poppler_page(page)
            surface.write_to_png((slide_dir_path + "#{i}.png").to_s)
          end
        end
      end
    end
  end
end
