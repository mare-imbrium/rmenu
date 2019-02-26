#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: smenu.rb
#  Description:  This program displays a list and allows user to select
#                with arrow keys and ENTER. q to quit.
#                It does not clear screen but only the lines it prints on. 
#                It is meant to be a simple version of `smenu`.
#       Author: j kepler  http://github.com/mare-imbrium/
#         Date: 2019-02-21 - 09:33
#      License: MIT
#  Last update: 2019-02-26 23:16
# ----------------------------------------------------------------------------- #
#  smenu.rb  Copyright (C) 2012-2019 j kepler
# v1 - printed all lines after each press resulting in flicker
# v2 - print only affected two lines (prev and current index)
# v3 - a separate version which allows printing detail below for curr index
# DONE 2019-02-22 - handle scrolling
# TODO 2019-02-25 - if scrolling fast, then arrow key codes show up on screen
# DONE 2019-02-25 - may need a label on top

# 2019-02-21 - this passes a block so we can print below. but we need to ensure
#   we back up as many rows as we write. would have been nice to save and restore cursor
# NOTE: print_partial was fine as long as there was no scrolling. with scrolling, 
#       we need to print all rows again. 2019-02-23 
require 'io/wait'

# we need this to use getch and raw 
# : https://ruby-doc.org/stdlib-2.1.0/libdoc/io/console/rdoc/IO.html
require 'io/console'

class Smenu

  # how many lines to display
  attr_accessor :display_lines

  # message to print before choices
  attr_accessor :message

  # TODO transpose choices
  attr_accessor :transpose_flag

  # block to call when ENTER pressed
  attr_accessor :on_enter_block

  def initialize
    @display_lines = 5
    @message = nil
    @transpose_flag = false
    @start_row = 0
    @sel_marker = '*'
    @uns_marker = ' '

    ## get input from keyboard, as there could be STDIN from pipe.
    @ios = tty_open
  end

  # store block to execute if ENTER pressed
  def on_enter &block
    @on_enter_block = block
  end

  # Use tty in place of stdin, in case user pipes in data
  def tty_open
    fd = IO.sysopen "/dev/tty", "r"
    ios = IO.new(fd, "r")
    #ios.echo = false   # tried this since fast scrolling shows up on screen
    #ios.raw!   # messes newline the first time
    return ios
  end

  # we require this in case user pipes in data
  def tty_getc
    @ios.getch
  end

  # get a character/key from user and process
  # @return String c.chr. e,g, ENTER TAB C-n a b c 1 2 3 
  def getchar  # {{{
    #cn = nil
    begin
      system("stty raw -echo 2>/dev/null") # turn raw input on
      #c = $stdin.getc
      c = tty_getc
      if c == ''      # Escape character, possible arrow key or page down
        buff = c.chr
        while true
          k = nil
          #if $stdin.ready?
          if @ios.ready?
            #k = $stdin.getc
            k = tty_getc
            buff += k.chr
          else
            #puts "buff is:#{buff}"
            return buff
          end
        end
      end

      # check for control characters
      cn = c.ord
      if cn >= 0 and cn < 27
        case cn
        when 13,10
          return "ENTER"
        when 9
          return "TAB"
        else
          x = cn + 96
          return "C-#{x.chr}"
        end
      end
      c.chr if c
    ensure
      system "stty -raw echo 2>/dev/null" # turn raw input off
    end
  end  # }}}

  # fix start and finish index when scrolling
  # modifies start_row and last_row
  # @param Integer current index
  # @param Array choices
  def fix_rows index, choices
    @last_row = @start_row + @display_lines - 1
    if index > @last_row 
      @start_row = index
      @last_row += (@display_lines - 0)
      if @last_row > choices.size - 1
        @last_row = choices.size - 1
        @start_row = (@last_row - @display_lines) + 1
      end
    elsif index < @start_row
      @start_row = @start_row - @display_lines + 0
      @start_row = 0 if @start_row < 0
      @last_row = @start_row + @display_lines - 1
    end
  end

  def print_full choices, index   # {{{
    if choices.size < @display_lines
      @display_lines = choices.size
    end
    fix_rows index, choices
    choices.each_with_index { |e, ix|
      next if ix < @start_row
      next if ix > @last_row
      if ix == index
        marker = @sel_marker
      else
        marker = @uns_marker
      end
      system "tput el"    # clear line since scrolling
      puts "#{marker} #{e}"
    }
  end  # }}}

  # now unused since scrolling requires reprinting all
  def UNUSEDprint_partial choices, prev_index, index  # {{{
    raise
    # 
    # only print for two given indices
    # there is still some flicker since I am still printing a puts for the non lines
    # I don't know current cursor pos, so i can just jump to that position
    fix_rows index, choices
    lines = choices.size 
    lines = @display_lines
    lines.times { system "tput cuu1;" }
    choices.each_with_index { |e, ix|
      next if ix < @start_row
      next if ix > @last_row
      marker = nil
      if ix == index
        marker = @sel_marker
      elsif ix == prev_index
        marker = @uns_marker
      end
      if marker
        system("tput el")
        puts "#{marker} #{e}" 
      else
        system("tput cud1")  # go down a line
        #puts
      end
    }
  end   # }}}

  def run choices
    Signal.trap("INT") do # SIGINT = control-C
      reset_terminal
      exit
    end
    c = nil
    prev_index = index = 0
    printed = false
    puts "#{message}" if @message
    begin
      #system "tput smcup" # clears the screen
      #system "tput ed"
      while true
        system "tput civis" # hide cursor
  
        if printed
          # after first time
          #print_partial choices, prev_index, index
          lines = @display_lines
          lines.times { system "tput cuu1;" }
          print_full(choices, index) 
        else
          # first time
          print_full(choices, index) unless printed
          printed = true 
        end
        # TODO save cursor here
        #system "tput sc"
        yield index , c if block_given?
        # TODO restore cursor here
        #system "tput rc"
        c = getchar
        next unless c


        break if c == 113 or c == 'q'
        prev_index = index
        case c
        when 'j', "TAB"
          index += 1
        when 'k' # 107
          index -= 1
        when "ENTER"
          if @on_enter_block
            @on_enter_block.call(index)
          else
            return choices[index]
          end
        when "[B"     # down arrow
          index += 1
        when "[A"     # up arrow
          index -= 1
        when "[C"     # right arraw
          index += 1
        when "[D"     # left arrow
          index -= 1
        when "[H"
          index = 0           # avoid this since we only want two consecutive lines affected
        when "[F"
          index = choices.size - 1 # avoid this since we only want two consecutive lines affected
        else
          ; # nothing yet
        end
        index = 0 if index < 0
        index = choices.size-1 if index > choices.size-1
      end
    ensure
      reset_terminal
    end
  end

  # bring cursor back up to the start, hopefully. This really needs to be improved.
  def reset_terminal
    lines = @display_lines
    lines.times { system "tput cuu1;" }
    system "tput cnorm" # unhide cursor
  end

