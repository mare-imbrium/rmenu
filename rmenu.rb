#!/usr/bin/env ruby
# ----------------------------------------------------------------------------- #
#         File: rmenu.rb
#  Description:  This program displays a list and allows user to select
#                with arrow keys and ENTER. q to quit.
#                It does not clear screen but only the lines it prints on.
#                It is meant to be a simple version of `smenu`.
#
#        Usage: Pipe in data and use selectors. You may specify command
#               to execute on selected file.
#               Common options:
#               -m message
#               -T multiple select
#               -c command to execute for single selection
#
#       Author: j kepler  http://github.com/mare-imbrium/
#         Date: 2019-02-21 - 09:33
#      License: MIT
#  Last update: 2019-02-27 12:36
# ----------------------------------------------------------------------------- #
#  rmenu.rb  Copyright (C) 2012-2019 j kepler

require 'io/wait'

# we need this to use getch and raw
# https://ruby-doc.org/stdlib-2.6.1/libdoc/io/console/rdoc/IO.html
require 'io/console'

# --------------------------------------------- {{{
# color constants for selected rows and message
CLEAR      = "\e[0m"
# The start of an ANSI bold sequence.
BOLD       = "\e[1m"
## use infocmp screen to get escape codes for tput codes if tput not working
# --------------------------------------------- }}}

class Rmenu

  # how many lines to display
  attr_accessor :display_lines

  # message to print before choices
  attr_accessor :message

  # TODO transpose choices
  attr_accessor :transpose_flag

  # multiple selection
  attr_accessor :multiple_flag

  # block to call when ENTER pressed
  attr_accessor :on_enter_block

  def initialize     # {{{
    @display_lines = 5
    @message = nil
    @transpose_flag = false
    @multiple_flag = false
    @start_row = 0
    @current_marker = '*'
    @clear_marker = ' '
    # a hash for key bindings
    @bindings = Hash.new

    ## get input from keyboard, as there could be STDIN from pipe.
    @ios = tty_open
  end

  # store block to execute if ENTER pressed
  def on_enter &block
    @on_enter_block = block
  end  # }}}

  # Use tty in place of stdin, in case user pipes in data  {{{
  def tty_open
    fd = IO.sysopen "/dev/tty", "r"
    ios = IO.new(fd, "r")
    ios.echo = false   # required since fast scrolling shows up on screen
    #ios.raw!   # messes newline the first time
    return ios
  end

  # we require this in case user pipes in data
  def tty_getc
    @ios.getch
  end     #  }}}
  def go_up(lines=1)
    lines.times { system "tput cuu1;" }
  end
  def clear_line
    system "tput el"
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

  # fix start and finish index when scrolling     {{{
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
  end # }}}

  def print_full choices, index   # {{{
    if choices.size < @display_lines
      @display_lines = choices.size
    end
    fix_rows index, choices
    choices.each_with_index { |e, ix|
      next if ix < @start_row
      next if ix > @last_row
      if ix == index
        marker = @current_marker
      else
        marker = @clear_marker
      end
      bold = clear = nil
      if @multiple_flag
        if @selection.include? e
          bold = BOLD
          clear = CLEAR
        end
      end
      system "tput el"    # clear line since scrolling
      puts "#{marker} #{bold}#{e}#{clear}"
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
        marker = @current_marker
      elsif ix == prev_index
        marker = @clear_marker
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

  def run choices   # {{{
    Signal.trap("INT") do # SIGINT = control-C
      reset_terminal
      exit
    end
    c = nil
    prev_index = index = 0
    printed = false
    @selection = nil
    @selection = [] if @multiple_flag
    puts "#{BOLD}#{message}#{CLEAR}" if @message
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
        when 't'
          # tag the current row for selection, toggle
          if @multiple_flag
            e = choices[index]
            if @selection.include? choices[index]
              @selection.delete e
            else
              @selection << choices[index]
            end
          end
        when "ENTER"
          # if an enter block defined execute it. No multiple selection or return selection
          if @on_enter_block
            @on_enter_block.call(index)
          else
            # check for multiple selection and return either current row or selections
            if @multiple_flag
              return @selection
            else
              return choices[index]
            end
          end
        when "[B"     # down arrow
          index += 1
        when "[A"     # up arrow
          index -= 1
        when "[C"     # right arraw
          index += 1
        when "[D"     # left arrow
          index -= 1
        when "[H"     # home
          index = 0
        when "[F"     # end
          index = choices.size - 1
        else
          execute_binding(c, index, choices[index])
          ; # nothing yet
        end
        index = 0 if index < 0
        index = choices.size-1 if index > choices.size-1
      end
    ensure
      reset_terminal
    end
  end # }}}

  # bring cursor back up to the start, hopefully. This really needs to be improved.
  def reset_terminal    # {{{
    lines = @display_lines
    lines.times { system "tput cuu1;" }
    system "tput cnorm" # unhide cursor
  end  # }}}
  def execute_binding(key, index, text) # {{{
    if @bindings[key]
      blk = @bindings[key]
      blk.call(index, text)
    end
  end # }}}
  def bind_key key, &block
    @bindings[key] = block
  end

end # class
if __FILE__ == $0      # {{{
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
      opts.on('-c', "--command=String", "Command to execute for ENTER")
      opts.on("-T", "--multiple", "Multiple selection using t")

    end.parse!(into: options)
    puts options if $opt_debug
    # ---------- }}}
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
    menu = Rmenu.new
    menu.display_lines = options[:n] if options[:n]
    menu.multiple_flag = options[:multiple] if options[:multiple]
    menu.message = options[:m] if options[:m]
    if options[:command] || options[:c]
      menu.on_enter do |ix|
        file = choices[ix]
        if File.exist? file
          #system "smcup"
          # vim warning about not a terminal, and screen gets messed up after
          command = options[:command] || options[:c]
          system "#{command} #{file}"
          #system "stty sane"
          #system "rmcup"
          # may need to hide cursor or reset terminal etc here
          #system "cat #{file} | vim -R -" # this works but its a noname file
        end
      end
    end
    # example of binding a key to a row so some action can be taken
    menu.bind_key("p") do |index, text|
      firstword = text.split(" ").first
      puts "You selected #{index}, #{firstword}"
      menu.tty_getc
      menu.go_up
      menu.clear_line
    end

    sel = menu.run choices do |ix|
      # TODO 2019-02-27 - 10:32 don't force this here {{{
      # NOTE this is just a sample
      if false
        system "tput el"
        lang = choices[ix]
        puts "You selected #{lang}"
        #str = %x{ brew info #{lang} 2>/dev/null | head -n 3 }
        #puts str
        1.times { system "tput cuu1;" }
      end # false }}}

    end
    #system "tput rmcup"
    #system "tput ed"
    system "tput el"    # clear till end of line
    print "\e[J" if sel  # tput ed not working to celar rest of screen
    puts sel if sel
  end # if ARGV
  end # begin
end # if FILE }}}
