#!/usr/bin/perl
use warnings;
use strict;
use feature qw(say);
use Getopt::Long; # for processing command line args
use File::Basename;
use POSIX qw(strftime);
use List::Util qw(pairs);

############################################################################
############################################################################
sub createOutputFileName {
	my $scriptName = $_[0];
	my $pair = $_[1];
	my $isTradeALong = $_[2];
	my $txtFile;
	my $date;
	my $dateWee;
	my $pairNoSlash;
	my $longOrShortStr;
	$scriptName=~s/\.pl//;
	#$date = strftime "%Y%m%d-%H%M%S", localtime;
	$date = strftime "%Y%m%d-%H%M", localtime;
	#$date = strftime "%Y%m%d", localtime;
	$dateWee = substr($date, 2);
	$pairNoSlash = $pair;
	$pairNoSlash =~ s/\///g;
	if ($isTradeALong == 1) {
		$longOrShortStr="long";
	} elsif ($isTradeALong == 0) {
		$longOrShortStr="short";
	} else {
		die "error: trade is neither a long nor a short";
	}
	$txtFile = "$dateWee-$pairNoSlash-$longOrShortStr\.txt";
	return $txtFile;
}

############################################################################
############################################################################
sub EvenDistribution {
	my $entriesOrTargets=$_[0];
	my $noOfEntriesOrTargetsWanted=$_[1];
	my $high=$_[2];
	my $low=$_[3];
	my $isTradeALong=$_[4];
	my @strArr;
	
	# deal with only 1 entry (use "high" values, not the "low" values)
	if ($noOfEntriesOrTargetsWanted == 1) {
		push(@strArr,"1) $high - 100%\n");
		return @strArr;
	}
	
	# calc the entry/target values based on high, low and numberEntries given
	my $highLowDiff = $high - $low;
	my $entryIncrement = $highLowDiff / ($noOfEntriesOrTargetsWanted-1);
	my @entryOrTargetValsArr;
	# put entries or targets in the correct order based on whether longing or shorting
	if ($entriesOrTargets eq "entries") {
		# long entries
		if ($isTradeALong == 1) {
			for(my $i=0; $i<$noOfEntriesOrTargetsWanted; $i++){
				push (@entryOrTargetValsArr, $high-($entryIncrement*$i));
			}
		}
		# short entries
		elsif ($isTradeALong == 0) {
			for(my $i=0; $i<$noOfEntriesOrTargetsWanted; $i++){
				push (@entryOrTargetValsArr, $low+($entryIncrement*$i));
			}
		} 
		else {
			die "error: need to declare trade either a long or a short when generating entries";
		}
	}
	elsif ($entriesOrTargets eq "targets") {
		# long targets
		if ($isTradeALong == 1) {
			for(my $i=0; $i<$noOfEntriesOrTargetsWanted; $i++){
				push (@entryOrTargetValsArr, $low+($entryIncrement*$i));
			}
		}
		# short targets
		elsif ($isTradeALong == 0) {
			for(my $i=0; $i<$noOfEntriesOrTargetsWanted; $i++){
				push (@entryOrTargetValsArr, $high-($entryIncrement*$i));
			}
		} 
		else {
			die "error: need to declare trade either a long or a short when generating targets";
		}
	}
	else {
		die "error: need to declare if generating entries or targets";
	}
	
	# get the percentage values 
	my $percentageIncrement = 100/$noOfEntriesOrTargetsWanted;
	# floor the percentage values to integers
	my $percentIncrementBase = int($percentageIncrement);
	my @percentageArr;
	my $sum=0;
	for(my $i=0; $i<$noOfEntriesOrTargetsWanted; $i++){
		push (@percentageArr, $percentIncrementBase);
		$sum+=$percentIncrementBase;
	}
	
	# brute force the percentages to have a total of 100
	if ($sum<100){
		my $toAdd=100-$sum;
		my $arraySize=@percentageArr;
		for (my $i=0; $i<$toAdd; $i++){
			$percentageArr[$i]+=1;
		}
	}
	
	# print out the entries / targets and their percentage allocations
	for my $i (0 .. $#entryOrTargetValsArr){
		my $loc = $i+1;
		my $val = sprintf("%.5f",$entryOrTargetValsArr[$i]);
		my $perc = $percentageArr[$i];
		push(@strArr,"$loc) $val - $perc%\n");
	}
	
	return @strArr;
}

