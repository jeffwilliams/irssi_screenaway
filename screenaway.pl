#!/usr/bin/env perl
#
# Detect user inactivity using screen's 'idle' command.
# 
# This script requires irssi to be run inside GNU screen to work properly.
# GNU screen has a feature activated by the command 'idle': when the user has been
# idle (hasn't typed any keys) for a specified number of seconds it runs a shell
# command specified by the 'blankerprg' setting.
#
# This script uses that functionality to implement auto-away functionality in 
# irssi. When screen detects the user is idle it executes a script (screenaway_blanker.pl)
# that notifies this irssi script that the user is away. The user's nick is changed to the 
# specified value and the /AWAY command is run. 
#
# When the user presses a key, screen terminates the screenaway_blanker.pl script which
# this irssi script detects, and on that event changes the user's nick back to it's previous
# setting and unmarks the user as away.
#
# Installation:
#
# 1. Copy `screenaway.pl` and `screenaway_blanker.pl` to the directory `~/.irssi/scripts`. 
# 2. Make a link to screenaway.pl from ~/.irssi/scripts/autorun if you want it started automatically.
# 
# Settings:
#
# This script registers the following settings in irssi which can be modified using the /set command, i.e.
# /set screenaway_nick bob-away. Query using /set screenaway.
#
# Setting               Default           Desc
# -------               -------           ----
# 'screenaway_nick'    'bob-away'         The nick to set when away.
# 'screenaway_timeout'  300               The number of seconds the user may be idle before being marked away.
# 'screenaway_reason', 'AFK for a while'  Reason to pass to the /away command
# 'screenaway_debug',   0                 Set this to 1 to enable debug messages. They'll appear in the main irssi window.            
#
# Inside irssi, you can load this script using `/script load screenaway.pl` and unload using `/script unload screenaway.pl`
#

use strict;
use vars qw($VERSION %IRSSI);
$VERSION = "1.0";
%IRSSI = (
    authors     => "Jeff Williams",
    contact     => "n/a",
    name        => "screenaway",
    description => "Auto-away script based on terminal lastmod",
    license     => "MIT",
    changed     => "$VERSION",
);

use Irssi;
use vars qw($timer);
use IO::Socket::UNIX;
use IO::Select;
use File::Basename;

##### Global variables
my $BLANKER_PATH = "$ENV{HOME}/.irssi/scripts/screenaway_blanker.pl";
my $SOCK_PATH = "$ENV{HOME}/.irssi/.idle.sock";
my $POLL_INTERVAL = 250;
my $blanker_sock = undef;
my $server = undef;
my $timeout = 300;
my %serverNicks = {};
my $DEBUG = 0; # Set to 1 to enable debug logs

##### Socket functions
sub uxlisten {
  unlink $SOCK_PATH;

  my $server = IO::Socket::UNIX->new(
    Type => SOCK_STREAM(),
    Local => $SOCK_PATH,
    Listen => 1,
  );

  return $server;
}

sub uxaccept {
  my $select =  IO::Select->new([$server]);
  if( $select->can_read(0) ){
    my $conn = $server->accept();
    # Disable buffering
    my $ofh = select $conn;
    $| = 1;
    select $ofh;
    return $conn;
  }
  return undef;
}

sub uxeof {
  my $conn = shift;
  my $select =  IO::Select->new([$conn]);
  if( $select->can_read(0) ){
    my $buf = "";
    my $rc = sysread $conn, $buf, 1;
    if( $rc == 0 ){
      return 1;
    }
  }
  return 0;
}

##### Irssi integration

sub debug {
  my $d = Irssi::settings_get_int("screenaway_debug");
  print CLIENTCRAP "%Rscreenaway>> $_[0]\n" if $d;
}

sub info {
  print CLIENTCRAP "%Rscreenaway>> $_[0]\n";
}

sub set_away {
  debug("user is away.");

  my $reason = Irssi::settings_get_str("screenaway_reason");
  my $nick = Irssi::settings_get_str("screenaway_nick");

  my @servers = Irssi::servers();
  return unless @servers;
  $servers[0]->command('AWAY '.$reason);

  foreach (@servers) {
    if( ! $_->{usermode_away} ) {
      debug("Saving nick $servers[0]->{nick} for server $servers[0]->{tag}");
      $serverNicks{$_->{tag}} = $_->{nick};
      debug("Changing nick to $nick for server $_->{tag}");
      $_->command('NICK '.$nick);
    }
  }
}

sub set_back {
  debug("user is back.");

  foreach(Irssi::servers()) {
    if( $_->{usermode_away} ){
      $_->command('AWAY');
    }

    last;
  }

  foreach (Irssi::servers()) {
    my $nick = $serverNicks{$_->{tag}};
    debug("Changing nick to $nick for server $_->{tag}");
    $_->command('NICK '.$nick) if $nick;
  }
}

sub check_away {
  if( ! uxeof($blanker_sock) ){
    # The blanker program is still connected; the user is still away.
    return;
  }

  # User is back!
  $blanker_sock = undef;
  set_back;
}

# Register the blanker program.
sub register_blanker {
  # The environment variable STY is set by screen to the socket name of the current screen session.
  my $cmd = 'screen -S $STY -X blankerprg '.$BLANKER_PATH;
  my $rc = system($cmd);
  if( $rc != 0 ){
    info("Registering blanker program $BLANKER_PATH with screen failed. Are we inside a screen session?");
    return 0;
  }

  $cmd = 'screen -S $STY -X idle '.$timeout;
  $rc = system($cmd);
  if( $rc != 0 ){
    info("Setting idle time in screen failed. Are we inside a screen session?");
    return 0;
  }

  return 1;
}

sub monitor {
  # Check if the user changed the timeout setting
  my $new_timeout = Irssi::settings_get_int("screenaway_timeout");
  if( $new_timeout != $timeout ) {
    $timeout = $new_timeout;
    debug("Adjusting timeout to $timeout");
    register_blanker;
  }

  if( $blanker_sock ) {
    check_away;
  } else {
    $blanker_sock = uxaccept;
    if( $blanker_sock ) {
      debug("remote connection!");
      set_away;
      check_away;
    }
  }
}

# Start the timer that checks if the user is away.
sub start_timer {
  debug("starting timer");
  $timer = Irssi::timeout_add($POLL_INTERVAL, "monitor", undef);
}

sub unregister_blanker {
  my $cmd = 'screen -S $STY -X idle off';
  my $rc = system($cmd);
  if( $rc != 0 ){
    info("Unsetting idle time in screen failed. Are we inside a screen session?");
    return 0;
  }
  return 1;
}

# Called by IRSSI on script unload
sub UNLOAD {
  unregister_blanker;
}

##### MAIN

Irssi::settings_add_str($IRSSI{name}, 'screenaway_nick', 'bob-away');
Irssi::settings_add_int($IRSSI{name}, 'screenaway_timeout', 300);
Irssi::settings_add_str($IRSSI{name}, 'screenaway_reason', 'AFK for a while.');
Irssi::settings_add_int($IRSSI{name}, 'screenaway_debug', $DEBUG);

$server = uxlisten;
if ( ! $server ) {
  my $d = dirname($SOCK_PATH);
  info("uxlisten failed: $!. Check that the directory where the unix socket is stored ($SOCK_PATH) exists.");
  exit 1;
}

register_blanker || exit 2;

start_timer;

info("started!");
