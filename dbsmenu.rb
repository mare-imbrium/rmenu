#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: test.rb
#  Description: this file tests smenu.rb and show table info as the second portion
#                for current line.
#       Author:  r kumar
#         Date: 2019-02-21 - 12:27
#  Last update: 2019-02-21 23:43
#      License: MIT License
# ----------------------------------------------------------------------------- #
#
require './smenu.rb'
#require 'sqlite3'
# get_first_value  get_first_row
# http://www.rubydoc.info/github/luislavena/sqlite3-ruby/SQLite3/Database
require 'color' # see ~/work/projects/common/color.rb
  # print color("Hello there black reverse on yellow\n", "black", "on_yellow", "reverse")

#today = Date.today.to_s
#now = Time.now.to_s
# include? exist? each_pair split gsub each_with_index

# @return Array
def tables dbname
  tables=%x{ sqlite3 #{dbname} ".tables" | tr -s ' ' | tr ' ' '\n' }
  return tables.split("\n")
end
# @return Array
def columns dbname, tbname
  cols = %x{sqlite3 #{dbname} "PRAGMA table_info(#{tbname})" | cut -f2 -d'|'}
  return cols.split("\n")
end
def row_count dbname, tbname
  res = %x{sqlite3 #{dbname} "SELECT COUNT(1) from #{tbname}" }
  res.chomp
end

def errecho text
  $stderr.puts text
end

# break up array into columns. currently they are just appended not sized.
# Another variation can be to create arrays rather than a string, so caller can decide
# n is the number of rows to create, which have concatenated values
def transpose arr, n
  narr = []
  n.times { narr << "" }
  arr.each_with_index do | e, ix |
    narr[ix%n] << " #{e} "
  end
  narr
end


if __FILE__ == $0
  include Color
  filename = nil
  $opt_verbose = false
  $opt_debug = false
  $opt_quiet = false
  begin
    # http://www.ruby-doc.org/stdlib/libdoc/optparse/rdoc/classes/OptionParser.html
    require 'optparse'
    options = {}
    OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [options]"

      opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
        options[:verbose] = v
        $opt_verbose = v
      end
      opts.on("--debug", "Show debug info") do 
        options[:debug] = true
        $opt_debug = true
      end
      opts.on("-q", "--quiet", "Run quietly") do |v|
        $opt_quiet = true
      end
    end.parse!

    p options if $opt_debug
    p ARGV if $opt_debug

    # --- if processing just one file ---------
    filename=ARGV[0] || exit 
    unless File.exist? filename
      $stderr.puts "File: #{filename} does not exist. Aborting"
      exit 1
    end
    _tables = tables(filename)
    #puts "#{_tables} #{_tables.count}"
    menu = Smenu.new
    selected = menu.run _tables do |ix|
      tb = _tables[ix]
      cols = columns(filename, tb)
      rows = row_count(filename, tb)
      print color( "#------ columns #{cols.size} rows: #{rows} -------\n", "bold")
      ncols = transpose(cols, 3)
      3.times {|j| 
        system "tput el"
        puts ncols[j] 
      }
      4.times {|j| system "tput cuu1;" }
      system "tput ed"
    end
      4.times {|j| system "tput cud1;" }
    if selected
      cols = columns(filename, selected)
      system "tput ed"
      puts
      puts "SELECT"
      puts cols.join(',')
      puts "FROM     "
      puts selected
    end


  ensure
  end
end

