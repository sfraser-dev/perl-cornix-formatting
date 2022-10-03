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
	$txtFile = "$dateWee-$pairNoSlash-$longOrShortStr\.trade";
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
	my $noDecimalPlacesForEntriesTargetsAndSLs=$_[5];
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
		my $val = formatToVariableNumberOfDecimalPlaces($entryOrTargetValsArr[$i],$noDecimalPlacesForEntriesTargetsAndSLs);
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
	my $weightingFactor=$_[5];
	my $noDecimalPlacesForEntriesTargetsAndSLs=$_[6];
	my @strArr;
	
	# run EvenDistribution calculation first
	@strArr = EvenDistribution($entriesOrTargetsStr,$noOfEntries,$high,$low,$tradeTypeIn,$noDecimalPlacesForEntriesTargetsAndSLs);
	
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
	# positive weightingFactor values weight towards the stop-loss
	# negative weightingFactor values weight towards the stop-loss
	for(my $x = 0; $x < (int($arrLengthPerc/2)); $x++){
		for(my $i = 0; $i < (int($arrLengthPerc/2))-$x; $i++){
			# my $ii = $indexPairs[$i]->key;
			my $p = $indexPairs[$i]->value;
			$percentages[$i]-=$weightingFactor;
			$percentages[$p]+=$weightingFactor;	
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
sub formatToVariableNumberOfDecimalPlaces {
	my $valIn = $_[0];
	my $decimalPlaces = $_[1];
	
	# sprintf("%.Xf",str) where X is variable
	my $temp = "%.$decimalPlaces"."f";			
	my $valOut = sprintf($temp, $valIn);
	
	return $valOut;
}

############################################################################
############################################################################
sub createCornixFreeTextAdvancedTemplate {
	my $pair = $_[0];
	my $clientSelected = $_[1];
	my $leverage = $_[2];
	my $noOfEntries = $_[3];
	my $highEntry = $_[4];
	my $lowEntry = $_[5];
	my $noOfTargets = $_[6];
	my $highTarget = $_[7];
	my $lowTarget = $_[8];
	my $stopLoss = $_[9];
	my $noDecimalPlacesForEntriesTargetsAndSLs = $_[10];
	my $isTradeALong = $_[11];
	my $weightingFactorEntries = $_[12];
	my $weightingFactorTargets = $_[13];
	my @template;
	my @strArr;
	my $strRead;
	my $riskSoftMult;
		
	push (@template, "########################### advanced template\n");
	
	# coin pairs
	push (@template, "$pair\n");
	
	# Cornix client
	push (@template, "Client: $clientSelected\n");
	
	# long or short trade
	if ($isTradeALong==1) 		{ push (@template, "Trade Type: Regular (Long)\n"); }
	elsif ($isTradeALong==0) 	{ push (@template, "Trade Type: Regular (Short)\n"); }
	else 						{ die "error: cannot determine if trade is a long or a short for writing template"; }
	
	# amount of leverage to use (if any at all, "-1" means no leverage)
	#if ($leverage >= 1) 		{ push (@template, "Leverage: Isolated ($leverage.0X)\n"); }
	if ($leverage >= 1) 		{ push (@template, "Leverage: Cross ($leverage.0X)\n"); }
	
	# entry targets
	push (@template,"\n");
	push (@template,"Entry Targets:\n");
	@strArr = HeavyWeightingAtEntryOrStoploss("entries",$noOfEntries,$highEntry,$lowEntry,$isTradeALong,$weightingFactorEntries,$noDecimalPlacesForEntriesTargetsAndSLs);
	foreach $strRead (@strArr) {
		push(@template,$strRead);
	}
	$riskSoftMult = riskSofteningMultiplier(\@strArr, $stopLoss); # passing array as reference

	# take profit targets
	push (@template,"\n");
	push (@template,"Take-Profit Targets:\n");
	@strArr = HeavyWeightingAtEntryOrStoploss("targets",$noOfTargets,$highTarget,$lowTarget,$isTradeALong,$weightingFactorTargets,$noDecimalPlacesForEntriesTargetsAndSLs);
	foreach $strRead (@strArr) {
		push(@template,$strRead);
	}


	# stop-loss
	my $sl = formatToVariableNumberOfDecimalPlaces($stopLoss, $noDecimalPlacesForEntriesTargetsAndSLs);
	push (@template,"\n");
	push (@template,"Stop Targets:\n1) $sl - 100%\n");
	push (@template,"\n");
	
	# trailing configuration
	my $trailingLine01 = "Trailing Configuration:";
	my $trailingLine02 = "Entry: Percentage (0.0%)";
	my $trailingLine03 = "Take-Profit: Percentage (0.0%)";
	my $trailingLine04 = "Stop: Breakeven -\n Trigger: Target (1)";
	push (@template,"$trailingLine01\n$trailingLine02\n$trailingLine03\n$trailingLine04\n\n");
	
	push (@template, "########################### risk softening multiplier\n$riskSoftMult\n");
	
	return @template;
}

############################################################################
############################################################################
sub readTradeConfigFile {
	# Cornix: max entries 10, only 1 SL allowed, max targets 10
	my $pathToFile = $_[0];
	my %dataHash = 	( 'coinPair' => "xxx/usdt",
					'client' => 999999,
					'leverage' => 999999,
					'numberOfEntries' => 0,
					'highEntry' => 0,
					'lowEntry' => 0,
					'stopLoss' => 0,
					'numberOfTargets' => 0,
					'lowTarget' => 0,
					'highTarget' => 0,
					'noDecimalPlacesForEntriesTargetsAndSLs' => 0
				);
	open my $info, $pathToFile or die "Could not open $pathToFile: $!";
	while( my $line = <$info>) { 
		my $temp = $line;
		$temp =~ s/^\s+|\s+$//g;	# remove leading and trailing whitespace
		if ($temp =~ /^#/) {		# is first character a '#' (ie: a comment)?
			next;
		}
		if ($line =~ m/coinPair/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{coinPair}=$val;
		}
		if ($line =~ m/client/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{client}=$val;
		}
		if ($line =~ m/leverage/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			if ($val<1 ) { $val = 0; }	# no leverage wanted, don't include leverage line in the template 
			$dataHash{leverage}=$val;
		}
		if ($line =~ m/numberOfEntries/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{numberOfEntries}=$val;
		}
		if ($line =~ m/highEntry/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{highEntry}=$val;
		}
		if ($line =~ m/lowEntry/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{lowEntry}=$val;
		}
		if ($line =~ m/stopLoss/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{stopLoss}=$val;
		}
		if ($line =~ m/numberOfTargets/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{numberOfTargets}=$val;
		}
		if ($line =~ m/lowTarget/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{lowTarget}=$val;
		}
		if ($line =~ m/highTarget/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{highTarget}=$val;
		}
		if ($line =~ m/decimalPlaces/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{noDecimalPlacesForEntriesTargetsAndSLs}=$val;
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
	my $noDecimalPlacesForEntriesTargetsAndSLs=$_[7];
	my @simpleTemplate; 

	push (@simpleTemplate, "########################### simple template\n");
	push(@simpleTemplate,"$pair\n");
	#if ($leverage >= 1) { push (@simpleTemplate, sprintf("leverage isolated %sx\n",$leverage)); }
	if ($leverage >= 1) { push (@simpleTemplate, sprintf("leverage cross %sx\n",$leverage)); }
	
	my $he = formatToVariableNumberOfDecimalPlaces($highEntry,$noDecimalPlacesForEntriesTargetsAndSLs);
	my $le = formatToVariableNumberOfDecimalPlaces($lowEntry,$noDecimalPlacesForEntriesTargetsAndSLs);
	my $ht = formatToVariableNumberOfDecimalPlaces($highTarget,$noDecimalPlacesForEntriesTargetsAndSLs);
	my $lt = formatToVariableNumberOfDecimalPlaces($lowTarget,$noDecimalPlacesForEntriesTargetsAndSLs);
	my $sl = formatToVariableNumberOfDecimalPlaces($stopLoss,$noDecimalPlacesForEntriesTargetsAndSLs);
	push(@simpleTemplate, "enter $he $le\n");
	push(@simpleTemplate, "stop $sl\n");
	push(@simpleTemplate, "targets $lt $ht\n");
	
	return @simpleTemplate;
}

############################################################################
############################################################################
sub getCornixClientName {
	my $clientNum=$_[0];
	my $retStr;
	
	if 		($clientNum == 1) 	{ $retStr = "BM BinFuts (main)"; }
	elsif 	($clientNum == 2) 	{ $retStr = "BM BinSpot (main)"; }	
	elsif 	($clientNum == 3) 	{ $retStr = "BM BybitKB7 Contract InvUSD (main) 260321"; }
	elsif 	($clientNum == 4) 	{ $retStr = "BM BybitKB7 Contract LinUSDT (main) 211128"; }	
	elsif 	($clientNum == 5) 	{ $retStr = "SF BinFuts (main)"; }	
	elsif 	($clientNum == 6) 	{ $retStr = "SF BinSpot (main)"; }	
	elsif 	($clientNum == 7) 	{ $retStr = "SF Bybit Contract InvUSD (main) 210318"; }	
	elsif 	($clientNum == 8) 	{ $retStr = "BM BybitKB7 Contract LinUSDT (main) 281121"; }	
	elsif 	($clientNum == 9) 	{ $retStr = "SF FtxFuturesPerp (main)"; }	
	elsif 	($clientNum == 10) 	{ $retStr = "SF FtxFSpot (main)"; }	
	elsif 	($clientNum == 11) 	{ $retStr = "SF KucoinSpot (main)"; }	
	elsif 	($clientNum == 12) 	{ $retStr = "SF Bybit Contract LinUSDT (main) 281121"; }	
	else 						{ die "error: can't determine Cornix client/exchange name"; }
	
	return $retStr;
}

############################################################################
############################################################################
sub checkValuesFromConfigFile {
	my $noOfEntries = $_[0];
	my $noOfTargets = $_[1];
	my $highEntry = $_[2];
	my $lowEntry = $_[3];
	my $highTarget = $_[4];
	my $lowTarget = $_[5];
	my $stopLoss = $_[6];
	my $leverage = $_[7];
	my $noDecimalPlacesForEntriesTargetsAndSLs = $_[8];

	# number of entries should be between 1 and 10 (Cornix free text maximum is 10)
	if (($noOfEntries<1) or ($noOfEntries>10)) { die "\nerror: noOfEntries should be 10 or less, \n"; }
	
	# number of targets should be between 1 and 10 (Cornix free text maximum is 10)	
	if (($noOfTargets<1) or ($noOfTargets>10)) { die "\nerror: noOfTargets should be 10 or less, \n"; }
	
	# make sure high entry is above the low entry
	if ($highEntry <= $lowEntry) { die "\nerror: highEntry is <= lowEntry\n"; }
	
	# make sure high target is above the low target
	if ($highTarget <= $lowTarget) { die "\nerror: highTarget is <= lowTarget\n"; }
	
	# determine if it's a long or a short trade
	my $isTradeALong;
	if (($highEntry>$highTarget) and ($highEntry>$lowTarget) and ($lowEntry>$highTarget) and ($lowEntry>$lowTarget)) {
		$isTradeALong = 0;
	} elsif (($highEntry<$highTarget) and ($highEntry<$lowTarget) and ($lowEntry<$highTarget) and ($lowEntry<$lowTarget)) {
		$isTradeALong = 1;
	} else {
		die "error: TradeType must be 'long' or 'short'";
	}
	
	# check stop-loss value makes sense
	if (($isTradeALong == 1) and ($stopLoss >= $lowEntry)) {
		die "error: wrong stop-loss placement for a long";
	} elsif (($isTradeALong == 0) and ($stopLoss <= $highEntry)) {
		die "error: wrong stop-loss placement for a short";
	}
	
	# leverage: cannot read "0" from command line, use "-1" for no leverage
	if (($leverage<-1) or ($leverage >20)) { 
		die "error: incorrect leverage (-1 <= lev <=20)";
	}
	
	# decimal places for entries and targets (so can ignore leading zeros in low sat coins)
	if (($noDecimalPlacesForEntriesTargetsAndSLs < 0) or ($noDecimalPlacesForEntriesTargetsAndSLs >10)) {
		die "error: issue with the amount of decimal places";
	}
	
	return $isTradeALong;
}

	
############################################################################
############################## main ########################################
############################################################################
# get command line arguments
my %args;
GetOptions( \%args,
			'file=s', 	# required: filename
			'ewf=s',	# required: entries weighting factor
			'twf=s',	# required: targets weighting factor
			'aoe=s',	# optional: amount of entries (override config file number of entries)
			'not=s'		# optional: number of targets (override config file number of targets)
          ) or die "Invalid command line arguments!";
my $pathToFile = $args{file};
my $weightingFactorEntries = $args{ewf};		# not in the trade config file
my $weightingFactorTargets = $args{twf};		# not in the trade config file
my $numberOfEntriesCommandLine = $args{aoe};	# in the config file, but override config file value if command line value given
my $numberOfTargetsCommandLine = $args{not};	# in the config file, but override config file value if command line value given

unless ($args{file}) 	{ die "Missing --file!\n"; }			# --file (-f) FileName 
unless ($args{ewf}) 	{ $weightingFactorEntries=0; }			# --ewf  (-e) entries weighting factor (for spreading percentages)
unless ($args{twf}) 	{ $weightingFactorTargets=0; }			# --twf  (-t) targets weighting factor (for spreading percentages)
unless ($args{aoe}) 	{ $numberOfEntriesCommandLine=0; }		# --aoe  (-a) amount of entries 
unless ($args{not}) 	{ $numberOfTargetsCommandLine=0; }		# --not  (-n) number of targets 

# read trade file
my %configHash = readTradeConfigFile($pathToFile);

# if number of entries/targets is given on the command line, override the number of entries/targets given in the config file
if ($numberOfEntriesCommandLine != 0) { $configHash{numberOfEntries} = $numberOfEntriesCommandLine; }
if ($numberOfTargetsCommandLine != 0) { $configHash{numberOfTargets} = $numberOfTargetsCommandLine; }

# check entries and targets make logical sense & determine if trade is a long or a short
my $isTradeALong = checkValuesFromConfigFile($configHash{numberOfEntries},
											$configHash{numberOfTargets},
											$configHash{highEntry},
											$configHash{lowEntry},
											$configHash{highTarget},
											$configHash{lowTarget},
											$configHash{stopLoss},
											$configHash{leverage},
											$configHash{noDecimalPlacesForEntriesTargetsAndSLs});
											
# old and simple way of using Cornix Free Text, generate a version of this too as well as the advanced template
my @cornixTemplateSimple = createCornixFreeTextSimpleTemplate($configHash{coinPair},
																	$configHash{leverage},
																	$configHash{highEntry},
																	$configHash{lowEntry},
																	$configHash{highTarget},
																	$configHash{lowTarget},
																	$configHash{stopLoss},
																	$configHash{noDecimalPlacesForEntriesTargetsAndSLs});

# create the advanced cornix template as an array of strings
my @cornixTemplateAdvanced = createCornixFreeTextAdvancedTemplate($configHash{coinPair},
													getCornixClientName($configHash{client}),
													$configHash{leverage},
													$configHash{numberOfEntries},
													$configHash{highEntry},
													$configHash{lowEntry},
													$configHash{numberOfTargets},
													$configHash{highTarget},
													$configHash{lowTarget},
													$configHash{stopLoss},
													$configHash{noDecimalPlacesForEntriesTargetsAndSLs},
													$isTradeALong,
													$weightingFactorEntries,
													$weightingFactorTargets);
													
# print templates to screen
say @cornixTemplateSimple;
say @cornixTemplateAdvanced;

# print template to file
my $scriptName = basename($0);
my $fileName = createOutputFileName($scriptName, $configHash{coinPair}, $isTradeALong);
my $fh;
open ($fh, '>', $fileName) or die ("Could not open file '$fileName' $!");
say $fh @cornixTemplateSimple;
say $fh @cornixTemplateAdvanced;

	