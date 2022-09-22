#!/usr/bin/perl
use warnings;
use strict;
use feature qw(say);
use Getopt::Long; # for processing command line args
use File::Basename;

########## subroutines
sub Average {
	my $n = scalar(@_); # how many args into function
	my $sum=0;
	foreach my $item (@_) {
		$sum+=$item;
	}
	my $average = $sum/$n;
	return $average;
}
sub EvenDistribution {
	my $noOfEntriesWanted=$_[0];
	my $high=$_[1];
	my $low=$_[2];
	say "number of entries wanted: ".$noOfEntriesWanted;
	say "high entry: $high";
	say "low entry: $low";
	
	# get the entry values 
	my $highLowDiff = $high - $low;
	my $entryIncrement = $highLowDiff / ($noOfEntriesWanted-1);
	say "The difference between high and low entries: $highLowDiff";
	say "The increment is: $entryIncrement";
	my @entryValsArr;
	for(my $i=0; $i<$noOfEntriesWanted; $i++){
		push (@entryValsArr, $low+($entryIncrement*$i));
	}
	print "entryValsArr: @entryValsArr\n";
	
	# get the percentage values 
	my $percentageIncrement = 100/$noOfEntriesWanted;
	my $percentIncrementBase = int($percentageIncrement);
	#my $percentIncrementDecimal = sprintf("%.2f",$percentageIncrement-$percentIncrementBase);
	my @baseArr;
	my $sum=0;
	for(my $i=0; $i<$noOfEntriesWanted; $i++){
		push (@baseArr, $percentIncrementBase);
		$sum+=$percentIncrementBase;
	}
	print "baseArr: @baseArr\n";
	print "sum: $sum\n";
	# brute force the percentages to have a total of 100
	if ($sum<100){
		my $toAdd=100-$sum;
		my $arraySize=@baseArr;
		for (my $i=0; $i<$toAdd; $i++){
			$baseArr[$i]+=1;
		}
		#$baseArr[$arraySize-1]+=$toAdd;
	}
	print "baseArr: @baseArr\n";
}

########## Client: 
my $client01 = "BM BinFuts (main)";
my $client02 = "BM BinSpot (main)";
my $client03 = "BM BybitKB7 Contract InvUSD (main) 260321";
my $client04 = "BM BybitKB7 Contract LinUSDT (main) 211128";
my $client05 = "SF BinFuts (main)";
my $client06 = "SF BinSpot (main)";
my $client07 = "SF Bybit Contract InvUSD (main) 210318";
my $client08 = "BM BybitKB7 Contract LinUSDT (main) 281121";
my $client09 = "SF FtxFuturesPerp (main)";
my $client10 = "SF FtxFSpot (main)";
my $client11 = "SF KucoinSpot (main)";
########## Trade Type: 
my $tradeTypeLong = "Regular (Long)";
my $tradeTypeShort = "Regular (Short)";
########## Leverage: 
#my $levIso = "Isolated"; ## Leverage: Isolated (4.0X)!!!!!
my $levCross = "Cross";  ## Leverage: Cross (4.0X)!!!!!
########## Trailing: 
my $trailingLine01 = "Trailing Configuration:";
my $trailingLine02 = "Entry: Percentage (0.0%)";
my $trailingLine03 = "Take-Profit: Percentage (0.0%)";
my $trailingLine04 = "Stop: Breakeven -\n Trigger: Target(1)";


my $script_name = basename($0);
my $usage = sprintf("usage is: %s -n NoEntries -h highEntry -l lowEntry -p CoinPair -c Client -t TradeType -v Leverage",$script_name); 
my $numberOfEntries;
my $highEntry;
my $lowEntry;
my $pair;
my $clientIn;
my $clientSelected;
my $tradeTypeIn;
my $tradeTypeSelected;
my $leverage;
my $tradeIsALong;
my %args;
GetOptions( \%args,
			'n=s', # number of entries
			'h=s', # highest entry value
            'l=s', # lowest entry value
			'p=s', # coin pair
			'c=s', # client
			't=s', # trade type
			'v=s'  # leverage
          ) or die "Invalid command line arguments!";
die "Missing -n!\n".$usage unless $args{n};
die "Missing -f!\n".$usage unless $args{h};
die "Missing -l!\n".$usage unless $args{l};
die "Missing -p!\n".$usage unless $args{p};
die "Missing -c!\n".$usage unless $args{c};
die "Missing -t!\n".$usage unless $args{t};
die "Missing -v!\n".$usage unless $args{v};

$numberOfEntries = $args{n};
$highEntry = $args{h};
$lowEntry = $args{l};
$pair = $args{p};
$clientIn = $args{c};
$tradeTypeIn = $args{t};
$leverage = $args{v};

# number of entries should be greater than 2
if ($numberOfEntries <= 2) { die "\nerror: numberOfEntries should be > 2\n".$usage; }
# make sure high entry is above the low entry
if ($highEntry <= $lowEntry) { die "\nerror: highEntry is <= lowEntry\n".$usage; }
# client / exchange to use
if ($clientIn == 1) {
	$clientSelected = $client01;
} elsif ($clientIn == 2) {
	$clientSelected = $client02;
} elsif ($clientIn == 3) {
	$clientSelected = $client03;
} elsif ($clientIn == 4) {
	$clientSelected = $client04;
} elsif ($clientIn == 5) {
	$clientSelected = $client05;
} elsif ($clientIn == 6) {
	$clientSelected = $client06;
} elsif ($clientIn == 7) {
	$clientSelected = $client07;
} elsif ($clientIn == 8) {
	$clientSelected = $client08;
} elsif ($clientIn == 9) {
	$clientSelected = $client09;
} elsif ($clientIn == 10) {
	$clientSelected = $client10;
} elsif ($clientIn == 11) {
	$clientSelected = $client11;
} else {
	die "error: unknown client number";
}
# trade type (long or short)
if ($tradeTypeIn eq "long") {
	$tradeTypeSelected = $tradeTypeLong;
	$tradeIsALong = 1;
} elsif ($tradeTypeIn eq "short") {
	$tradeTypeSelected = $tradeTypeShort;
	$tradeIsALong = 0;
} else {
	die "error: TradeType must be 'long' or 'short'";
}
# cannot read "0" from command line, use "-1" for no leverage
if (($leverage<-1) or ($leverage >20)) { 
	die "error: incorrect leverage (-1 <= lev <=20)";
} else {
	$levCross  = $leverage;
}

say"";
say"";
say"";
say $pair;
say "Client: $clientSelected";
say "Trade Type: $tradeTypeSelected";
if ($levCross >= 1) { say "Leverage: Cross ($leverage.0X)"; }
say"";
say "Entry Targets:";
EvenDistribution($numberOfEntries,$highEntry,$lowEntry);
say"";
say "Take-Profit Targets:";
say"";
say "Stop Targets:";
say"";
say $trailingLine01;
say $trailingLine02;
say $trailingLine03;
say $trailingLine04;


	