== smenu

Inspired by the `smenu` command.

This is a ruby program that can be used to get interactive menus that can display
some text as user scrolls down the list.
Also, if user presses ENTER a program may be launched if defined.

The caller will use a block to specify what is to be displayed when a row becomes current, as well as what program is to be launched when ENTER is pressed.

Usually the caller program will be a ruby program which includes this.

However, I am also making this into a command line program which receives data as a pipe and uses that to make a menu. Currently, by default it launches "most" (which is a pager).
If i launch "vim", then vim complains about terminals, and then messes up the screen upon exiting. However, the command line program should not launch a program upon hitting ENTER as that makes it very specific. It should just return the selection on ENTER.

The advantage of this is that control comes back to the menu after closing the PAGER, so the user can continue.

The file `dbsmenu.rb` is a demo, which takes a SQLITE database as ARGV and displays tables, pressing ENTER will display some data from the table in VIM. To exit the menu, press "q".
