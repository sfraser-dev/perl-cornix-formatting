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
	$txtFile = "$dateWee-$pairNoSlash-$longOrShortStr-tt\.trade";
	return $txtFile;
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
sub removeMidLineComments {
	my $line = $_[0];
	if ($line =~ m/#/) { 
		my @arr = split(/#/,$line);
		$line = $arr[0];
	}
	
	return $line;
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
					'noOfAddOns' => 999999,
					'addOnSoftenerMultiple' => 999999,
					'stepSizeInR' => 999999
				);
	open my $info, $pathToFile or die "Could not open $pathToFile: $!";
	while( my $line = <$info>) { 
		my $temp = $line;
		$temp =~ s/^\s+|\s+$//g;	# remove leading and trailing whitespace
		if ($temp =~ /^#/) {		# is first character a '#' (ie: a comment)?
			next;
		}
		$line = removeMidLineComments($line);
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
		if ($line =~ m/addOnSoftenerMultiple/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{addOnSoftenerMultiple}=$val;
		}
		if ($line =~ m/stepSizeInR/) {
			my @splitter = split(/=/,$line);
			my $val = $splitter[1];
			$val =~ s/^\s+|\s+$//g;		# remove white space from start and end of variables
			$dataHash{stepSizeInR}=$val;
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
	my $forLoopIncrement=$_[6];
	my $isTradeALong=$_[7];
	my @simpleTemplate; 

	if ($forLoopIncrement==0) { push (@simpleTemplate, "########################### simple template base 0\n"); }
	else { push (@simpleTemplate, "########################### simple template add-on $forLoopIncrement\n"); }
	
	push(@simpleTemplate,"$pair\n");
	if ($leverage >= 1) { push (@simpleTemplate, sprintf("leverage cross %sx\n",$leverage)); }
	
	my $ent = formatToVariableNumberOfDecimalPlaces($entryValue,$noDecimalPlacesForEntriesTargetsAndSLs);
	my $targ = formatToVariableNumberOfDecimalPlaces($targetValue,$noDecimalPlacesForEntriesTargetsAndSLs);
	my $sl = formatToVariableNumberOfDecimalPlaces($stopLoss,$noDecimalPlacesForEntriesTargetsAndSLs);
	# make base trades regular trades  
	if ($forLoopIncrement==0) { ($isTradeALong==1) ? push(@simpleTemplate, "enter $ent\n") : push(@simpleTemplate, "enter $ent\n"); }
	# make add-on trades breakout trades 
	else { ($isTradeALong==1) ? push(@simpleTemplate, "enter above $ent\n") : push(@simpleTemplate, "enter below $ent\n"); }
	push(@simpleTemplate, "stop $sl\n");
	push(@simpleTemplate, "targets $targ\n");
	
	return @simpleTemplate;
}

############################################################################
############################################################################
sub createCornixFreeTextAdvancedTemplateTT_PercentBelowHighest {
	my $pair = $_[0];
	my $clientSelected = $_[1];
	my $leverage = $_[2];
	my $entryValue = $_[3];
	my $targetValue = $_[4];
	my $stopLoss = $_[5];
	my $noDecimalPlacesForEntriesTargetsAndSLs = $_[6];
	my $forLoopIncrement = $_[7];
	my $isTradeALong = $_[8];
	my $stepSizeInR = $_[9];
	
	my @template;
	if ($forLoopIncrement==0) { push (@template, "########################### advanced template base 0\n"); }
	else { push (@template, "########################### advanced template add-on $forLoopIncrement\n"); }
	
	# coin pairs
	push (@template, "$pair\n");
	
	# Cornix client
	my $clientName = getCornixClientName($clientSelected);
	push (@template, "Client: $clientName\n");
	
	# make base trades regular trades  
	if($forLoopIncrement==0) {
		($isTradeALong==1) ? push(@template,"Trade Type: Regular (Long)\n") : push(@template, "Trade Type: Regular (Short)\n");
	}
	# make add-on trades breakout trades 
	else {
		($isTradeALong==1) ? push(@template,"Trade Type: Breakout (Long)\n") : push(@template, "Trade Type: Breakout (Short)\n");
	}
	
	# amount of leverage to use (if any at all, "-1" means no leverage)
	#if ($leverage >= 1) 		{ push (@template, "Leverage: Isolated ($leverage.0X)\n"); }
	if ($leverage >= 1) 		{ push (@template, "Leverage: Cross ($leverage.0X)\n"); }
	
	# entry, target and SL
	push (@template,"Entry Targets:\n1) $entryValue - 100%\n");
	push (@template,"Take-Profit Targets:\n1) $targetValue - 100%\n");
	push (@template,"Stop Targets:\n1) $stopLoss - 100%\n");

	# trailing configuration
	my $stoplossPercentage_R = (abs($entryValue-$stopLoss)) / $entryValue;		 # R
	my $trailingStoplossTrigger_percentageAboveEntry = $stoplossPercentage_R * $stepSizeInR * 100;
	my $trailingStoplossDistance_percentageBelowHighestPriceReached = $stoplossPercentage_R * 100;
	$trailingStoplossTrigger_percentageAboveEntry = formatToVariableNumberOfDecimalPlaces($trailingStoplossTrigger_percentageAboveEntry, 2);
	$trailingStoplossDistance_percentageBelowHighestPriceReached = formatToVariableNumberOfDecimalPlaces($trailingStoplossDistance_percentageBelowHighestPriceReached, 2);
	
	my $trailingLine01 = "Trailing Configuration:";
	my $trailingLine02 = "Entry: Percentage (0.0%)";
	my $trailingLine03 = "Take-Profit: Percentage (0.0%)";
	my $trailingLine04 = "Stop: Percent Below Highest ($trailingStoplossDistance_percentageBelowHighestPriceReached%) -";
	my $trailingLine05 = " Trigger: Percent ($trailingStoplossTrigger_percentageAboveEntry%)";
	push (@template,"$trailingLine01\n$trailingLine02\n$trailingLine03\n$trailingLine04\n$trailingLine05\n");
	
	return @template;
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
	my $addOnSoftenerMultiple = $_[7];
	my $stepSizeInR = $_[8];
	
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
	
	# TT the risked amount
	if ($wantedToRiskAmount <= 0) { die "\nerror: wantedToRiskAmount is <= 0\n"; }
	
	# TT number of add-ons (Cornix can only have 3 trades of the same symbol at the same time (ie: the base trade and 2 add-ons)
	if ($noOfAddOns != 0) {
		if ($noOfAddOns != 1) {
			if ($noOfAddOns != 2) {
				die "\nerror: noOfAddOns should be 0, 1 or 2\n";
			}
		}
	}
	
	# TT add-on reduce multiple (add the same amount of risk at each add on (1) or reduce the amount of risk at each add on (<1))
	if (($addOnSoftenerMultiple > 1) or ($addOnSoftenerMultiple <= 0)) { 
		die "\nerror: addOnSoftenerMultiple should be between 0 and 1\n";
	}
	
	# TT the stepsize (in R) for add-ons to be implemented
	if (($stepSizeInR < 0.25) or ($stepSizeInR > 0.5)) {
		die "\nerror: stepSizeInR should be between 0.25R and 0.50R\n";
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
	
	my @arr;
	push(@arr,"---------------------------\n");
	my $str1 = sprintf("\$%.2f",$wantedToRiskAmount); 
	$wantedToRiskPercentage *= 100;
	my $str2 = sprintf("%.2f",$wantedToRiskPercentage);
	$str2 = $str2."%";
	my $str3 = sprintf("\$%.2f",$requiredPositionSize); 		
	push(@arr,"wantedToRiskAmount=$str1\n");
	push(@arr,"wantedToRiskPercentage=$str2\n");
	push(@arr,"requiredPositionSize=$str3\n");
	push(@arr,"\n");
	
	return @arr;
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
	my $addOnSoftenerMultiple = $_[9];
	my $stepSizeInR = $_[10];
	my $clientSelected = $_[11];
	
	my $totalNumberOfTradesOriginalAndAddons = $noOfAddOns + 1;
	my $theStepSize = (abs($ent1-$sl1))*$stepSizeInR;

	# arrays for original trade and calculated TT add-ons templates 
	# note: these will all have the same SLs & targets (determined by base), only the entries will be different
	# the SLs in the guidebook arrays will show what the SLs need to be manually set to as the trade progresses
	my @entriesArr;
	my @targetsArr;
	my @stoplossArr;
	my @guideBookSLs;				# ideal SLs that will need to be manually set
									# cannot preset add-on SLs above base entry or add-on trades will be cancelled by Cornix
		
	# the original trade...
	push(@entriesArr,$ent1); 
	push(@targetsArr,$targ1);
	push(@stoplossArr,$sl1);
	push(@guideBookSLs,$sl1);	

	# ...TT add-ons
	my $wantedToRiskPercentage = (abs($ent1-$sl1))/$ent1; 
	my $addOnOption = 1;
	# Same SL distances (eg:1000) at different entries results in different risk percentages1000/18000
	# SL distance of 1000: 1000/18000=0.061, 1000/18500=0.054
	# Can have either:
	# (1) stop-losses in nice sequential order but risk percentages and position sizes very slightly different at each add-on
	# (2) stop-loss sequence very slightly off but risk percentages and position sizes the same at each add-on
	if ($addOnOption==1) {
		#-----exact sequential stop-losses resulting in very slightly different risked percentages at each add on 
		for(my $i = 1; $i < $totalNumberOfTradesOriginalAndAddons; $i++){
			($isTradeALong==1) ? push(@entriesArr, $entriesArr[0]+($i*$theStepSize))  : push(@entriesArr, $entriesArr[0]-($i*$theStepSize));
			($isTradeALong==1) ? push(@guideBookSLs,$guideBookSLs[0]+($i*$theStepSize)) : push(@guideBookSLs,$guideBookSLs[0]-($i*$theStepSize));
			push(@stoplossArr, $sl1);
			push(@targetsArr, $targ1); 
		}
	}
	elsif ($addOnOption==2) {
		#-----very slightly non-sequential stop-losses resulting in the exact same amount being risked at each add-on
		for(my $i = 1; $i < $totalNumberOfTradesOriginalAndAddons; $i++){
			my $entryLong  = $entriesArr[0]+($i*$theStepSize);
			my $entryShort = $entriesArr[0]-($i*$theStepSize);
			($isTradeALong==1) ? push(@entriesArr, $entryLong) : push(@entriesArr, $entryShort);
			($isTradeALong==1) ? push(@guideBookSLs,$entryLong*(1-$wantedToRiskPercentage)) : push(@guideBookSLs,$entryShort*(1+$wantedToRiskPercentage));
			push(@stoplossArr, $sl1);
			push(@targetsArr, $targ1); 
		}
	}
	else { die "\nerror: option error in add-on generation"; }
	
	# tidy up entry, stop-loss and target values in their arrays
	for(my $i = 0; $i < scalar(@entriesArr); $i++){
		$entriesArr[$i]  = formatToVariableNumberOfDecimalPlaces($entriesArr[$i],$noDecimalPlacesForEntriesTargetsAndSLs);
		$stoplossArr[$i] = formatToVariableNumberOfDecimalPlaces($stoplossArr[$i],$noDecimalPlacesForEntriesTargetsAndSLs);
		$targetsArr[$i]  = formatToVariableNumberOfDecimalPlaces($targetsArr[$i],$noDecimalPlacesForEntriesTargetsAndSLs);
	}
	
	# create simple cornix free text templates for the original trade and add-ons 
	my @multipleTemplates;
	for(my $i = 0; $i < $totalNumberOfTradesOriginalAndAddons; $i++){
		# create simple Cornix free text templates for base trade and TT add-ons
		my @simpleTemplate = createCornixFreeTextSimpleTemplateTT($coinPair, $leverage, $entriesArr[$i], $targetsArr[$i],
											$stoplossArr[$i], $noDecimalPlacesForEntriesTargetsAndSLs, $i, $isTradeALong);
		
		# create advanced Cornix free text templates for base trade and TT add-ons
		my @advancedTemplate = createCornixFreeTextAdvancedTemplateTT_PercentBelowHighest($coinPair,$clientSelected,$leverage,$entriesArr[$i],
										$targetsArr[$i],$stoplossArr[$i],$noDecimalPlacesForEntriesTargetsAndSLs,$i,$isTradeALong,$stepSizeInR);
		my @currentTemplate;								
		push(@currentTemplate,@simpleTemplate);
		push(@currentTemplate,@advancedTemplate);
		
		# get the trade statistics
		my @stats = trade_stats($entriesArr[$i],$targetsArr[$i],$stoplossArr[$i],$wantedToRiskAmount);		
	
		# add trade stats to the end of the templates
		push(@currentTemplate,@stats);
		
		push(@multipleTemplates, @currentTemplate);
		$wantedToRiskAmount *= $addOnSoftenerMultiple;		# skyscraper, 321, etc
	}
	
	# all trades templates now have the same stop-losses and targets (just different entries).
	# creating a guidebook to show what the stop-losses should be manually set to as add-on entries are reached
	my @guideBook;
	push(@guideBook, "########################### guide book\n");
	for(my $i = 0; $i < $totalNumberOfTradesOriginalAndAddons; $i++){
		my $str;
		if ($i==0) { $str="base: "; }
		if ($i==1) { $str="add1: "; }
		if ($i==2) { $str="add2: "; }
		my $ent = formatToVariableNumberOfDecimalPlaces($entriesArr[$i],$noDecimalPlacesForEntriesTargetsAndSLs);
		my $targ = formatToVariableNumberOfDecimalPlaces($targetsArr[$i],$noDecimalPlacesForEntriesTargetsAndSLs);
		my $stop = formatToVariableNumberOfDecimalPlaces($guideBookSLs[$i],$noDecimalPlacesForEntriesTargetsAndSLs);
		push(@guideBook,"$str entry:$entriesArr[$i] target:$targetsArr[$i] stop:$guideBookSLs[$i]\n");
	}
	push(@multipleTemplates,@guideBook);
	
	return @multipleTemplates; 
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
												$configHash{addOnSoftenerMultiple},
												$configHash{stepSizeInR},
											);
																	
my @multipleCornixTemplatesSimple = tt_begin($configHash{entryValue},$configHash{targetValue},$configHash{stopLoss},$configHash{noOfAddOns},
												$configHash{wantedToRiskAmount}, $isTradeALong,$configHash{coinPair}, $configHash{leverage},
												$configHash{noDecimalPlacesForEntriesTargetsAndSLs},$configHash{addOnSoftenerMultiple},
												$configHash{stepSizeInR},$configHash{client});

# print templates to screen
say @multipleCornixTemplatesSimple;

# print template to file
my $scriptName = basename($0);
my $fileName = createOutputFileName($scriptName, $configHash{coinPair}, $isTradeALong);
my $fh;
open ($fh, '>', $fileName) or die ("Could not open file '$fileName' $!");
say $fh @multipleCornixTemplatesSimple;
