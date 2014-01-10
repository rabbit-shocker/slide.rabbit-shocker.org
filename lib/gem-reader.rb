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

begin
  require "rubygems/format"
rescue LoadError
  require "rubygems/package"
end

class GemReader
  def initialize(path)
    if Gem.const_defined?(:Format)
      @reader = FormatReader.new(path)
    else
      @reader = PackageReader.new(path)
    end
  end

  def each(&block)
    @reader.each(&block)
  end

  def spec
    @reader.spec
  end

  class FormatReader
    def initialize(path)
      @format = Gem::Format.from_file_by_path(path)
    end

    def each
      @format.file_entries.each do |info, content|
        yield(info["path"], content)
      end
    end

    def spec
      @format.spec
    end
  end

  class PackageReader
    def initialize(path)
      @path = path
      @package = Gem::Package.new(@path)
    end

    def each
      open_gem(@path) do |gem|
        gem.each do |entry|
          yield(entry.full_name, entry.read)
        end
      end
    end

    def spec
      @package.spec
    end

    private
    def open_gem(path)
      File.open(path, "rb") do |gem|
        open_tar(gem) do |tar|
          tar.each do |entry|
            next unless entry.full_name == "data.tar.gz"
            open_tar_gz(entry) do |tar|
              yield(tar)
            end
            break
          end
        end
      end
    end

    def open_tar(input)
      Gem::Package::TarReader.new(input) do |tar|
        yield(tar)
      end
    end

    def open_tar_gz(input)
      Zlib::GzipReader.wrap(input) do |gzip|
        open_tar(gzip) do |tar|
          yield(tar)
        end
      end
    end
  end
end
