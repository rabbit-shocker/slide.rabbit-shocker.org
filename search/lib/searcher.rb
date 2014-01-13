# -*- coding: utf-8 -*-
#
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
      @tags = @request["tags"] || []
      @tags = [@tags] if @tags.is_a?(String)
    end

    def search_slides
      query = @query.to_s.strip
      return [] if query.empty?
      @database.slides.select do |record|
        conditions = []
        conditions << (query_match_target(record) =~ query)
        conditions.concat(@tags.collect {|tag| record.tags =~ tag})
        conditions
      end
    end

    def query_match_target(record)
      record.match_target do |match_record|
        (match_record.title * 20000) |
          (match_record.author * 15000) |
          (match_record.author.label * 10000) |
          (match_record.description * 1000) |
          (match_record.page_texts)
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
      @tags = slides.group("tags")
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

    def current_query
      @current_query ||= @request["query"]
    end

    def current_tags
      @current_tags ||= @request["tags"] || []
    end

    def tag_path(tag)
      tag_key = tag["_key"]
      if @request.query_string.empty?
        "#{@request.path}?tags[]=#{tag_key}"
      else
        "#{@request.fullpath}&tags[]=#{tag_key}"
      end
    end

    def tag_link(tag)
      tag_key = tag["_key"]
      tag_label = h(tag.label)
      if current_tags.include?(tag_key)
        "#{tag_label} #{tag_clear_link(tag_key)}"
      else
        html_tag("a", {:href => tag_path(tag)}, tag_label)
      end
    end

    def tag_clear_link(tag)
      params = {}
      @request.params.each do |key, value|
        if key == "tags"
          value = value.dup
          value.delete(tag)
        end
        params[key] = value unless value.empty?
      end
      query_string = Rack::Utils.build_nested_query(params)
      tag_clear_link_path = "#{@request.path}?#{query_string}"
      tag_clear_link_attributes = {
        :href => tag_clear_link_path,
        :class => "tag-clear",
        :title => "Clear",
      }
      tag_clear_link = html_tag("a", tag_clear_link_attributes, "❌")
    end

    def snippeter
      @snipepter ||= create_snippeter
    end

    def snippet_width
      100
    end

    def create_snippeter(width=nil)
      open_tag = "<span class=\"keyword\">"
      close_tag = "</span>"
      options = {
        :normalize => true,
        :width => width || snippet_width,
        :html_escape => true,
      }
      snippeter = @slides.expression.snippet([open_tag, close_tag], options)
      snippeter ||= Groonga::Snippet.new(options)
      snippeter
    end

    def slide_snippets(slide)
      snippets = []
      snippets.concat(snippeter.execute(slide.page_texts.join(" ")))
      separator = "<span class=\"separator\">...</span>"
      snippets.collect do |snippet|
        normalized_snippet = snippet.strip
        if snippet.bytesize < snippet_width
          normalized_snippet
        else
          "#{separator}#{normalized_snippet}#{separator}"
        end
      end
    end

    def highlight(text)
      snippets = create_snippeter(text.bytesize).execute(text)
      if snippets.empty?
        h(text)
      else
        snippets.join("")
      end
    end
  end
end
