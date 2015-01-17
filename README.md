
# IRSSI script: screenaway

Detect user inactivity using screen's 'idle' command.
 
This script requires irssi to be run inside GNU screen to work properly.
GNU screen has a feature activated by the command 'idle': when the user has been
idle (hasn't typed any keys) for a specified number of seconds it runs a shell
command specified by the 'blankerprg' setting.

This script uses that functionality to implement auto-away functionality in 
irssi. When screen detects the user is idle it executes a script (`screenaway_blanker.pl`)
that notifies this irssi script that the user is away. The user's nick is changed to the 
specified value and the /AWAY command is run. 

When the user presses a key, screen terminates the `screenaway_blanker.pl` script which
this irssi script detects, and on that event changes the user's nick back to it's previous
setting and unmarks the user as away.

## Installation:

1. Copy `screenaway.pl` and `screenaway_blanker.pl` to the directory `~/.irssi/scripts`. 
2. Make a link to `screenaway.pl` from `~/.irssi/scripts/autorun` if you want it started automatically.
 
## Settings:

 This script registers the following settings in irssi which can be modified using the `/set` command, i.e.
 `/set screenaway_nick bob-away`. Query using `/set screenaway`.

    Setting               Default           Desc
    -------               -------           ----
    'screenaway_nick'    'bob-away'         The nick to set when away.
    'screenaway_timeout'  300               The number of seconds the user may be idle before being marked away.
    'screenaway_reason', 'AFK for a while'  Reason to pass to the /away command
    'screenaway_debug',   0                 Set this to 1 to enable debug messages. They'll appear in the main irssi window.            
 Inside irssi, you can load this script using `/script load screenaway.pl` and unload using `/script unload screenaway.pl`


