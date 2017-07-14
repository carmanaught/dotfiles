# dotfiles
Public copies of some of my configs/dotfiles for reference.

Possible configurations of interest:

* .config/gtk-3.0/gtk.css file for removing/shrinking the padding on titlebars.
* mpv configuration (mpv.conf and input.conf) and various scripts. A number of keybindings are based off of what I used with [Bomi](https://github.com/xylosper/bomi).

### Config/Scripts for mpv

The shorcuts specified in the input.conf are modeled off of what I used in Bomi before moving to straight mpv and the scripts are saved from various gists or github repos, linked from the [mpv scripts page](https://github.com/mpv-player/mpv/wiki/User-Scripts).

One of the things I did miss from Bomi and have sort-of regained, is a right-click menu. Specifically, the [Tcl/Tk context menu](https://gist.github.com/avih/bee746200b5712220b8bd2f230e535de) context.lua and context.tcl files which are used to create a right-click menu. The context.lua specifically has been fairly heavily modified to match the layout of the Bomi menu. Note however that this is a **work-in-progress** and I'll probably remove items that are too difficult or that I just straight don't feel like trying to implement. There may also be bugs.

Also keep in mind that the menu doesn't support proper submenus and I haven't figured out the logistics of how to do this between the LUA and TCL/TK code. Another thing to note is that the context menu uses some of the mpv scripts I've downloaded, such as [subit](https://github.com/wiiaboo/mpv-scripts/blob/master/subit.lua), [playlistmanager](https://github.com/donmaiq/Mpv-Playlistmanager), [filenavigator](https://github.com/donmaiq/mpv-filenavigator) or [stats](https://github.com/Argon-/mpv-stats/).

For config in a couple of the scripts, they reference a file externally that I used so as not to have to edit out personal paths in each file each time I want to push updates to this git repo. The personal-values.lua file in this repo also simply contains the default values. I mention this here as if you want to change those values you either need to update the personal-values.lua file or update the scripts yourself.

If you're trying to debug any of this yourself, it's probably best to run mpv from the command-line to see the error output.