############################################################################
############################################################################
sub riskSofteningMultiplier {
	# assumes advanced template entries are in the correct order (whether long or shorting)
	my @strArr=@{$_[0]}; 					# dereference the passed array
	my $stopLoss=$_[1];
	
	my @splitter;
	my $entryPrice;
	my $firstEntryPrice = 0;
	my $percentage;
	
	my $arbitraryPositionValue = 10000;		# copy how calculated on spreadsheet
	my $amountSpentAtThisEntry;
	my $noCoinsObtainedAtThisEntry;
	my $totalCoinsObtained=0;
	
	my $riskPercentageBasedOnEntry1;
	my $avgEntryPrice;
	my $riskPercentageBasedOnAvgEntry;
	my $riskSoftMult;
	
	# Assigns arbitary position value ($10000). Based on this, calc number of coins
	# bought at each entry point (based on target entry price and assigned percentage)
	for my $i (0 .. $#strArr) {
		# get the values and percentages from the Cornix Entry Tragets: string array 
		@splitter=split / /, $strArr[$i];	# split line using spaces, [0]=1), [1]=value, [2]=hyphen, [3]=percentage
		$entryPrice = $splitter[1];
		if ($i == 0) { $firstEntryPrice = $entryPrice; }
		$percentage = ($splitter[3]);
		$percentage =~ s/%//g;				# remove percentage sign
		$percentage /= 100;					# percenatge as decimal
		
		# calculate the risk softening multiplier
		$amountSpentAtThisEntry = $arbitraryPositionValue * $percentage;
		$noCoinsObtainedAtThisEntry = $amountSpentAtThisEntry / $entryPrice;
		$totalCoinsObtained += $noCoinsObtainedAtThisEntry;		
	}
	$riskPercentageBasedOnEntry1 = (abs($firstEntryPrice-$stopLoss))/$firstEntryPrice;
	$avgEntryPrice = $arbitraryPositionValue / $totalCoinsObtained;
	$riskPercentageBasedOnAvgEntry = (abs($avgEntryPrice-$stopLoss))/$avgEntryPrice;
	$riskSoftMult = $riskPercentageBasedOnAvgEntry / $riskPercentageBasedOnEntry1;
	
	return $riskSoftMult;
}

############################################################################
############################################################################
sub HeavyWeightingAtEntryOrStoploss {
	my $entriesOrTargetsStr=$_[0];
	my $noOfEntries=$_[1];
	my $high=$_[2];
	my $low=$_[3];
	my $tradeTypeIn=$_[4];
	my $weightingFactorCommandLine=$_[5];
	my @strArr;
	
	# run EvenDistribution calculation first
	@strArr = EvenDistribution($entriesOrTargetsStr,$noOfEntries,$high,$low,$tradeTypeIn);
	
	# get the percentages from @strArr
	my @percentages;
	for my $i (0 .. $#strArr) {
		my @splitter=split / /, $strArr[$i];	# split line using spaces, [0]=1), [1]=value, [2]=hyphen, [3]=percentage
		my $percentage = ($splitter[3]);
		$percentage =~ s/%//g;					# remove percentage sign
		push (@percentages, $percentage);
	}
	
	# is there an odd or even number of percentages?
	my $arrLengthPerc = @percentages;
	my $mod = $arrLengthPerc % 2;
	my $quot = int($arrLengthPerc / 2);
	my $isEven;
	if ($mod == 0) {
		$isEven = 1;
	} elsif ($mod == 1) {
		$isEven = 0;
	} else {
		die "error: modulus calculation error";
	}
	
	# create an array of percentage "pairs" (next to each other in the array)
	my @temp;						
	for(my $i = 0; $i < (int($arrLengthPerc/2)); $i++){
		push(@temp, $i);
		push(@temp, ($arrLengthPerc-1-$i));
	}
	# convert this array into a "pairs value" index array
	my @indexPairs = pairs @temp;
	
	### array indexes, length 6 (even length)
	# 00 01 02 03 04 05
	### values
	# 10 10 10 10 10 10		initial array values 
	# 12 12 12 08 08 08		iteration 1 (weighting factor 2)
	# 14 14 12 08 06 06		iteration 2 (weighting factor 2)
	# 16 14 12 08 06 04		iteration 3 (weighting factor 2)
	### index pairs
	# 0,5 (0...length-1)
	# 1,4 (1...length-2)
	# 2,3 (2...length-3)
	#########################################
	### array indexes, length 5 (odd length)
	# 00 01 02 03 04 
	### values
	# 10 10 10 10 10		initial array values 
	# 12 12 10 08 08		iteration 1 (weighting factor 2)
	# 14 12 10 08 06		iteration 2 (weighting factor 2)
	### index pairs
	# 0,4 (0...length-1)
	# 1,3 (1...length-2)
	#
	# positive weightingFactorCommandLine values weight towards the stop-loss
	# negative weightingFactorCommandLine values weight towards the stop-loss
	for(my $x = 0; $x < (int($arrLengthPerc/2)); $x++){
		for(my $i = 0; $i < (int($arrLengthPerc/2))-$x; $i++){
			# my $ii = $indexPairs[$i]->key;
			my $p = $indexPairs[$i]->value;
			$percentages[$i]-=$weightingFactorCommandLine;
			$percentages[$p]+=$weightingFactorCommandLine;	
		}
	}

	# update strArr with the new weighted percentages
	my @strArrNewPercentages;
	for my $i (0 .. $#strArr) {
		my @splitter=split / /, $strArr[$i];	# split line using spaces, [0]=1), [1]=value, [2]=hyphen, [3]=percentage
		my $num = ($splitter[0]);
		my $val = ($splitter[1]);
		my $hash = ($splitter[2]);
		my $per = ($splitter[3]);
		$per = sprintf("%.2f", $percentages[$i]);
		my $newline = $num." ".$val." ".$hash." "."$per%\n";
		push(@strArrNewPercentages, $newline);
	}
			
	return @strArrNewPercentages;
}

