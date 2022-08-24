#!/usr/bin/perl
use warnings;
use strict;
use feature qw(say);
use Getopt::Long;

# save arguments following -h or --host in the scalar $host
# the '=s' means that an argument follows the option
# they can follow by a space or '=' ( --host=127.0.0.1 )
# same for --user or -u
# same for --pass or -p
GetOptions( 'numberOfEntries=s' => \my $numberOfEntries,
			'highEntry=s' => \my $highEntry,
            'lowEntry=s' => \my $lowEntry  
          );

my $i=0;
my $thediff =0;
my $theincrement=0;
my $newval=0;

say $numberOfEntries;
say $highEntry;
say $lowEntry;

if ($highEntry <= $lowEntry){
	say "error, highEntry (-h) is less than lowEntry -(l)";
	exit();
}
if ($numberOfEntries <= 2){
	say "error, numberOfEntries (-n) should be greater than 2";
	exit();
}

$thediff = $highEntry - $lowEntry;
say $thediff;

$theincrement = $thediff / $numberOfEntries;
say $theincrement;

for($i=0; $i<10; $i++){
	#$newval = sprintf("%.3f",$i);
	printf("%.3f ", $i);
}