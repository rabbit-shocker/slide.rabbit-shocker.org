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

require "poppler"

require "rabbit/slide-configuration"

require_relative "gem-reader"
require_relative "environment"
require_relative "template"

class Slide
  include Rake::DSL
  include Template::HTMLHelper
  include GetText

  bindtextdomain("generator")

  extend Template::Renderer
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

  def base_name
    @config.base_name
  end

  def gem_name
    @config.gem_name
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
    "https://rubygems.org/gems/#{u(gem_name)}"
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

  def pages
    @pdf.pages
  end

  def page_texts
    pages.collect do |page|
      normalize_text(page.get_text)
    end
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
    "#{base_name}.pdf"
  end

  def thumbnail_base_name
    "thumbnail.png"
  end

  def thumbnail_path
    "#{u(id)}/#{thumbnail_base_name}"
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
    author_image_urls = [@author.profile_image_url].compact
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
