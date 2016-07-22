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

require "rabbit/author-configuration"

require_relative "environment"
require_relative "template"

class Author
  include Rake::DSL
  include Template::HTMLHelper
  include GetText

  bindtextdomain("generator")

  extend Template::Renderer
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
    "https://slideshare.net/#{u(slideshare_user)}/"
  end

  def speaker_deck_user
    @config.speaker_deck_user
  end

  def have_speaker_deck_user?
    not speaker_deck_user.nil?
  end

  def speaker_deck_url
    "https://speakerdeck.com/u/#{u(speaker_deck_user)}/"
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

  def profile_image_url
    return nil if email.nil?
    gravatar_url(email)
  end

  def url
    "#{base_url}#{path}"
  end

  def page_image_urls
    urls = []
    urls << profile_image_url
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
