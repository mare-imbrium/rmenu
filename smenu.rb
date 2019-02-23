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
#  Last update: 2019-02-23 09:37
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
class Smenu
  attr_accessor :display_lines
  attr_accessor :transpose_flag
  def initialize
    @display_lines = 3
    @transpose_flag = false
    @start_row = 0
  end
  $sel_marker = '*'
  $uns_marker = ' '
  def char_if_pressed  # {{{
    #cn = nil
    begin
      system("stty raw -echo 2>/dev/null") # turn raw input on
      c = $stdin.getc
      if c == ''
        buff = c.chr
        while true
          k = nil
          if $stdin.ready?
            k = $stdin.getc
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
        marker = $sel_marker
      else
        marker = $uns_marker
      end
      puts "#{marker} #{e}"
    }
  end  # }}}
  def print_partial ch, prev_index, index  # {{{
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
        marker = $sel_marker
      elsif ix == prev_index
        marker = $uns_marker
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
      system "tput cnorm"
      exit
    end
    c = nil
    prev_index = index = 0
    printed = false
    begin
      system "tput civis" # hide cursor
      while true
  
        if printed
          #print_partial ch, prev_index, index
          lines = @display_lines
          lines.times { system "tput cuu1;" }
          print_full(ch, index) 
        else
          print_full(ch, index) unless printed
          printed = true 
        end
        # TODO save cursor here
        #system "tput sc"
        yield index , c if block_given?
        # TODO restore cursor here
        #system "tput rc"
        c = char_if_pressed

        # clear as many lines as printed only
        #lines = ch.size 
        #lines.times { system "tput cuu1;tput el" }
        #lines.times { system "tput cuu1;" }
        # TODO to prevent flicker only clear the TWO lines to change and print them
        # only if index has changed
        # -------

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
      system "tput cnorm" # unhide cursor
    end
  end
end # class
if __FILE__ == $0
  #system "tput smcup"
  choices = %w{ ruby perl go elixir }
  choices = ('a'..'z').to_a
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
