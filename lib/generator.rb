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

require "time"
require "date"
require "erb"
require "pathname"
require "digest/md5"

require "gettext"
require "poppler"

require "rabbit/author-configuration"
require "rabbit/slide-configuration"

require_relative "gem-reader"

class Generator
  module Environment
    def production?
      ENV["PRODUCTION"] == "true"
    end
  end

  include Rake::DSL
  include Environment

  def initialize(html_dir_path)
    @gems_dir_path = Pathname("gems")
    @assets_dir_path = Pathname("assets")
    @html_dir_path = Pathname(html_dir_path)
  end

  def generate
    copy_assets
    generate_author_html
    generate_index_html
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
    collect_slides
    @authors.each do |rubygems_user, author|
      author_dir_path = @html_dir_path + "authors" + rubygems_user
      mkdir_p(author_dir_path.to_s)
      author.generate_html(author_dir_path)
      author.slides.each do |slide|
        slide.generate_html(author_dir_path)
      end
    end
  end

  def generate_index_html
    top_page = TopPage.new(@authors.values)
    top_page.generate_html(@html_dir_path)
  end

  def collect_slides
    @authors = {}
    @gems_dir_path.children.each do |slide_gem_path|
      slide = Slide.new(slide_gem_path)
      next unless slide.available?

      rubygems_user = slide.rubygems_user
      @authors[rubygems_user] ||= Author.new
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
    include ERB::Util
    include Environment

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

  class TopPage
    include Rake::DSL
    include HTMLHelper
    include GetText

    bindtextdomain("generator")

    extend TemplateRenderer
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

  class Author
    include Rake::DSL
    include HTMLHelper
    include GetText

    bindtextdomain("generator")

    extend TemplateRenderer
    define_common_templates
    template("header", "header.html.erb")
    template("content", "author.html.erb")

    attr_reader :config, :tags
    def initialize
      @slides = {}
      @config = Rabbit::AuthorConfiguration.new
      @tags = {}
    end

    def slides
      @slides.values.sort_by do |slide|
        presentation_date = slide.presentation_date || Time.at(0)
        -presentation_date.to_i
      end
    end

    def add_slide(slide)
      slide.author = self
      existing_slide = @slides[slide.config.id]
      if existing_slide and existing_slide.config.version >= slide.config.version
        return
      end
      @slides[slide.config.id] = slide
      extract_slide_config(slide)
    end

    def generate_html(author_dir_path)
      mkdir_p(author_dir_path.to_s)
      generate_index_html(author_dir_path)
    end

    def to_html
      layout do
        content
      end
    end

    def top_path
      "../../"
    end

    def name
      @config.name
    end

    def label
      name || rubygems_user
    end

    def email
      @config.email
    end

    def page_title
      [label, site_name].join(" - ")
    end

    def description
      _("%{author}'s slides") % {:author => label}
    end

    def slideshare_user
      @config.slideshare_user
    end

    def have_slideshare_user?
      not slideshare_user.nil?
    end

    def slideshare_url
      "http://slideshare.net/#{u(slideshare_user)}/"
    end

    def speaker_deck_user
      @config.speaker_deck_user
    end

    def have_speaker_deck_user?
      not speaker_deck_user.nil?
    end

    def speaker_deck_url
      "http://speakerdeck.com/u/#{u(speaker_deck_user)}/"
    end

    def rubygems_user
      @config.rubygems_user
    end

    def have_rubygems_user?
      not rubygems_user.nil?
    end

    def rubygems_url
      "https://rubygems.org/profiles/#{u(rubygems_user)}"
    end

    def image_url
      return nil if email.nil?
      gravatar_url(email)
    end

    def url
      "#{base_url}#{path}"
    end

    def page_image_urls
      urls = []
      urls << image_url
      slides.each do |slide|
        urls << slide.image_urls.first
      end
      urls << logo_url
      urls.compact
    end

    def path
      "authors/#{u(rubygems_user)}/"
    end

    private
    def extract_slide_config(slide)
      @config.merge!(slide.config.author.to_hash)
      slide.config.tags.each do |tag|
        @tags[tag] ||= 0
        @tags[tag] += 1
      end
    end

    def generate_index_html(author_dir_path)
      (author_dir_path + "index.html").open("w") do |author_html|
        author_html.print(to_html)
      end
    end
  end

  class Slide
    include Rake::DSL
    include HTMLHelper
    include GetText

    bindtextdomain("generator")

    extend TemplateRenderer
    define_common_templates
    template("header", "header.html.erb")
    template("content", "slide.html.erb")
    template("skeleton", "skeleton.html.erb")
    template("viewer", "slide-viewer.html.erb")
    template("embed_viewer_html", "embed-viewer-html.html.erb")

    attr_reader :spec, :config
    attr_accessor :author
    def initialize(gem_path)
      @gem_path = gem_path
      @spec = nil
      @config = Rabbit::SlideConfiguration.new
      @author = nil
      @pdf = nil
      @image_width = 640
      @image_height = 480
      @thumbnail_width = 200
      @thumbnail_height = 150
    end

    def available?
      load
      return false if rubygems_user.nil?
      return false if @pdf.nil?
      true
    end

    def generate_html(author_dir_path)
      slide_dir_path = author_dir_path + id
      mkdir_p(slide_dir_path.to_s)
      generate_index_html(slide_dir_path)
      generate_viewer_html(slide_dir_path)
      generate_pdf(slide_dir_path)
      generate_images(slide_dir_path)
      generate_thumbnail(slide_dir_path)
    end

    def to_html
      layout do
        content
      end
    end

    def top_path
      "../#{@author.top_path}"
    end

    def id
      @config.id
    end

    def page_title
      [title, @author.label, site_name].join(" - ")
    end

    def title
      @spec.summary
    end

    def description
      @spec.description
    end

    def presentation_date
      date = @config.presentation_date
      return nil if date.nil?
      return date.to_time if date.respond_to?(:to_time)

      begin
        Time.parse(date)
      rescue ArgumentError
        nil
      end
    end

    def licenses
      @config.licenses
    end

    def slideshare_user
      @author.slideshare_user
    end

    def slideshare_id
      @config.slideshare_id
    end

    def have_slideshare_id?
      slideshare_user and slideshare_id
    end

    def slideshare_url
      "#{@author.slideshare_url}#{u(slideshare_id)}"
    end

    def speaker_deck_user
      @author.speaker_deck_user
    end

    def speaker_deck_id
      @config.speaker_deck_id
    end

    def have_speaker_deck_id?
      speaker_deck_user and speaker_deck_id
    end

    def speaker_deck_url
      "#{@author.speaker_deck_url}p/#{u(speaker_deck_id)}"
    end

    def rubygems_user
      @config.author.rubygems_user
    end

    def have_rubygems_id?
      rubygems_user and id
    end

    def rubygems_url
      "https://rubygems.org/gems/#{u(@config.gem_name)}"
    end

    def ustream_id
      @config.ustream_id
    end

    def have_ustream_id?
      ustream_id
    end

    def ustream_url
      "http://www.ustream.tv/recorded/#{u(ustream_id)}"
    end

    def vimeo_id
      @config.vimeo_id
    end

    def have_vimeo_id?
      vimeo_id
    end

    def vimeo_url
      "http://vimeo.com/#{u(vimeo_id)}"
    end

    def youtube_id
      @config.youtube_id
    end

    def have_youtube_id?
      youtube_id
    end

    def youtube_url
      "http://www.youtube.com/watch?v=#{u(youtube_id)}"
    end

    def n_pages
      @pdf.size
    end

    def tags
      @config.tags
    end

    def other_slides
      @author.slides.reject do |slide|
        id == slide.id
      end
    end

    def tweet_text
      text = "#{@author.label}: #{title}"
      hash_tags = tags.collect {|tag| "\##{tag}"}
      [text, *hash_tags].join(" ")
    end

    def pdf_base_name
      "#{@config.base_name}.pdf"
    end

    def thumbnail_base_name
      "thumbnail.png"
    end

    def thumbnail_path
      "#{h(id)}/#{thumbnail_base_name}"
    end

    def url
      "#{@author.url}#{h(id)}/"
    end

    def image_urls
      urls = []
      n_pages.times do |i|
        urls << "#{url}#{i}.png"
      end
      urls
    end

    def page_image_urls
      author_image_urls = [@author.image_url].compact
      image_urls + author_image_urls + [logo_url]
    end

    def viewer_url
      "#{url}viewer.html"
    end

    def path
      "#{@author.path}#{h(id)}/"
    end

    def hatena_bookmark_url
      url_without_scheme = url.gsub(/\Ahttp:\/\//, "")
      "http://b.hatena.ne.jp/entry/#{url_without_scheme}"
    end

    private
    def load
      return unless @gem_path.exist?

      gem_reader = GemReader.new(@gem_path.to_s)
      @spec = gem_reader.spec

      gem_reader.each do |path, content|
        if path == "config.yaml"
          @config.merge!(YAML.load(content))
          break
        end
      end

      @pdf_content = nil
      gem_reader.each do |path, content|
        next unless path.start_with?("pdf/")
        @pdf_content = content
        begin
          @pdf = Poppler::Document.new(@pdf_content)
          break
        rescue GLib::Error
          @pdf_content = nil
          puts("Failed to parse PDF: #{path}: #{$!.class}: #{$!}")
        end
      end
    end

    def generate_index_html(slide_dir_path)
      (slide_dir_path + "index.html").open("w") do |slide_html|
        slide_html.print(to_html)
      end
    end

    def generate_viewer_html(slide_dir_path)
      (slide_dir_path + "viewer.html").open("w") do |slide_html|
        slide_html.print(viewer_html)
      end
    end

    def generate_pdf(slide_dir_path)
      (slide_dir_path + pdf_base_name).open("w:ascii-8bit") do |slide_pdf|
        slide_pdf.print(@pdf_content)
      end
    end

    def generate_images(slide_dir_path)
      @pdf.each_with_index do |page, i|
        image_path = slide_dir_path + "#{i}.png"
        save_page(page, @image_width, @image_height, image_path.to_s)
      end
    end

    def generate_thumbnail(slide_dir_path)
      image_path = slide_dir_path + thumbnail_base_name
      save_page(@pdf[0], @thumbnail_width, @thumbnail_height, image_path.to_s)
    end

    def normalize_text(text)
      text.gsub(/\uFFFD/, " ")
    end

    def save_page(page, image_width, image_height, output_file_name)
      Cairo::ImageSurface.new(:argb32, image_width, image_height) do |surface|
        Cairo::Context.new(surface) do |context|
          context.set_source_rgb(1, 1, 1)
          context.rectangle(0, 0, image_width, image_height)
          context.fill

          width, height = page.size
          x_scale = image_width / width.to_f
          y_scale = image_height / height.to_f
          context.scale(x_scale, y_scale)
          context.render_poppler_page(page)
          surface.write_to_png(output_file_name)
        end
      end
    end

    def viewer_html
      skeleton do
        viewer
      end
    end
  end
end
