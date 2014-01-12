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

require "template"

class Searcher
  def initialize(database)
    @database = database
  end

  def call(env)
    request = Rack::Request.new(env)
    response = Rack::Response.new
    processor = Processor.new(request, response, @database)
    processor.process
    response.finish
  end

  class Processor
    def initialize(request, response, database)
      @request = request
      @response = response
      @database = database
    end

    def process
      parse_query
      slides = search_slides
      @response.headers["Content-Type"] = "text/html"
      renderer = Renderer.new(@request, slides)
      @response.write(renderer.render)
    end

    private
    def parse_query
      @query = @request["query"]
    end

    def search_slides
      query = @query.to_s.strip
      return [] if query.empty?
      @database.slides.select do |record|
        record.page_texts =~ query
      end
    end
  end

  class Renderer
    include Template::HTMLHelper
    include GetText

    extend Template::Renderer
    define_common_templates
    template("header", "header.html.erb")
    template("content", "search.html.erb")

    def initialize(request, slides)
      @request = request
      @slides = slides
    end

    def render
      layout do
        content
      end
    end

    private
    def page_title
      "Search"
    end

    def top_path
      components = @request.path.split("/")
      n_components = components.size - 1
      n_components += 1 if @request.path.end_with?("/")
      if n_components == 1
        "./"
      else
        "../" * n_components
      end
    end

    def author_path(author)
      "#{top_path}authors/#{author.key}/"
    end

    def url
      "#{base_url}search/"
    end

    def description
      "Search result"
    end

    def page_image_urls
      []
    end

    def snippeter
      @snipepter ||= create_snippeter
    end

    def snippet_width
      100
    end

    def create_snippeter
      open_tag = "<span class=\"keyword\">"
      close_tag = "</span>"
      options = {
        :normalize => true,
        :width => snippet_width,
        :html_escape => true,
      }
      snippeter = @slides.expression.snippet([open_tag, close_tag], options)
      snippeter ||= Groonga::Snippet.new(options)
      snippeter
    end

    def slide_snippets(slide)
      snippets = []
      # snippets.concat(snippeter.execute(slide.name))
      # snippets.concat(snippeter.execute(slide.base_name))
      # snippets.concat(snippeter.execute(slide.title))
      # snippets.concat(snippeter.execute(slide.description))
      snippets.concat(snippeter.execute(slide.page_texts.join(" ")))
      # snippets.concat(snippeter.execute(slide.tags.collect(&:label).join(" ")))
      # snippets.concat(snippeter.execute(slide.author.key))
      # snippets.concat(snippeter.execute(slide.author.name))
      separator = "<span class=\"separator\">...</span>"
      snippets.collect do |snippet|
        normalized_snippet = snippet.strip
        "#{separator}#{normalized_snippet}#{separator}"
      end
    end
  end
end
