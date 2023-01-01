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
sub readTradeConfigFile {
	# Cornix: max entries 10, only 1 SL allowed, max targets 10
	my $pathToFile = $_[0];
	my %dataHash = 	( 'coinPair' => "xxx/usdt",
					'client' => 999999,
					'leverage' => 999999,
					'entryValue' => 0,
					'stopLoss' => 0,
					'targetValue' => 0,
					'noDecimalPlacesForEntriesTargetsAndSLs' => 0,
					'wantedToRiskAmount' => 999999,
					'noOfAddOns' => 0,
					'addOnReduceMultiple' => 1
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
		if ($line =~ m/entryValue/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{entryValue}=$val;
		}
		if ($line =~ m/stopLoss/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{stopLoss}=$val;
		}
		if ($line =~ m/targetValue/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{targetValue}=$val;
		}
		if ($line =~ m/numDecimalPlacesForCoinPrices/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{noDecimalPlacesForEntriesTargetsAndSLs}=$val;
		}
		if ($line =~ m/wantedToRiskAmount/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{wantedToRiskAmount}=$val;
		}
		if ($line =~ m/noOfAddOns/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{noOfAddOns}=$val;
		}
		if ($line =~ m/addOnReduceMultiple/) { 
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{addOnReduceMultiple}=$val;
		}
	}
	close $info;
	return %dataHash;
}