############################################################################
############################################################################
sub createAdvancedTemplate {
	my $pair = $_[0];
	my $clientSelected = $_[1];
	my $tradeTypeSelectedCornixStr = $_[2];
	my $leverage = $_[3];
	my $noOfEntries = $_[4];
	my $highEntry = $_[5];
	my $lowEntry = $_[6];
	my $noOfTargets = $_[7];
	my $highTarget = $_[8];
	my $lowTarget = $_[9];
	my $stopLoss = $_[10];
	my $trailingConfig = $_[11];
	my $isTradeALong = $_[12];
	my $weightingFactorCommandLine = $_[13];
	my @template;
	my @strArr;
	my $strRead;
	my $riskSoftMult;
	
	push (@template, "########################### advanced template\n");
	push (@template, "$pair\n");
	push (@template, "Client: $clientSelected\n");
	push (@template, "Trade Type: $tradeTypeSelectedCornixStr\n");
	if ($leverage >= 1) { push (@template, "Leverage: Cross ($leverage.0X)\n"); }
	
	push (@template,"\n");
	push (@template,"Entry Targets:\n");
	#@strArr = EvenDistribution("entries",$noOfEntries,$highEntry,$lowEntry,$isTradeALong);
	@strArr = HeavyWeightingAtEntryOrStoploss("entries",$noOfEntries,$highEntry,$lowEntry,$isTradeALong,$weightingFactorCommandLine);
	foreach $strRead (@strArr) {
		push(@template,$strRead);
	}
	$riskSoftMult = riskSofteningMultiplier(\@strArr, $stopLoss); # passing array as reference

	push (@template,"\n");
	push (@template,"Take-Profit Targets:\n");
	@strArr = EvenDistribution("targets",$noOfTargets,$highTarget,$lowTarget,$isTradeALong);
	#@strArr = EntryHeavyWeighting("targets",$noOfTargets,$highTarget,$lowTarget,$isTradeALong);
	foreach $strRead (@strArr) {
		push(@template,$strRead);
	}
	
	push (@template,"\n");
	push (@template,"Stop Targets:\n1) $stopLoss - 100%\n");
	
	push (@template,"\n");
	push (@template,"$trailingConfig\n");
	
	push (@template, "########################### risk softening multiplier\n$riskSoftMult\n");
	
	return @template;
}

