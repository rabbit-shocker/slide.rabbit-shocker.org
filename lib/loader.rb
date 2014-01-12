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

require "pathname"

require_relative "author"
require_relative "slide"

class Loader
  def initialize
    @gems_dir_path = Pathname("gems")
    @authors = {}
  end

  def authors
    @authors.values
  end

  def load
    @gems_dir_path.children.each do |slide_gem_path|
      slide = Slide.new(slide_gem_path)
      next unless slide.available?

      rubygems_user = slide.rubygems_user
      @authors[rubygems_user] ||= Author.new
      author = @authors[rubygems_user]
      author.add_slide(slide)
    end
  end
end
