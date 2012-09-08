# -*- ruby -*-
#
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

require "rake/clean"

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "lib"))

require "generator"

task :default => :generate

namespace :images do
  generated_images = []
  Dir.glob("assets/images/go-*.svg").each do |go_svg|
    go_mini_png = go_svg.gsub(/\.svg/, "-mini.png")
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

task :generate => "images:generate" do
  generator = Generator.new
  generator.generate
end
