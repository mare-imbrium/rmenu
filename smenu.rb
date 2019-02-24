#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: smenu.rb
#  Description:  This program displays a list and allows user to select
#                with arrow keys and ENTER. q to quit.
#                It does not clear screen but only the lines it prints on. 
#                It is meant to be a simple version of `smenu`.
#       Author: j kepler  http://github.com/mare-imbrium/canis/
#         Date: 2019-02-21 - 09:33
#      License: MIT
#  Last update: 2019-02-24 14:41
# ----------------------------------------------------------------------------- #
#  smenu.rb  Copyright (C) 2012-2019 j kepler
# v1 - printed all lines after each press resulting in flicker
# v2 - print only affected two lines (prev and current index)
# v3 - a separate version which allows printing detail below for curr index
# TODO 2019-02-22 - handle scrolling

# 2019-02-21 - this passes a block so we can print below. but we need to ensure
#   we back up as many rows as we write. would have been nice to save and restore cursor
# NOTE: print_partial was fine as long as there was no scrolling. with scrolling, 
#       we need to print all rows again. 2019-02-23 
require 'io/wait'

# we need this to use getch and raw 
# : https://ruby-doc.org/stdlib-2.1.0/libdoc/io/console/rdoc/IO.html
require 'io/console'

class Smenu
  attr_accessor :display_lines
  attr_accessor :transpose_flag
  def initialize
    @display_lines = 3
    @transpose_flag = false
    @start_row = 0
    @sel_marker = '*'
    @uns_marker = ' '

    ## get input from keyboard, as there could be STDIN from pipe.
    @ios = tty_open
  end

  # we require this in case user pipes in data
  def tty_open
    fd = IO.sysopen "/dev/tty", "r"
    ios = IO.new(fd, "r")
    return ios
  end

  # we require this in case user pipes in data
  def tty_getc
    @ios.getch
  end

  def char_if_pressed  # {{{
    #cn = nil
    begin
      system("stty raw -echo 2>/dev/null") # turn raw input on
      #c = $stdin.getc
      c = tty_getc
      #return nil unless c
      if c == ''
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

  def fix_rows index, ch
    @last_row = @start_row + @display_lines - 1
    if index > @last_row 
      @start_row = index
      @last_row += (@display_lines - 0)
      if @last_row > ch.size - 1
        @last_row = ch.size - 1
        @start_row = (@last_row - @display_lines) + 1
      end
    elsif index < @start_row
      @start_row = @start_row - @display_lines + 0
      @start_row = 0 if @start_row < 0
      @last_row = @start_row + @display_lines - 1
    end
  end

  def print_full ch, index   # {{{
    if ch.size < @display_lines
      @display_lines = ch.size
    end
    fix_rows index, ch
    ch.each_with_index { |e, ix|
      next if ix < @start_row
      next if ix > @last_row
      if ix == index
        marker = @sel_marker
      else
        marker = @uns_marker
      end
      puts "#{marker} #{e}"
    }
  end  # }}}

  # now unused since scrolling requires reprinting all
  def UNUSEDprint_partial ch, prev_index, index  # {{{
    raise
    # 
    # only print for two given indices
    # there is still some flicker since I am still printing a puts for the non lines
    # I don't know current cursor pos, so i can just jump to that position
    fix_rows index, ch
    lines = ch.size 
    lines = @display_lines
    lines.times { system "tput cuu1;" }
    ch.each_with_index { |e, ix|
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

  def run ch
    Signal.trap("INT") do # SIGINT = control-C
      reset_terminal
      exit
    end
    c = nil
    prev_index = index = 0
    printed = false
    begin
      #system "tput smcup" # clears the screen
      #system "tput ed"
      system "tput civis" # hide cursor
      while true
  
        if printed
          # after first time
          #print_partial ch, prev_index, index
          lines = @display_lines
          lines.times { system "tput cuu1;" }
          print_full(ch, index) 
        else
          # first time
          print_full(ch, index) unless printed
          printed = true 
        end
        # TODO save cursor here
        #system "tput sc"
        yield index , c if block_given?
        # TODO restore cursor here
        #system "tput rc"
        c = char_if_pressed
        next unless c


        break if c == 113 or c == 'q'
        prev_index = index
        case c
        when 'j', "TAB"
          index += 1
        when 'k' # 107
          index -= 1
        when 13
          return ch[index]
        when "ENTER"
          return ch[index]
        when "[B"
          index += 1
        when "[A"
          index -= 1
        when "[C"
          index += 1
        when "[D"
          index -= 1
        when "[H"
          index = 0           # avoid this since we only want two consecutive lines affected
        when "[F"
          index = ch.size - 1 # avoid this since we only want two consecutive lines affected
        else
          ; # nothing yet
        end
        index = 0 if index < 0
        index = ch.size-1 if index > ch.size-1
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
  # Keep reading lines of input as long as they're coming.
  if ARGV.count == 0
    choices = []
    while input = ARGF.gets
      input.each_line do |line|
        line = line.chomp
        choices << line
      end
    end
    $stdin.flush
    #system "tput smcup"
    #choices = %w{ ruby perl go elixir }
    #choices = ('a'..'z').to_a
    menu = Smenu.new
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
  end
end