############################################################################
############################################################################
sub createCornixFreeTextSimpleTemplateTT {
	my $pair=$_[0];
	my $leverage=$_[1];
	my $entryValue=$_[2];
	my $targetValue=$_[3];
	my $stopLoss=$_[4];
	my $noDecimalPlacesForEntriesTargetsAndSLs=$_[5];
	my $forLoopInc=$_[6];
	my @simpleTemplate; 

	if ($forLoopInc==0) { push (@simpleTemplate, "########################### simple template base trade\n"); }
	else { push (@simpleTemplate, "########################### simple template add-on $forLoopInc\n"); }
	
	push(@simpleTemplate,"$pair\n");
	if ($leverage >= 1) { push (@simpleTemplate, sprintf("leverage cross %sx\n",$leverage)); }
	
	my $ent = formatToVariableNumberOfDecimalPlaces($entryValue,$noDecimalPlacesForEntriesTargetsAndSLs);
	my $targ = formatToVariableNumberOfDecimalPlaces($targetValue,$noDecimalPlacesForEntriesTargetsAndSLs);
	my $sl = formatToVariableNumberOfDecimalPlaces($stopLoss,$noDecimalPlacesForEntriesTargetsAndSLs);
	push(@simpleTemplate, "enter $ent\n");
	push(@simpleTemplate, "stop $sl\n");
	push(@simpleTemplate, "targets $targ\n");
	
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
	my $entryValue = $_[0];
	my $targetValue = $_[1];
	my $stopLoss = $_[2];
	my $leverage = $_[3];
	my $noDecimalPlacesForEntriesTargetsAndSLs = $_[4];
	my $wantedToRiskAmount = $_[5];
	my $noOfAddOns = $_[6];
	my $addOnReduceMultiple = $_[7];
	
	# determine if it's a long or a short trade
	my $isTradeALong;
	if ($entryValue>$targetValue) {
		$isTradeALong = 0;
	} elsif ($entryValue<$targetValue) {
		$isTradeALong = 1;
	} else {
		die "error: TradeType must be 'long' or 'short'";
	}
	
	# check stop-loss value makes sense
	if (($isTradeALong == 1) and ($stopLoss >= $entryValue)) {
		die "error: wrong stop-loss placement for a long";
	} elsif (($isTradeALong == 0) and ($stopLoss <= $entryValue)) {
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
	
	# the risked amount
	if ($wantedToRiskAmount <= 0) { die "\nerror: wantedToRiskAmount is <= 0\n"; }
	
	# TT number of add-ons
	if ($noOfAddOns <= 0) { die "\nerror: noOfAddOns is <= 0\n"; }
	
	# TT add-on reduce multiple (add the same amount of risk at each add on (1) or reduce the amount of risk at each add on (>1))
	if (($addOnReduceMultiple < 1) or ($addOnReduceMultiple > 3)) { 
		die "\nerror: addOnReduceMultiple is not a sensible value\n";
	}
	
	return $isTradeALong;
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
sub printArrayToScreen {
	my @arr = @{$_[0]}; 				# dereference the passed array
	my $decimalPlaces = $_[1];
	my $len = scalar(@arr);
	for(my $i = 0; $i < $len; $i++){
		my $temp = formatToVariableNumberOfDecimalPlaces($arr[$i], $decimalPlaces);
		print("$temp ");
	}
	print("\n");	
}

############################################################################
############################################################################
sub trade_stats {
	my $ent = $_[0];
	my $tar= $_[1];
	my $sl = $_[2];
	my $wantedToRiskAmount = $_[3];
	
	my $wantedToRiskPercentage = (abs($ent-$sl))/$ent;
	my $requiredPositionSize =  $wantedToRiskAmount / $wantedToRiskPercentage;
	
	say"-----";
	say"wantedToRiskAmount=$wantedToRiskAmount";
	say"wantedToRiskPercentage=$wantedToRiskPercentage";
	say"requiredPositionSize=$requiredPositionSize\n";
}

############################################################################
############################################################################
sub tt_begin {
	my $ent1 = $_[0];
	my $targ1= $_[1];
	my $sl1 = $_[2];
	my $noOfAddOns = $_[3];
	my $wantedToRiskAmount = $_[4];
	my $isTradeALong = $_[5];
	my $coinPair = $_[6];
	my $leverage = $_[7];
	my $noDecimalPlacesForEntriesTargetsAndSLs = $_[8];
	my $addOnReduceMultiple = $_[9];

	my $totalNumberOfTradesOriginalAndAddons = $noOfAddOns+1;	# the original trade plus the required noOfAddOns  
	my $theStepSize = (abs($ent1-$sl1))/$totalNumberOfTradesOriginalAndAddons;

	say"noOfAddOns wanted=$noOfAddOns";

	if ($isTradeALong==1) {		
		# arrays for original trade and calculated TT add-ons
		my @entriesArr;
		my @targetsArr;
		my @stoplossArr;
		
		# the original trade
		push(@entriesArr,$ent1);
		push(@targetsArr,$targ1);
		push(@stoplossArr,$sl1);

		# the required TT add-ons
		for(my $i = 1; $i < $totalNumberOfTradesOriginalAndAddons; $i++){
			push(@entriesArr, $entriesArr[$i-1]+$theStepSize);
			push(@targetsArr, $targetsArr[$i-1]+$theStepSize);
			push(@stoplossArr,$stoplossArr[$i-1]+$theStepSize);
		}
		# print the original and add-on arrays
		# print("entries: "); printArrayToScreen(\@entriesArr, 1);
		# print("stoplosses: "); printArrayToScreen(\@stoplossArr, 1);
		# print("targets: "); printArrayToScreen(\@targetsArr, 1);
		
		# create simple cornix free text templates for the original trade and add-ons 
		my @multipleCornixTemplatesSimple;
		for(my $i = 0; $i < $totalNumberOfTradesOriginalAndAddons; $i++){
			my @tempCornixSimple = createCornixFreeTextSimpleTemplateTT($coinPair, $leverage, $entriesArr[$i], $targetsArr[$i],
																		$stoplossArr[$i], $noDecimalPlacesForEntriesTargetsAndSLs,
																		$i);
			print @tempCornixSimple;
			trade_stats($entriesArr[$i], $targetsArr[$i], $stoplossArr[$i], $wantedToRiskAmount);
			push(@multipleCornixTemplatesSimple, @tempCornixSimple);
			$wantedToRiskAmount /= $addOnReduceMultiple;		# skyscraper building
		}
		
		#say @multipleCornixTemplatesSimple; 
	}
	
	

}

############################################################################
############################## main ########################################
############################################################################
# get command line arguments
my %args;
GetOptions( \%args,
			'file=s', 	# required: filename
          ) or die "Invalid command line arguments!";
my $pathToFile = $args{file};
unless ($args{file}) 	{ die "Missing --file!\n"; }			# --file (-f) FileName 

# read trade file
my %configHash = readTradeConfigFile($pathToFile);

# check entries and targets make logical sense & determine if trade is a long or a short
my $isTradeALong = checkValuesFromConfigFile(	$configHash{entryValue},
												$configHash{targetValue},
												$configHash{stopLoss},
												$configHash{leverage},
												$configHash{noDecimalPlacesForEntriesTargetsAndSLs},
												$configHash{wantedToRiskAmount},
												$configHash{noOfAddOns},
												$configHash{addOnReduceMultiple}
											);
																	
tt_begin($configHash{entryValue}, $configHash{targetValue},	$configHash{stopLoss},
			$configHash{noOfAddOns}, $configHash{wantedToRiskAmount}, $isTradeALong,
			$configHash{coinPair}, $configHash{leverage}, $configHash{noDecimalPlacesForEntriesTargetsAndSLs},
			$configHash{addOnReduceMultiple});

# print templates to screen
#say @cornixTemplateSimple;

# # print template to file
# my $scriptName = basename($0);
# my $fileName = createOutputFileName($scriptName, $configHash{coinPair}, $isTradeALong);
# my $fh;
# open ($fh, '>', $fileName) or die ("Could not open file '$fileName' $!");
# say $fh @cornixTemplateSimple;
