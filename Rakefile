# -*- ruby -*-
#
# Copyright (C) 2012-2019  Sutou Kouhei <kou@cozmixng.org>
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

require "rubygems/remote_fetcher"
require "rake/clean"

require "bundler/setup"

require "less"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "lib"))

require "generator"
require "indexer"

task :default => :generate

namespace :css do
  generated_css_paths = []
  Dir.glob("assets/stylesheets/slide.less").each do |less_path|
    css_path = less_path.gsub(/\.less\Z/, ".css")
    file css_path => less_path do |task|
      parser = Less::Parser.new(:filename => less_path)
      tree = parser.parse(File.read(less_path))
      css = tree.to_css
      File.open(css_path, "w") do |css_output|
        css_output.puts(css)
      end
    end
    generated_css_paths << css_path
  end
  CLOBBER.concat(generated_css_paths)
  task :generate => generated_css_paths
end

namespace :image do
  generated_images = []
  Dir.glob("assets/images/go-*.svg").each do |go_svg|
    go_mini_png = go_svg.gsub(/\.svg\z/, "-mini.png")
    file go_mini_png => go_svg do |task|
      sh("inkscape",
         "--export-png=#{go_mini_png}",
         "--export-width=16",
         "--export-height=16",
         "--export-background-opacity=0",
         go_svg)
    end
    generated_images << go_mini_png
  end
  CLOBBER.concat(generated_images)
  task :generate => generated_images
end

desc "Create index for search"
task :index do
  database = Database.new
  indexer = Indexer.new(database)
  indexer.index
  database.close
  touch("search/tmp/restart.txt")
end

namespace :generate do
  dependencies = ["css:generate", "image:generate"]
  html_dir = ENV["HTML_DIR"] || "html"

  desc "Generate HTML for development environment"
  task :development => dependencies do
    generator = Generator.new(html_dir)
    generator.generate
  end

  desc "Generate HTML for production environment"
  task :production => dependencies do
    ENV["PRODUCTION"] = "true"
    generator = Generator.new(html_dir)
    generator.generate
  end
end

desc "Generate HTML for production environment and create index for search"
task :generate => ["generate:production", "index"]

@gems_dir = "gems"

def download_gem(spec, source_uri=nil)
  source_uri ||= Gem.sources.first

  if spec.respond_to?(:cache_file)
    gem_base_name = File.basename(spec.cache_file)
  else
    gem_base_name = spec.file_name
  end
  gem_path = File.join(@gems_dir, gem_base_name)
  return if File.exist?(gem_path)

  tmp_dir = "tmp"
  rm_rf(tmp_dir)
  mkdir_p(tmp_dir)

  remote_fetcher = Gem::RemoteFetcher.fetcher
  remote_fetcher.download(spec, source_uri, tmp_dir)
  downloaded_gem_path = File.join(tmp_dir, "cache", gem_base_name)

  mkdir_p(@gems_dir)
  mv(downloaded_gem_path, gem_path)

  rm_rf(tmp_dir)
end

def download_latest_gems(name_or_pattern)
  if name_or_pattern.is_a?(Regexp)
    pattern = name_or_pattern
    dependency = Gem::Deprecate.skip_during do
      Gem::Dependency.new(pattern)
    end
  else
    name = name_or_pattern
    dependency = Gem::Dependency.new(name)
  end
  spec_fetcher = Gem::SpecFetcher.fetcher
  if spec_fetcher.respond_to?(:search_for_dependency)
    tuples, = spec_fetcher.search_for_dependency(dependency)
    spec_and_source_uris = tuples.collect do |name_tuple, source|
      [source.fetch_spec(name_tuple), source.uri]
    end
  else
    spec_and_source_uris = spec_fetcher.fetch(dependency)
  end
  spec_and_source_uris.each do |spec, source_uri|
    download_gem(spec, source_uri)
  end
end

namespace :gems do
  desc "Fetch all slide gems"
  task :fetch do
    download_latest_gems(/\Arabbit-slide-/)
  end

  desc "Update existing slide gems"
  task :update do
    updated_gems = {}
    Dir.glob(File.join(@gems_dir, "*.gem")).each do |gem_path|
      gem_reader = GemReader.new(gem_path.to_s)
      spec = gem_reader.spec
      spec_name = spec.name
      next if updated_gems.has_key?(spec_name)
      download_latest_gems(spec_name)
      updated_gems[spec_name] = true
    end
  end

  desc "Clean old slide gems"
  task :clean do
    gems = {}

    Dir.glob(File.join(@gems_dir, "*.gem")).each do |gem_path|
      gem_reader = GemReader.new(gem_path.to_s)
      spec = gem_reader.spec
      gems[spec.name] ||= []
      gems[spec.name] << spec
    end

    gems.each do |name, specs|
      sorted_specs = specs.sort_by(&:version)
      old_specs = sorted_specs[0..-2]
      old_specs.each do |old_spec|
        rm(File.join(@gems_dir, "#{old_spec.full_name}.gem"))
      end
    end
  end
end

desc "Apply the Ansible configurations"
task :deploy do
  cd("ansible") do
    sh("ansible-playbook",
       "--inventory-file", "../hosts",
       "playbook.yml")
  end
end