end # class
if __FILE__ == $0
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
        $opt_verbose = v
      end
      opts.on("--debug", "Show debug info") do 
        $opt_debug = true
      end
      opts.on("-q", "--quiet", "Run quietly") do |v|
        $opt_quiet = true
      end
      #opts.on("-nNAME", "--name=NAME", "Name to say hello to") do |n|
      #end
      opts.on('-n LINES', Integer, "Lines to show")
      opts.on('-m MESSAGE', String, "Prompt to show")

    end.parse!(into: options)
  # Keep reading lines of input as long as they're coming.
  if ARGV.count == 0
    choices = []

    # take input from a pipe, however this gives errors from vim
    # works fine if pager most is used
    if !STDIN.tty?
      while input = ARGF.gets
        input.each_line do |line|
          line = line.chomp
          choices << line
        end
      end
      $stdin.flush
      $stdin.close
    else
      # if nothing passed, then make some dir entries
      choices = Dir.entries('.').select { |e| File.file?(e) }
    end
    #system "tput smcup"
    #choices = %w{ ruby perl go elixir }
    #choices = ('a'..'z').to_a
    menu = Smenu.new
    menu.display_lines = options[:n] if options[:n]
    menu.message = options[:m] if options[:m]
    menu.on_enter do |ix|
      file = choices[ix]
      if File.exist? file
        #system "smcup"
        # vim warning about not a terminal, and screen gets messed up after
        system "most #{file}"
        #system "stty sane"
        #system "rmcup"
        # may need to hide cursor or reset terminal etc here
        #system "cat #{file} | vim -R -" # this works but its a noname file
      end
    end
    sel = menu.run choices do |ix|
      system "tput el" 
      lang = choices[ix]
      puts "You selected #{lang}"
      #str = %x{ brew info #{lang} 2>/dev/null | head -n 3 }
      #puts str
      1.times { system "tput cuu1;" }
    end
    #system "tput rmcup"
    puts sel if sel
  end # if ARGV
  end # begin
end # if FILE
