# Copyright (C) 2014  Kouhei Sutou <kou@cozmixng.org>
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

require_relative "database"
require_relative "loader"

class Indexer
  def initialize(database)
    @database = database
  end

  def index
    loader = Loader.new
    loader.load
    authors = loader.authors
    authors.each do |author|
      index_author(author)
    end
  end

  private
  def index_author(author)
    authors = @database.authors
    author_record = authors.add(author.rubygems_user)
    author_record.name  = author.name
    author_record.label = author.label
    author_record.email = author.email
    author.slides.each do |slide|
      index_slide(slide)
    end
  end

  def index_slide(slide)
    slides = @database.slides
    slide_record = slides.add(slide.gem_name)
    slide_record.name              = slide.name
    slide_record.base_name         = slide.base_name
    slide_record.title             = slide.title
    slide_record.description       = slide.description
    slide_record.page_texts        = slide.page_texts
    slide_record.presentation_date = slide.presentation_date
    slide_record.thumbnail_path    = slide.thumbnail_path
    slide_record.licenses          = index_licenses(slide.licenses)
    slide_record.tags              = index_tags(slide.tags)
    slide_record.n_pages           = slide.n_pages
    slide_record.slideshare_id     = slide.slideshare_id
    slide_record.speaker_deck_id   = slide.speaker_deck_id
    slide_record.vimeo_id          = slide.vimeo_id
    slide_record.youtube_id        = slide.youtube_id
    slide_record.author            = slide.author.rubygems_user
  end

  def index_licenses(licenses)
    licenses_table = @database.licenses
    licenses.collect do |license|
      license = normalize_license(license)
      licenses_table.add(license,
                         :label => license,
                         :url => license_url(license))
    end
  end

  def index_tags(tags)
    tags_table = @database.tags
    tags.collect do |tag|
      tag = normalize_tag(tag)
      tags_table.add(tag, :label => tag)
    end
  end

  def normalize_license(license)
    case license
    when /\A(.?GPL)v?(\d(?:\.\d)?)( or later)?\z/i
      family = $1
      version = $2
      or_later = $3
      normalize_license_gpl(family, version, or_later)
    else
      license
    end
  end

  def normalize_license_gpl(family, version, or_later)
    if or_later
      or_later_mark = "+"
    else
      or_later_mark = ""
    end
    "#{family}v#{version}#{or_later_mark}"
  end

  def license_url(license)
    case license
    when /\A(.?GPL)v(\d(?:\.\d)?)/
      family = $1
      version = $2
      license_url_gpl(family, version)
    else
      nil
    end
  end

  def license_url_gpl(family, version)
    normalized_family = family.downcase
    if /\./ =~ version
      normalized_version = version
    else
      normalized_version = "#{version}.0"
    end

    if version == "3.0"
      "http://www.gnu.org/licenses/#{normalized_family}.html"
    else
      base_url = "http://www.gnu.org/licenses/old-licenses/"
      "#{base_url}#{normalized_family}-#{normalized_version}.html"
    end
  end

  def normalize_tag(tag)
    tag
  end
end
