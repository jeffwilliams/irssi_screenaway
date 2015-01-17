#!/usr/bin/env perl

use strict;
use IO::Socket::UNIX;

my $SOCK_PATH = "$ENV{HOME}/.irssi/.idle.sock";

# Connect to socket
my $client = IO::Socket::UNIX->new(
  Type => SOCK_STREAM(),
  Peer => $SOCK_PATH,
);

print "screenaway_blanker.pl: Hit any key to resume this screen session.\n";

# Sleep forever (until screen kills us)
sleep