############################################################################
############################################################################
sub readTradeConfigFile {
	# Cornix: max entries 10, only 1 SL allowed, max targets 10
	my $path_to_file = $_[0];
	my %dataHash = 	( 'coinPair' => "xxx/usdt",
					'client' => 999999,
					'leverage' => 999999,
					'numberOfEntries' => 0,
					'highEntry' => 0,
					'lowEntry' => 0,
					'stopLoss' => 0,
					'numberOfTargets' => 0,
					'lowTarget' => 0,
					'highTarget' => 0
				);
	open my $info, $path_to_file or die "Could not open $path_to_file: $!";
	while( my $line = <$info>) { 
		my $temp = $line;
		$temp =~ s/^\s+|\s+$//g;	# remove leading and trailing whitespace
		if ($temp =~ /^#/) {		# is first character a '#' (ie: a comment)?
			next;
		}
		if ($line =~ m/coinPair/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{coinPair}=$val;
		}
		if ($line =~ m/client/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{client}=$val;
		}
		if ($line =~ m/leverage/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{leverage}=$val;
		}
		if ($line =~ m/numberOfEntries/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{numberOfEntries}=$val;
		}
		if ($line =~ m/highEntry/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{highEntry}=$val;
		}
		if ($line =~ m/lowEntry/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{lowEntry}=$val;
		}
		if ($line =~ m/stopLoss/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{stopLoss}=$val;
		}
		if ($line =~ m/numberOfTargets/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{numberOfTargets}=$val;
		}
		if ($line =~ m/lowTarget/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{lowTarget}=$val;
		}
		if ($line =~ m/highTarget/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			chomp($val);
			$dataHash{highTarget}=$val;
		}
	}
	close $info;
	return %dataHash;
}

############################################################################
############################################################################
sub createCornixFreeTextSimpleTemplate {
	my $pair=$_[0];
	my $leverage=$_[1];
	my $highEntry=$_[2];
	my $lowEntry=$_[3];
	my $highTarget=$_[4];
	my $lowTarget=$_[5];
	my $stopLoss=$_[6];
	my @simpleTemplate; 

	push (@simpleTemplate, "########################### simple template\n");
	push(@simpleTemplate,"$pair\n");
	if ($leverage >= 1) { push (@simpleTemplate, sprintf("leverage cross %sx\n",$leverage)); }
	push(@simpleTemplate, "enter $highEntry $lowEntry\n");
	push(@simpleTemplate, "stop $stopLoss\n");
	push(@simpleTemplate, "targets $lowTarget $highTarget\n");
	
	return @simpleTemplate;
}


############################################################################
############################## main ########################################
############################################################################

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
my $client12 = "SF Bybit Contract LinUSDT (main) 281121";
########## Trade Type: 
my $tradeTypeLongStr = "Regular (Long)";
my $tradeTypeShortStr = "Regular (Short)";
########## Leverage: 
#my $levIsoStr = "Isolated"; 	## Leverage: Isolated (4.0X)!!!!!
my $levCrossStr = "Cross";  	## Leverage: Cross (4.0X)!!!!!
########## Trailing: 
my $trailingLine01 = "Trailing Configuration:";
my $trailingLine02 = "Entry: Percentage (0.0%)";
my $trailingLine03 = "Take-Profit: Percentage (0.0%)";
my $trailingLine04 = "Stop: Breakeven -\n Trigger: Target (1)";
my $trailingConfig = "$trailingLine01\n$trailingLine02\n$trailingLine03\n$trailingLine04\n";

my $script_name = basename($0);
my $usage = sprintf("usage is: %s -f tradeSetup.txt",$script_name); 
my $noOfEntries;
my $highEntry;
my $lowEntry;
my $stopLoss;
my $noOfTargets;
my $highTarget;
my $lowTarget;
my $pair;
my $clientIn;
my $clientSelected;
my $tradeTypeSelectedCornixStr;
my $leverage;
my $isTradeALong;
my @cornixTemplateAdvanced;
my $fileName;
my $fh;
my $pathToFileCommandLine;
my $weightingFactorCommandLine;
my %dataHash;
my %args;
my @cornixFreeTextSimpleTemplate;
GetOptions( \%args,
			'file=s', 	# filename
			'wf=s'		# weighting factor (override config file weighting factor)
          ) or die "Invalid command line arguments!";
$pathToFileCommandLine = $args{file};
$weightingFactorCommandLine = $args{wf};
unless ($args{file}) {
	die "Missing --file!\n".$usage;
}
unless ($args{wf}) {
	$weightingFactorCommandLine=0;
}
# read trade file
%dataHash = readTradeConfigFile($pathToFileCommandLine);

