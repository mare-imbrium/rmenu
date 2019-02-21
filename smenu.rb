#!/usr/bin/env ruby

# this program displays a list and allows user to select
# with arrow keys and ENTER. q to quit.
# It does not clear screen but only the lines it prints on. It is meant
# to be a simple version of `smenu`.
# Last Update:2019-02-21 00:07
# Rahul Kumar 2019.
require 'io/wait'
def char_if_pressed
  #cn = nil
  begin
    system("stty raw -echo 2>/dev/null") # turn raw input on
    c = nil
    #if $stdin.ready?
      c = $stdin.getc
    #end
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
    case cn
    when 13,10
      return "ENTER"
    when 9
      return "TAB"
    end

    
    c.chr if c
  ensure
    system "stty -raw echo 2>/dev/null" # turn raw input off
  end
end

def run ch
  Signal.trap("INT") do # SIGINT = control-C
    exit
  end
  i = 0
  index = 0
  while true
    #system "clear" # we should only clear from where we print get cursor pos
    ch.each_with_index { |e, ix|
      if ix == index
        marker = 'x'
      else
        marker = ' '
      end
      puts "#{marker} #{e}"
    }
    c = char_if_pressed

    # clear as many lines as printed only
    lines = ch.size 
    lines.times { system "tput cuu1;tput el" }
    # TODO to prevent flicker only clear the TWO lines to change and print them
    # only if index has changed
    # -------

    break if c == 113 or c == 'q'
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
      index = 0
    when "[F"
      index = ch.size - 1
    else
      sleep 4
    end
    index = 0 if index < 0
    index = ch.size-1 if index > ch.size-1
  end
end
#system "tput smcup"
choices = %w{ ruby perl golang elixir }
sel = run choices
#system "tput rmcup"
puts sel
