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

require "fileutils"
require "pathname"

require "groonga"

class Database
  attr_reader :context
  def initialize
    @context = Groonga::Context.new
    ensure_database
  end

  def close
    @context.database.close
    @context.close
    @context = nil
  end

  def authors
    @context["Authors"]
  end

  def slides
    @context["Slides"]
  end

  def licenses
    @context["Licenses"]
  end

  def tags
    @context["Tags"]
  end

  private
  def database_path
    base_path = Pathname(__FILE__).dirname.parent.expand_path
    base_path + "database" + "slide.db"
  end

  def ensure_database
    @database = nil
    if database_path.exist?
      @database = @context.open_database(database_path.to_s)
      if need_rebuild_schema?
        @database.remove
        @database = nil
      end
    end

    if @database.nil?
      FileUtils.mkdir_p(database_path.dirname.to_s)
      @database = @context.create_database(database_path.to_s)
    end

    define_schema
  end

  def define_schema
    schema = Schema.new(@context)
    schema.define
  end

  def need_rebuild_schema?
    meta_data = @context["MetaData"]
    return true if meta_data.nil?

    schema_version = meta_data["schema-version"]
    return true if schema_version.nil?
    return true if schema_version.content != Schema::VERSION

    false
  end

  class Schema
    VERSION = "1"

    def initialize(context)
      @context = context
    end

    def define
      define_schema
      set_schema_version
    end

    private
    def define_schema
      Groonga::Schema.define(:context => @context) do |schema|
        schema.create_table("MetaData",
                            :type => :hash,
                            :key_type => :short_text) do |table|
          table.text("content")
        end

        schema.create_table("Licenses",
                            :type => :hash,
                            :key_type => :short_text) do |table|
          table.short_text("label")
          table.text("url")
        end

        schema.create_table("Tags",
                            :type => :patricia_trie,
                            :key_type => :short_text,
                            :normalizer => "NormalizerAuto") do |table|
          table.short_text("label")
        end

        schema.create_table("Authors",
                            :type => :hash,
                            :key_type => :short_text) do |table|
          table.short_text("name")
          table.short_text("label")
          table.short_text("email")
        end

        schema.create_table("Slides",
                            :type => :hash,
                            :key_type => :short_text) do |table|
          table.short_text("name")
          table.short_text("base_name")
          table.text("title")
          table.text("description")
          table.text("page_texts", :type => :vector)
          table.time("presentation_date")
          table.short_text("thumbnail_path")
          table.reference("licenses", "Licenses", :type => :vector)
          table.reference("tags", "Tags", :type => :vector)
          table.uint32("n_pages")
          table.short_text("slideshare_id")
          table.short_text("speaker_deck_id")
          table.short_text("ustream_id")
          table.short_text("vimeo_id")
          table.short_text("youtube_id")
          table.reference("author", "Authors")
        end

        schema.create_table("Terms",
                            :type => :patricia_trie,
                            :key_type => :short_text,
                            :default_tokenizer => "TokenBigramSplitSymbolAlpha",
                            :normalizer => "NormalizerAuto") do |table|
          table.index("Authors.name")
          table.index("Authors.label")
          table.index("Slides.title")
          table.index("Slides.description")
          table.index("Slides.page_texts")
        end

        schema.create_table("Words",
                            :type => :patricia_trie,
                            :key_type => :short_text,
                            :normalizer => "NormalizerAuto") do |table|
          table.index("Slides.name")
          table.index("Slides.base_name")
        end

        schema.change_table("Authors") do |table|
          table.index("Slides.author")
        end

        schema.change_table("Licenses") do |table|
          table.index("Slides.licenses")
        end

        schema.change_table("Tags") do |table|
          table.index("Slides.tags")
        end
      end
    end

    def set_schema_version
      meta_data = @context["MetaData"]
      meta_data.add("schema-version", :content => VERSION)
    end
  end
end