# assign key pairs from hash to variables
$pair = $dataHash{coinPair};
$clientIn = $dataHash{client};
$leverage = $dataHash{leverage};
$noOfEntries = $dataHash{numberOfEntries};
$highEntry = $dataHash{highEntry};
$lowEntry = $dataHash{lowEntry};
$stopLoss = $dataHash{stopLoss};
$noOfTargets = $dataHash{numberOfTargets};
$lowTarget = $dataHash{lowTarget};
$highTarget = $dataHash{highTarget};

# remove white space from start and end of variables
$pair =~ s/^\s+|\s+$//g;
$clientIn =~ s/^\s+|\s+$//g;
$leverage =~ s/^\s+|\s+$//g;
$noOfEntries =~ s/^\s+|\s+$//g;
$highEntry =~ s/^\s+|\s+$//g;
$lowEntry =~ s/^\s+|\s+$//g;
$stopLoss =~ s/^\s+|\s+$//g;
$noOfTargets =~ s/^\s+|\s+$//g;
$lowTarget =~ s/^\s+|\s+$//g;
$highTarget =~ s/^\s+|\s+$//g;

# number of entries should be between 1 and 10 (Cornix free text maximum is 10)
if (($noOfEntries<1) or ($noOfEntries>10)) { die "\nerror: noOfEntries should be 10 or less, \n".$usage; }
# number of targets should be between 1 and 10 (Cornix free text maximum is 10)
if (($noOfTargets<1) or ($noOfTargets>10)) { die "\nerror: noOfTargets should be 10 or less, \n".$usage; }
# make sure high entry is above the low entry
if ($highEntry <= $lowEntry) { die "\nerror: highEntry is <= lowEntry\n".$usage; }
# make sure high target is above the low target
if ($highTarget <= $lowTarget) { die "\nerror: highTarget is <= lowTarget\n".$usage; }
# determine if it's a long or a short trade
if (($highEntry>$highTarget) and ($highEntry>$lowTarget) and ($lowEntry>$highTarget) and ($lowEntry>$lowTarget)) {
	$tradeTypeSelectedCornixStr = $tradeTypeShortStr;
	$isTradeALong = 0;
} elsif (($highEntry<$highTarget) and ($highEntry<$lowTarget) and ($lowEntry<$highTarget) and ($lowEntry<$lowTarget)) {
	$tradeTypeSelectedCornixStr = $tradeTypeLongStr;
	$isTradeALong = 1;
} else {
	die "error: TradeType must be 'long' or 'short'";
}
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
} elsif ($clientIn == 12) {
	$clientSelected = $client12;
} else {
	die "error: unknown client number";
}
# leverage: cannot read "0" from command line, use "-1" for no leverage
if (($leverage<-1) or ($leverage >20)) { 
	die "error: incorrect leverage (-1 <= lev <=20)";
}
# check stop-loss value makes sense
if (($isTradeALong == 1) and ($stopLoss >= $lowEntry)) {
	die "error: wrong stop-loss placement for a long";
} elsif (($isTradeALong == 0) and ($stopLoss <= $highEntry)) {
	die "error: wrong stop-loss placement for a short";
}

# old and simple way of using Cornix Free Text, generate a version of this too as well as the complex template
@cornixFreeTextSimpleTemplate = createCornixFreeTextSimpleTemplate($pair,$leverage,$highEntry,$lowEntry,$highTarget,$lowTarget,$stopLoss);


# create the cornix template as an array of strings
@cornixTemplateAdvanced = createAdvancedTemplate(		$pair,$clientSelected,$tradeTypeSelectedCornixStr,
								$leverage,$noOfEntries,$highEntry,$lowEntry,$noOfTargets,
								$highTarget,$lowTarget,$stopLoss,$trailingConfig,$isTradeALong,$weightingFactorCommandLine);

# print templates to screen
say @cornixFreeTextSimpleTemplate;
say @cornixTemplateAdvanced;
# print template to file
$fileName = createOutputFileName($script_name, $pair, $isTradeALong);
open ($fh, '>', $fileName) or die ("Could not open file '$fileName' $!");
say $fh @cornixFreeTextSimpleTemplate;
say $fh @cornixTemplateAdvanced;

	