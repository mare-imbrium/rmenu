#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: test.rb
#  Description: this file tests rmenu.rb and show table info as the second portion
#                for current line.
#       Author:  r kumar
#         Date: 2019-02-21 - 12:27
#  Last update: 2019-03-05 09:38
#      License: MIT License
# ----------------------------------------------------------------------------- #
#
require 'logger'
require './rmenu.rb'
#require 'sqlite3'
# get_first_value  get_first_row
# http://www.rubydoc.info/github/luislavena/sqlite3-ruby/SQLite3/Database
require 'color' # see ~/work/projects/common/color.rb
  # print color("Hello there black reverse on yellow\n", "black", "on_yellow", "reverse")

#today = Date.today.to_s
#now = Time.now.to_s
# include? exist? each_pair split gsub each_with_index
logger = Logger.new('logfile.log')
_MAX_ROWS = 5
# class that encapsulates Sqlite3 functions using command line client not gem
class Cli_Sqlite3 # {{{
  def initialize dbname
    @dbname = nil
    if File.exist? dbname
      @dbname = dbname
    else
      raise ArgumentError, "#{dbname} does not exist."
    end
  end

  # @return Array of tablenames
  def tables
    tables=%x{ sqlite3 #{@dbname} ".tables" | tr -s ' ' | tr ' ' '\n' }
    return tables.split("\n")
  end
  # @return Array of columnnames
  def columns tbname
    cols = %x{sqlite3 #{@dbname} "PRAGMA table_info(#{tbname})" | cut -f2 -d'|'}
    return cols.split("\n")
  end

  # @return Integer count of rows
  def row_count tbname
    res = %x{sqlite3 #{@dbname} "SELECT COUNT(1) from #{tbname}" }
    res.chomp.to_i
  end
  def execute statement
    res = %x{sqlite3 #{@dbname} "#{statement}" }
    return res.split("\n")
  end
end # class  }}}

# break up array into columns. currently they are just appended not sized. {{{
# Another variation can be to create arrays rather than a string, so caller can decide
# n is the number of rows to create, which have concatenated values
def transpose arr, n
  narr = []
  n.times { narr << "" }
  arr.each_with_index do | e, ix |
    narr[ix%n] << " #{e} "
  end
  narr
end # }}}

    def printcols cols
      ncols = transpose(cols, 3)
      3.times {|j|
        system "tput el"
        puts ncols[j]
      }
    end
    def printdata cols, selected, db, max_rows=3
      columns = cols[0,3].join(",")
      statement = "SELECT #{columns} FROM #{selected} LIMIT #{max_rows}"
      #logger.info(statement)
      res = db.execute(statement)
      #logger.debug res.class
      res = res.join("\n")
      rs = %x{ echo "#{res}" | column -t -s'|' -c 80 }
      rs = rs.split("\n")
      rs.each do |e|
        system "tput el"
        puts e
      end
    end
    def get_rows selected, db
      cols = db.columns(selected)
      columns = cols[0,3].join(",")
      max_rows = 5
      statement = "SELECT #{columns} FROM #{selected} LIMIT #{max_rows}"
      res = db.execute(statement)
      #logger.debug res.class
      res = res.join("\n")
      rs = %x{ echo "#{res}" | column -t -s'|' -c 80 }
      rs = rs.split("\n")
      return rs
    end

if __FILE__ == $0
  include Color
  filename = nil
  $opt_verbose = false
  $opt_debug = false
  $opt_quiet = false
  begin
    # http://www.ruby-doc.org/stdlib/libdoc/optparse/rdoc/classes/OptionParser.html
    require 'optparse' # {{{
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
    end.parse! # }}}

    p options if $opt_debug
    p ARGV if $opt_debug

    # --- if processing just one file ---------
    filename=ARGV[0] || exit
    unless File.exist? filename
      $stderr.puts "File: #{filename} does not exist. Aborting"
      exit 1
    end
    db = Cli_Sqlite3.new filename
    _tables = db.tables()
    #puts "#{_tables} #{_tables.count}"
    menu = Rmenu.new
    scrollrows = _MAX_ROWS + 1
    selected = menu.run _tables do |ix, key|
      tb = _tables[ix]
      cols = db.columns(tb)
      rows = db.row_count(tb)
      print color( "#------ columns #{cols.size} rows: #{rows} -------\n", "bold")
      system "tput ed"
      #printcols cols
      printdata cols, tb, db, _MAX_ROWS
      scrollrows.times {|j| system "tput cuu1;" }
      system "tput ed"
    end
      #scrollrows.times {|j| system "tput cud1;" }
    if selected
      cols = db.columns(selected)
      # why does next line not clear to end of screen
      system "tput ed"
      rs = get_rows selected, db
      sm = Rmenu.new
      sm.run rs
      system "tput ed"

      printdata cols, selected, db, _MAX_ROWS
      if false
      puts
      puts "SELECT"
      puts cols.join(',')
      puts "FROM     "
      puts selected
      end
    end


  ensure
  end
end

