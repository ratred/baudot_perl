#!/usr/bin/perl

#  ascii2baudot.pl - read ASCII input from STDIN and output
#  its Baudot equivalent to ttySx.
#
#  (c) 2002 Christian Herzog & Georg Fischer
#           daduke@daduke.org  punctum@punctum.com
#
# use GPL license or whatever else suits you
#
# changes:
# 03/06/08 use Device::SerialPort and added automatic turning on and off of the teletype
# 02/13/02 added umlauts, lines too long are wrapped _between_ words
# 02/10/02 first version


use strict;
use Device::SerialPort;
use Time::HiRes qw(usleep);

my $version = 1.0;
my $width = 62;	# max size of a fernschreiber line
my ($bu, $zi, $cr, $lf, $tab, $tty);	# $bu changes to letters, $zi to numbers

my ($custPort) = $ARGV[0] =~ /([\w\d\/]+)/;
my $port = ($custPort ne '')?$custPort:'/dev/ttyS0';      # your serial port goes here


print "This is ascii2baudot version $version.\nI'm now gonna print STDIN to your teletype on $port. Please stand by...\n\n";

initty ();	# initialize the serial port
initchars ();	# initialize the translation string

my $state = $bu;	# start with letters

$tty->write($cr . $lf);	# go to a new line
$tty->write($cr . $lf);
$tty->write($state);	# and active letter layer

my $counter = 0;
my $start = time;
while (<STDIN>) {	# for each line of STDIN
	s/\012//g;	# strip CRs
	s/ö/oe/gi;	# expand German umlauts
	s/ä/ae/gi;
	s/ü/ue/gi;
	s/ß/ss/gi;
	s/\t/    /g;	# tab becomes 4 spaces
	
	my $line = $_;
	my $outline = '';
	while (length($line) > $width) {	# line is too long!
		my $revpart = reverse (substr($line, 0, $width));	# turn around first chunk of line
		for my $charctr (0..length($revpart)) {	# go thru chars
			my $ch = substr ($revpart, $charctr, 1);
			if ($ch eq ' ') {	# and look for spaces; if found,
				$outline .= substr (reverse ($revpart), 0,
					length($revpart)-$charctr-1) . "\n";	# take the part before the space
				substr ($line, 0, $width-$charctr) = '';	# and delete it from the original line
				last;	# leave loop
			}
		}
	}
	$outline .= $line;	# add the remaining part

	for my $i (0..length($outline)) {	# for each char
		my $ch = substr($outline, $i, 1);	# get char
		if ($ch eq "\n") { 	# if it's a LF
			$tty->write($cr); # insert carriage return before linefeed
			$ch = "\015";
		}
		elsif ($ch eq ' ') { # whitespace
			# don't switch $state
		}
		elsif ($ch =~ /[a-z]/i) { # letters
			if ($state eq $zi) {	# change state if necessary
				$tty->write($bu);
				$state = $bu;
			}
		} else { # digits and special chars
			if ($state eq $bu) {
				$tty->write($zi);
				$state = $zi;
			}
		}
		
		$ch =  substr ($tab, ord $ch, 1);	# get the corresponding output char
		next if ($ch eq ' '); # empty table entry = nonprintable
		$tty->write($ch);	# output char
		$counter++;
		usleep(10000);
	} # for $i
	$tty->write($cr . $lf);	# next line of STDIN
} # while <>


my $stop = time - $start;
my $av = substr($counter / $stop, 0, 4);

print "I printed $counter characters on your teletype in $stop seconds. That's $av ch/sec. Not bad, hm?\n";
$tty->dtr_active (0) || die "fail unsetting dtr_active";

undef $tty;

##--------------------------------------
sub initty {	# initialize serial port
	$tty = Device::SerialPort->new($port) || die "Can't open $port:$!";

	$tty->baudrate (50) || die "fail setting baudrate";
	$tty->parity ("none") || die "fail setting parity";
	$tty->databits (5) || die "fail setting databits";
	$tty->stopbits (2) || die "fail setting stopbits";
	$tty->handshake ("none") || die "fail setting handshake";
	$tty->dtr_active (1) || die "fail setting dtr_active";

	$tty->write_settings || die "no settings";
}

sub initchars {	# for each char in the comment line, $tab holds the
		# Baudot equivalent
	$bu = '_';	# change to letters
	$zi = '[';	# change to numbers
	$cr = 'H';	# carriage return
	$lf = 'B';	# line feed

	$tab =
	# ABCDEFGHIJKLMNO
	'       K DH BB  ' .

	#PQ 
	'                ' .

	# !"#$%&'()*+,-. /
	'DNEQENQEORQQLC\\]' .

	#0123456789:;<=>?
	'VWSAJPUGFXNNO^RY' .

	#@ABCDEFGHIJKLM NO 
	'QCYNIAMZTFKOR\\LX' .

	#PQRSTUVWXYZ[\]^_
	'VWJEPG^S]UQO]REC' .

	#`abcdefghijklm no
	'ECYNIAMZTFKOR\\LX' .

	#pqrstuvwxyz{|}~
	'VWJEPG^S]UQO]REC';
}
