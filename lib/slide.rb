# Copyright (C) 2012-2018  Kouhei Sutou <kou@cozmixng.org>
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

require "tempfile"

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
  template("page_images(prefix, options)", "page-images.html.erb")
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
    @mini_image_width = 320
    @thumbnail_width = 200
    @mini_thumbnail_width = 100
  end

  def available?
    load
    return false if rubygems_user.nil?
    return false if @pdf.nil?
    true
  end

  def generate_html(author_dir_path)
    slide_dir_path = author_dir_path + name
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

  def name
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
    rubygems_user and name
  end

  def rubygems_url
    "https://rubygems.org/gems/#{u(gem_name)}"
  end

  def vimeo_id
    @config.vimeo_id
  end

  def have_vimeo_id?
    vimeo_id
  end

  def vimeo_url
    "https://vimeo.com/#{u(vimeo_id)}"
  end

  def youtube_id
    @config.youtube_id
  end

  def have_youtube_id?
    youtube_id
  end

  def youtube_url
    "https://www.youtube.com/watch?v=#{u(youtube_id)}"
  end

  def n_pages
    @pdf.n_pages
  end

  def pages
    @pdf.to_a
  end

  def generate_link_coords(page, link_mapping, mini: false)
    if mini
      image_width = @mini_image_width
    else
      image_width = @image_width
    end
    width, height = page.size
    width_ratio = image_width / width
    image_height = (image_width * (height / width)).ceil
    height_ratio = image_height / height
    x, y, w, h = link_mapping.area.to_a
    coords = [
      x * width_ratio,
      (height - y) * height_ratio,
      w * width_ratio,
      (height - h) * height_ratio,
    ]
    coords.collect(&:to_i).join(",")
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
      name == slide.name
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

  def mini_thumbnail_base_name
    "mini-#{thumbnail_base_name}"
  end

  def thumbnail_path
    "#{u(name)}/#{thumbnail_base_name}"
  end

  def mini_thumbnail_path
    "#{u(name)}/#{mini_thumbnail_base_name}"
  end

  def url
    "#{@author.url}#{u(name)}/"
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
    "#{@author.path}#{u(name)}/"
  end

  def hatena_bookmark_url
    url_without_scheme = url.gsub(/\Ahttps:\/\//, "s/")
    "https://b.hatena.ne.jp/entry/#{url_without_scheme}"
  end

  def slide_ratio_class_suffix
    case image_height
    when 360
      "-ratio-16-9"
    else
      ""
    end
  end

  def image_height
    compute_height(@pdf[0], @image_width)
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
      rescue GLib::Error
        @pdf_content = nil
        puts("Failed to parse PDF: #{path}: #{$!.class}: #{$!}")
      else
        break
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
      [
        ["", @image_width],
        ["mini-", @mini_image_width],
      ].each do |prefix, image_width|
        image_path = slide_dir_path + "#{prefix}#{i}.png"
        image_height = compute_height(page, image_width)
        save_page(page, image_width, image_height, image_path.to_s)
      end
    end
  end

  def generate_thumbnail(slide_dir_path)
    first_page = @pdf[0]
    [
      [thumbnail_base_name, @thumbnail_width],
      [mini_thumbnail_base_name, @mini_thumbnail_width],
    ].each do |base_name, thumbnail_width|
      image_path = slide_dir_path + base_name
      thumbnail_height = compute_height(first_page, thumbnail_width)
      save_page(first_page, thumbnail_width, thumbnail_height, image_path.to_s)
    end
  end

  def compute_height(page, width)
    page_width, page_height = page.size
    (width * (page_height / page_width)).ceil
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
