#!/usr/bin/perl
use warnings;
use strict;
use feature qw(say);
use Getopt::Long; # for processing command line args
use File::Basename;
use POSIX qw(strftime);


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
	my $noOfEntriesOrTargetsWanted=$_[0];
	my $high=$_[1];
	my $low=$_[2];
	# say "number of entries wanted: ".$noOfEntriesOrTargetsWanted;
	# say "high entry: $high";
	# say "low entry: $low";
	
	# get the entry values 
	my $highLowDiff = $high - $low;
	my $entryIncrement = $highLowDiff / ($noOfEntriesOrTargetsWanted-1);
	# say "The difference between high and low entries: $highLowDiff";
	# say "The increment is: $entryIncrement";
	my @entryOrTargetValsArr;
	for(my $i=0; $i<$noOfEntriesOrTargetsWanted; $i++){
		push (@entryOrTargetValsArr, $low+($entryIncrement*$i));
	}
	#print "entryOrTargetValsArr: @entryOrTargetValsArr\n";
	
	# get the percentage values 
	my $percentageIncrement = 100/$noOfEntriesOrTargetsWanted;
	# floor the percentage values to integers
	my $percentIncrementBase = int($percentageIncrement);
	#my $percentIncrementDecimal = sprintf("%.2f",$percentageIncrement-$percentIncrementBase);
	my @percentageArr;
	my $sum=0;
	for(my $i=0; $i<$noOfEntriesOrTargetsWanted; $i++){
		push (@percentageArr, $percentIncrementBase);
		$sum+=$percentIncrementBase;
	}
	#print "percentageArr: @percentageArr\n";
	#print "sum: $sum\n";
	# brute force the percentages to have a total of 100
	if ($sum<100){
		my $toAdd=100-$sum;
		my $arraySize=@percentageArr;
		for (my $i=0; $i<$toAdd; $i++){
			$percentageArr[$i]+=1;
		}
	}
	#print "entryOrTargetValsArr: @entryOrTargetValsArr\n";
	#print "percentageArr: @percentageArr\n";
	# print out the entries / targets and their percentage allocations
	for my $i (0 .. $#entryOrTargetValsArr){
		my $loc = $i+1;
		my $val = sprintf("%.5f",$entryOrTargetValsArr[$i]);
		my $perc = $percentageArr[$i];
		print "$loc) $val - $perc%\n";
	}
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
my $trailingLine04 = "Stop: Breakeven -\n Trigger: Target (1)";


my $script_name = basename($0);
my $usage = sprintf("usage is: %s -n NoEntries -h highEntry -l lowEntry -p CoinPair -c Client -t TradeType -v Leverage",$script_name); 
my $numberOfEntries;
my $highEntry;
my $lowEntry;
my $stopLoss;
my $numberOfTargets;
my $highTarget;
my $lowTarget;
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
			's=s', # stop-loss
			'p=s', # coin pair
			'c=s', # client
			't=s', # trade type
			'v=s', # leverage
			'x=s', # number of targets
			'y=s', # lowest target value
			'z=s'  # highest target value
          ) or die "Invalid command line arguments!";
die "Missing -n!\n".$usage unless $args{n};
die "Missing -h!\n".$usage unless $args{h};
die "Missing -l!\n".$usage unless $args{l};
die "Missing -s!\n".$usage unless $args{s};
die "Missing -p!\n".$usage unless $args{p};
die "Missing -c!\n".$usage unless $args{c};
die "Missing -t!\n".$usage unless $args{t};
die "Missing -v!\n".$usage unless $args{v};
die "Missing -x!\n".$usage unless $args{x};
die "Missing -y!\n".$usage unless $args{y};
die "Missing -z!\n".$usage unless $args{z};

$numberOfEntries = $args{n};
$highEntry = $args{h};
$lowEntry = $args{l};
$stopLoss = $args{s};
$pair = $args{p};
$clientIn = $args{c};
$tradeTypeIn = $args{t};
$leverage = $args{v};
$numberOfTargets = $args{x};
$lowTarget = $args{y};
$highTarget = $args{z};

# number of entries should be greater than 2
if ($numberOfEntries <= 2) { die "\nerror: numberOfEntries should be > 2\n".$usage; }
# make sure high entry is above the low entry
if ($highEntry <= $lowEntry) { die "\nerror: highEntry is <= lowEntry\n".$usage; }
# make sure high target is above the low target
if ($highTarget <= $lowTarget) { die "\nerror: highTarget is <= lowTarget\n".$usage; }
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
# leverage: cannot read "0" from command line, use "-1" for no leverage
if (($leverage<-1) or ($leverage >20)) { 
	die "error: incorrect leverage (-1 <= lev <=20)";
} else {
	$levCross  = $leverage;
}
# check stop-loss value makes sense
if (($tradeIsALong == 1) and ($stopLoss >= $lowEntry)) {
	die "error: wrong stop-loss placement for a long";
} elsif (($tradeIsALong == 0) and ($stopLoss <= $highEntry)) {
	die "error: wrong stop-loss placement for a short";
}

# print the cornix template
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
EvenDistribution($numberOfTargets,$highTarget,$lowTarget);
say"";
say "Stop Targets:\n1) $stopLoss - 100%";
say"";
say $trailingLine01;
say $trailingLine02;
say $trailingLine03;
say $trailingLine04;
say"";
say"";

# creating a filename
my $perlFilenameBase;
my $logFile;
my $date;
my $dateWee;
my $pairNoSlash;
$perlFilenameBase=basename($0);
$perlFilenameBase=~s/\.pl//;
say "$logFile";
$date = strftime "%Y%m%d", localtime;
$dateWee = substr($date, 2);
$pairNoSlash = $pair;
$pairNoSlash =~ s/\///g;
$logFile = "$perlFilenameBase-$dateWee-$pairNoSlash-$tradeTypeIn\.log";
print $logFile;

	