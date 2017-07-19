# dotfiles
Public copies of some of my configs/dotfiles for reference.

Possible configurations of interest:

* .config/gtk-3.0/gtk.css file for removing/shrinking the padding on titlebars.
* mpv configuration (mpv.conf and input.conf) and various scripts. A number of keybindings are based off of what I used with [Bomi](https://github.com/xylosper/bomi).

### Config/Scripts for mpv

The shorcuts specified in the input.conf are modeled off of what I used in Bomi before moving to straight mpv and the scripts are saved from various gists or github repos, linked from the [mpv scripts page](https://github.com/mpv-player/mpv/wiki/User-Scripts).

I have a seperate github repo for my [mpvcontextmenu script](https://github.com/carmanaught/mpvcontextmenu).

For config in a couple of the scripts, they reference a file externally that I used so as not to have to edit out personal paths in each file each time I want to push updates to this git repo. The personal-values.lua file in this repo also simply contains the default values. I mention this here as if you want to change those values you either need to update the personal-values.lua file or update the scripts yourself.

If you're trying to debug any of this yourself, it's probably best to run mpv from the command-line to see the error output.