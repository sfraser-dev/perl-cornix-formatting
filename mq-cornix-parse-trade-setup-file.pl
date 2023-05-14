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
	my $longOrShortStr;
	$scriptName=~s/\.pl//;
	#$date = strftime "%Y%m%d-%H%M%S", localtime;
	#$date = strftime "%Y%m%d", localtime;
	my $date1 = strftime "%Y%m%d---%H%M", localtime; 
	my $date2 = strftime "%S", localtime;			
	my $date = $date1."_".$date2;		# YYYYMMDD---HM_SS
	my $dateWee = substr($date, 2); 	# YYMMDD---HHMM_SS (use date format 220325 not 20220325)
	my $pairNoSlash = $pair;
	$pairNoSlash =~ s/\///g;
	if ($isTradeALong == 1) {
		$longOrShortStr="long";
	} elsif ($isTradeALong == 0) {
		$longOrShortStr="short";
	} else {
		die "error: trade is neither a long nor a short";
	}
	my $txtFile = "$dateWee---$pairNoSlash-$longOrShortStr\.trade";
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
		# long entries (putting in "correct" order, long entries start high and get lower)
		if ($isTradeALong == 1) {
			for(my $i=0; $i<$noOfEntriesOrTargetsWanted; $i++){
				push (@entryOrTargetValsArr, $high-($entryIncrement*$i));
			}
		}
		# short entries (putting in "correct" order, short entries start low and get higher)
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
		# long targets (putting in "correct" order, long targets start low and get higher)
		if ($isTradeALong == 1) {
			for(my $i=0; $i<$noOfEntriesOrTargetsWanted; $i++){
				push (@entryOrTargetValsArr, $low+($entryIncrement*$i));
			}
		}
		# short targets (putting in "correct" order, short targets start high and get lower)
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
	# assumes advanced template entries are in the correct order (whether long or shorting), "EvenDistribution" sub does this
	my @strArrEnts=@{$_[0]}; 					# dereference the passed array
	my $stopLoss=$_[1];
	
	my $numEntriesHit = scalar(@strArrEnts);
	my $firstEntryPrice;
	my $avgEntryPrice;
	my $percentageOfPosSizeBoughtSoFar;
	my $dummyVar;
	($firstEntryPrice,$avgEntryPrice,$percentageOfPosSizeBoughtSoFar,$dummyVar) = calcAverageEntryPriceForVariableEntriesHit(\@strArrEnts,$numEntriesHit);
	
	# calculate risk percentatge based on just the first entry (entry1), risk percentage based on average entry and a
	# risk-softening-multiplier (the risk-softening-multiplier is just for entry1 calculation)
	#
	# What is risk-softening-multiplier? I would use TradingView's RR tool to get the SL distance from the FIRST entry;
	# I would then use this risk percentage to calculate my total position size. When I started layering multiple bids below
	# the FirstEntry, I kept using ONLY the first entry to calcualte my risk - my risk WASN'T this much as I would have an average
	# bid entry below this due to layering my bids. The risk-softening-multiplier accounts for this. If I wanted to risk $100 on 
	# a trade and used only the first entry to calculate this risk (but actually had layered bids), my risk-softening-multiplier
	# might be something like 0.75, thus my actual risk would only be $100*0.75 = $75. I never used to layer bids so this was a simple
	# way for me implement it initially - easy for me to update my journal properly and quickly if I calcualed my risk using only
	# the first entry but actually had layered bids.
	my $riskPercentageBasedOnEntry1 = (abs($firstEntryPrice-$stopLoss))/$firstEntryPrice;
	my $riskPercentageBasedOnAvgEntry = (abs($avgEntryPrice-$stopLoss))/$avgEntryPrice;
	my $riskSoftMult = $riskPercentageBasedOnAvgEntry / $riskPercentageBasedOnEntry1;

	return ($riskSoftMult, $riskPercentageBasedOnEntry1,$riskPercentageBasedOnAvgEntry);	
}

############################################################################
############################################################################
sub HeavyWeightingAtEntryOrStoploss {
	my $entriesOrTargetsStr=$_[0];
	my $noOfEntries=$_[1];
	my $high=$_[2];
	my $low=$_[3];
	my $isTradeALong=$_[4];
	my $weightingFactor=$_[5];
	my $noDecimalPlacesForEntriesTargetsAndSLs=$_[6];
	my @strArr;
	
	# run EvenDistribution calculation first
	@strArr = EvenDistribution($entriesOrTargetsStr,$noOfEntries,$high,$low,$isTradeALong,$noDecimalPlacesForEntriesTargetsAndSLs);
	
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
	
	# entries: positive values are the more "disciplined" weightings
	# entries: positive weightingFactor values weight towards the stop-loss
	# entries: negative weightingFactor values weight towards the entry
	# targets: positive values is the more "disciplined" weightings
	# targets: positive weightingFactor values weight towards the furthest away target
	# targets: negative weightingFactor values weight towards the closest target
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
		if ($per <= 0) { die "error: percentage weighting is zero or less"; }
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
	my $wantedToRiskAmount = $_[11];
	my $isTradeALong = $_[12];
	my $weightingFactorEntries = $_[13];
	my $weightingFactorTargets = $_[14];
	my $dynamicEntryValue = $_[15];
	my @template;
	my $strRead;
	my $riskSoftMult;
	my $riskPercentageBasedOnEntry1;
	my $riskPercentageBasedOnAvgEntry;
		
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
	my @strArrEntries = HeavyWeightingAtEntryOrStoploss("entries",$noOfEntries,$highEntry,$lowEntry,$isTradeALong,$weightingFactorEntries,$noDecimalPlacesForEntriesTargetsAndSLs);
	foreach $strRead (@strArrEntries) {
		push(@template,$strRead);
	}
	
	# take profit targets
	push (@template,"\n");
	push (@template,"Take-Profit Targets:\n");
	my @strArrTargets = HeavyWeightingAtEntryOrStoploss("targets",$noOfTargets,$highTarget,$lowTarget,$isTradeALong,$weightingFactorTargets,$noDecimalPlacesForEntriesTargetsAndSLs);
	foreach $strRead (@strArrTargets) {
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
	#my $trailingLine04 = "Stop: Breakeven -\n Trigger: Target (1)";
	my $trailingLine04 = "Stop: Without";
	push (@template,"$trailingLine01\n$trailingLine02\n$trailingLine03\n$trailingLine04\n\n");
	
	# risk softening multiplier (just for risk based on only entry1) and risk percentages (risked amount is based on entry and stop-loss)
	($riskSoftMult,$riskPercentageBasedOnEntry1,$riskPercentageBasedOnAvgEntry) = riskSofteningMultiplier(\@strArrEntries, $stopLoss); # passing array as reference
	
	# position sizes required for the wanted risk (calc for both enrty1 and average-entry)
	my $positionSizeEntry1 = $wantedToRiskAmount/$riskPercentageBasedOnEntry1;
	my $positionSizeAverageEntry = $wantedToRiskAmount/$riskPercentageBasedOnAvgEntry;
	
	my @dollarsRiskedAtEachEntry_ent1 = calcRiskAddedAtEachEntry (\@strArrEntries,$noOfEntries,$stopLoss,$positionSizeEntry1,$wantedToRiskAmount*$riskSoftMult);
	my @dollarsRiskedAtEachEntry_avgEnt = calcRiskAddedAtEachEntry (\@strArrEntries,$noOfEntries,$stopLoss,$positionSizeAverageEntry,$wantedToRiskAmount);
	
	# fixed risk dynamic position size calculation
	my @temp_arraysConcatenatedReturnedFromSub;
	my @frdps_dataEnt1;
	my @frdps_dataAvgEnt;
	if ($dynamicEntryValue != 0) {  
		@temp_arraysConcatenatedReturnedFromSub = fixedRiskDynamicPositionSize(\@strArrEntries,$stopLoss, # passing array as references
														$positionSizeEntry1,$positionSizeAverageEntry,$wantedToRiskAmount,
														$dynamicEntryValue,$isTradeALong); 
		for my $i (0 .. ($noOfEntries-1)) {
			$frdps_dataEnt1[$i]=$temp_arraysConcatenatedReturnedFromSub[$i];
			$frdps_dataAvgEnt[$i]=$temp_arraysConcatenatedReturnedFromSub[$noOfEntries+$i];
		}
	}		
	
	# # show position size needed for required risk percentage (based only on entry1)
	###### commenting out risk-softening-multiplier output information, never using it just now
	# my $tempEnt1 = "########################### risk based only on entry 1\n";
	# my $tempEnt2 = sprintf("riskPercentageBasedOnEntry1 = %.4f\n",$riskPercentageBasedOnEntry1);
	# my $tempEnt3 = sprintf("riskSoftMult = %.4f\n",$riskSoftMult);
	# my $reducedRisk = $wantedToRiskAmount*$riskSoftMult;
	# my $tempEnt4 = "position size of \$".sprintf("%.2f",$positionSizeEntry1)." is needed to risk \$".sprintf("%.2f",$reducedRisk);
	# my $tempEnt5 = sprintf("; softened risk is \$%0.2f (\$%0.2f * %0.4f)\n",$reducedRisk,$wantedToRiskAmount,$riskSoftMult);
	# push (@template,$tempEnt1);
	# push (@template,$tempEnt2);
	# push (@template,$tempEnt3);
	# push (@template,$tempEnt4);
	# push (@template,$tempEnt5);	
	# # risk added at each entry (based only on entry1)
	# for my $i (0 .. ($noOfEntries-1)) {
		# my $str = sprintf("%s\n",$dollarsRiskedAtEachEntry_ent1[$i]);
		# push(@template,$str);
	# }
	# my $softenedRisk = $wantedToRiskAmount*$riskSoftMult;
	# my $tempEnt6 = sprintf("riskSoftMult: \$%.2f * %.4f = \$%.2f\n\n",$wantedToRiskAmount,$riskSoftMult,$softenedRisk);
	# push (@template,$tempEnt6);

	# show position size needed for required risk percentage (based average entry)
	my $tempAvg1 = "########################### risk based on average entry\n";
	my $tempAvg2 = sprintf("riskPercentageBasedOnAvgEntry = %.4f\n",$riskPercentageBasedOnAvgEntry);
	my $tempAvg3 = "position size of \$".sprintf("%.2f",$positionSizeAverageEntry)." is needed to risk \$".sprintf("%.2f",$wantedToRiskAmount)."\n";
	push (@template,$tempAvg1);
	push (@template,$tempAvg2);
	push (@template,$tempAvg3);
	# risk added at each entry (based only on avgEntry)
	for my $i (0 .. ($noOfEntries-1)) {
		my $str = sprintf("%s\n",$dollarsRiskedAtEachEntry_avgEnt[$i]);
		push(@template,$str);
	}
	
	# Optional: show fixed risk dynamic position sizes 
	if ($dynamicEntryValue != 0) {
		# entry1
		push(@template,"\n########################### fixed risk dynamic position size\n");
		push (@template,"### only on entry 1\n");
		for my $i (0 .. ($noOfEntries-1)) {
			push (@template,$frdps_dataEnt1[$i]);
		}
		average entry
		push (@template,"### average entry\n");
		for my $i (0 .. ($noOfEntries-1)) {
			push (@template,$frdps_dataAvgEnt[$i]);
		}
	}
	
	return @template;
}

############################################################################
############################################################################
sub calcAverageEntryPriceForVariableEntriesHit {
	my @strArrEnts=@{$_[0]}; 						# dereference the passed array
	my $numOfEntriesToUseForCalculation=$_[1];
	
	# Assigns arbitary position value for ease of claculation. Based on this arbitary position value, calc number of coins
	# bought at each entry point (using entry price & assigned percentage of position size). Keep a running total of amount of
	# coins bought and a running total paid for these coins (total paid will be the full arbitary value *IF* all entry targets hit).
	# If not all entry targets hit, it will be a different total amount paid.
	# Note: the amount used for the arbitary position value doesn't matter, it'll give the same result
	my $arbitraryPositionValue = 100000;
	my $totalNumberCoinsBought = 0;
	my $totalAmountPaidForCoins = 0;
	my $firstEntryPrice;
	my $totalPercentageOfPositionSizeBought = 0;
	
	my $entryPriceFinal_i;
	for my $i (0 .. ($numOfEntriesToUseForCalculation-1)) {
		# get the values and percentages from the Cornix Entry Tragets: string array 
		my @splitter=split / /, $strArrEnts[$i];	# split line using spaces, [0]=1), [1]=value, [2]=hyphen, [3]=percentage
		my $entryPrice = $splitter[1];
		if ($i == 0) { $firstEntryPrice = $entryPrice; }
		my $percentage = ($splitter[3]);
		$percentage =~ s/%//g;						# remove percentage sign
		$percentage /= 100;							# percenatge as decimal
		$totalPercentageOfPositionSizeBought += $percentage;
		
		# calculate "number of coins obtained" at this entry and percentage (using arbitary position size same as spreadsheet)
		my $amountSpentAtThisEntryPoint =  $arbitraryPositionValue * $percentage;
		my $numberCoinsBoughtAtThisEntryPoint = $amountSpentAtThisEntryPoint / $entryPrice;
		$totalAmountPaidForCoins += $amountSpentAtThisEntryPoint;
		$totalNumberCoinsBought += $numberCoinsBoughtAtThisEntryPoint;
		
		$entryPriceFinal_i = $entryPrice;
	}
	my $averageEntryPrice = $totalAmountPaidForCoins / $totalNumberCoinsBought;
		
	return ($firstEntryPrice, $averageEntryPrice, $totalPercentageOfPositionSizeBought, $entryPriceFinal_i);
}

############################################################################
############################################################################
sub calcRiskAddedAtEachEntry {
	my @strArrEnts=@{$_[0]}; 						# dereference the passed array
	my $noOfEntries=$_[1];
	my $stopLoss=$_[2];
	my $fullPositionSize=$_[3];
	my $wantedToRiskAmount=$_[4];
	
	my $totalRiskSoFar=0;
	my @retArr;
	
	for my $i (0 .. ($noOfEntries-1)) {
		# get the values and percentages from the Cornix Entry Tragets: string array 
		my @splitter=split / /, $strArrEnts[$i];	# split line using spaces, [0]=1), [1]=value, [2]=hyphen, [3]=percentage
		my $entryPrice = $splitter[1];
		my $percentage = ($splitter[3]);
		$percentage =~ s/%//g;						# remove percentage sign
		$percentage /= 100;							# percenatge as decimal
		
		my $entryNo=$i+1;
		my $thisEntryPositionSize=$fullPositionSize*$percentage;
		my $thisRiskedPercentage = (abs($entryPrice-$stopLoss))/$entryPrice;
		my $thisRiskedAmount = $thisEntryPositionSize*$thisRiskedPercentage;
		
		$totalRiskSoFar += $thisRiskedAmount;
		my $amountStillLeftToRisk = $wantedToRiskAmount - $totalRiskSoFar;
		my $str1=sprintf("entry %d: riskAmountAddedHere=\$%.2f, totRiskNow=\$%.2f (\$%0.2f-\$%0.2f=\$%0.2f still to risk)",
										$entryNo,$thisRiskedAmount,$totalRiskSoFar, $wantedToRiskAmount, $totalRiskSoFar, $amountStillLeftToRisk);
		push(@retArr,$str1);
	}
	return @retArr;
}

############################################################################
############################################################################
sub fixedRiskDynamicPositionSize {
	my @strArrEnts=@{$_[0]}; 						# dereference the passed array
	my $stopLoss=$_[1];
	my $fullPositionSize_entry1=$_[2];
	my $fullPositionSize_avgEnt=$_[3];
	my $wantedToRiskAmount=$_[4];
	my $dynamicEntryValue=$_[5];
	my $isTradeALong=$_[6];
	
	# check that the new dynamic entry value occurs only while trade is currently in profit
	my $firstEntryPrice;
	my $avgEntryPrice;
	my $percentageOfPosSizeBoughtSoFar;
	my $dummyVar;
	# run calcAverageEntryPriceForVariableEntriesHit() once to get the first entry price so checks can be run
	($firstEntryPrice,$avgEntryPrice,$percentageOfPosSizeBoughtSoFar,$dummyVar) = calcAverageEntryPriceForVariableEntriesHit(\@strArrEnts,1);
	if ( ( $isTradeALong==1) && ($dynamicEntryValue <= $firstEntryPrice) ) { 	# long
		die "fixed risk dynamic position size error for long trade!\n";
	}
	if ( ($isTradeALong!=1) && ($dynamicEntryValue >= $firstEntryPrice) ){		# short
		die "fixed risk dynamic position size error for short trade!\n";
	}
		
	my @dataEnt1;
	my @dataAvgEnt;
	my $numEntriesToProcess = scalar(@strArrEnts);
	my $percentageBoughtSoFar_previous_ent1 = 0;
	my $theCurrentEntryPrice;
	my $riskedAmountSoFar_ent1 = 0;
	# get stats for all possible entry targets hit so fixed risk dynamic position size can be calculated
	for my $i (1 .. $numEntriesToProcess) {
		($firstEntryPrice,$avgEntryPrice,$percentageOfPosSizeBoughtSoFar,$theCurrentEntryPrice) = 
															calcAverageEntryPriceForVariableEntriesHit(\@strArrEnts,$i);
		# calculate current risk percentage based on hit entries and stop-loss
		my $riskPercentageBasedOnEntry1 = (abs($firstEntryPrice-$stopLoss))/$firstEntryPrice;
		my $riskPercentageBasedOnAvgEntry = (abs($avgEntryPrice-$stopLoss))/$avgEntryPrice;
		# calculate new risk percentage based on adding to position at the current price (not moving stop-loss)
		my $riskPercentage_new_frdps = (abs($dynamicEntryValue-$stopLoss))/$dynamicEntryValue;	
		
		# entry1-only: calculate the new position size required for fixed risk dynamic position sizing	
		# entry1-only: need the percentage of total postion size bought here (to calculate the position size at the current entry)
		my $percentageBoughtHere_ent1 = $percentageOfPosSizeBoughtSoFar - $percentageBoughtSoFar_previous_ent1;
		$percentageBoughtSoFar_previous_ent1 += $percentageBoughtHere_ent1;
		# entry1-only: calculate cumulative amount risked so far
		my $positionSizeHere_ent1 = $fullPositionSize_entry1 * $percentageBoughtHere_ent1;
		my $percentageRiskedHere_ent1 = (abs($theCurrentEntryPrice-$stopLoss))/$theCurrentEntryPrice;
		my $riskedAmountHere_ent1 = $positionSizeHere_ent1 * $percentageRiskedHere_ent1;
		$riskedAmountSoFar_ent1 += $riskedAmountHere_ent1;	
		# can now finally calculate the new position size required for fixed risk dynamic position sizing
		my $newAmountToRisk_ent1 = $wantedToRiskAmount - $riskedAmountSoFar_ent1;
		my $newPositionSize_ent1 = $newAmountToRisk_ent1 / $riskPercentage_new_frdps;
		# entry1-only: output the data
		my $currentTotalRisk_ent1 = $riskedAmountSoFar_ent1 + $newAmountToRisk_ent1;
		my $e1=sprintf("%dentriesHit: totRiskNow=\$%.2f, newPosSize \$%.0f ",$i,$riskedAmountSoFar_ent1,$newPositionSize_ent1);
		my $e2=sprintf("at price \$%.4f adds \$%.2f of risk (totRisk now \$%.0f, ",$dynamicEntryValue,$newAmountToRisk_ent1,$currentTotalRisk_ent1);
		my $e3=sprintf("SL=\$%.4f)\n",$stopLoss);
		my $e4=$e1.$e2.$e3;
		push(@dataEnt1,$e4);
		
		# average-entry: calculate the new position size required for fixed risk dynamic position sizing
		my $riskedAmountSoFar_avgEnt = $fullPositionSize_avgEnt * $percentageOfPosSizeBoughtSoFar * $riskPercentageBasedOnAvgEntry;
		my $newAmountToRisk_avgEnt = $wantedToRiskAmount - $riskedAmountSoFar_avgEnt;
		my $newPositionSize_avgEnt = $newAmountToRisk_avgEnt / $riskPercentage_new_frdps;
		# average-entry: output the data
		my $currentTotalRisk_avgEnt = $riskedAmountSoFar_avgEnt + $newAmountToRisk_avgEnt;
		my $a1=sprintf("%dentriesHit: totRiskNow=\$%.2f, newPosSize \$%.0f ",$i,$riskedAmountSoFar_avgEnt,$newPositionSize_avgEnt);
		my $a2=sprintf("at price \$%.4f adds \$%.2f of risk (totRisk now \$%.0f, ",$dynamicEntryValue,$newAmountToRisk_avgEnt,$currentTotalRisk_avgEnt);
		my $a3=sprintf("SL=\$%.4f)\n",$stopLoss);
		my $a4=$a1.$a2.$a3;
		push(@dataAvgEnt,$a4);
	}
	
	return @dataEnt1, @dataAvgEnt;
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
					'noDecimalPlacesForEntriesTargetsAndSLs' => 0,
					'wantedToRiskAmount' => 999999
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
	my $noOfEntries=$_[8];
	my $noOfTargets=$_[9];
	my $isTradeALong=$_[10];
	my @simpleTemplate; 

	push (@simpleTemplate, "########################### simple template\n");
	push(@simpleTemplate,"$pair\n");
	#if ($leverage >= 1) { push (@simpleTemplate, sprintf("leverage isolated %sx\n",$leverage)); }
	if ($leverage >= 1) { push (@simpleTemplate, sprintf("leverage cross %sx\n",$leverage)); }

	# note: Need to set up each Cornix client (bot configuration - trading) with desired entry and target distributions
	# note: Need to do this for each individual client, there is no global setting for this
	my $sl = formatToVariableNumberOfDecimalPlaces($stopLoss,$noDecimalPlacesForEntriesTargetsAndSLs);
	
	# Set weighting factors set to 0 (Cornix Free Text simple mode cannot set percentage weighting factors at all)
	# Cornix Free Text simple mode can only setsentry, target and stop-loss VALUES, it cannot set weighting factor percentages
	# Only in Cornix Free Text advanced mode (when choose to edit trade) can we set weighting factor percentages 
	my $weightingFactorEntries=0;
	my $weightingFactorTargets=0;
	my @strArrEntries = HeavyWeightingAtEntryOrStoploss("entries",$noOfEntries,$highEntry,$lowEntry,$isTradeALong,$weightingFactorEntries,$noDecimalPlacesForEntriesTargetsAndSLs);
	my @strArrTargets = HeavyWeightingAtEntryOrStoploss("targets",$noOfTargets,$highTarget,$lowTarget,$isTradeALong,$weightingFactorTargets,$noDecimalPlacesForEntriesTargetsAndSLs);
	
	my @entryVals;
	my @targetVals;
	# get all the entry values
	for my $i (0 .. $#strArrEntries) {
		my @splitter=split / /, $strArrEntries[$i];	# split line using spaces, [0]=1), [1]=value, [2]=hyphen, [3]=percentage
		my $val = ($splitter[1]);
		push(@entryVals, formatToVariableNumberOfDecimalPlaces($val,$noDecimalPlacesForEntriesTargetsAndSLs));
	}
	# get all the target values
	for my $i (0 .. $#strArrTargets) {
		my @splitter=split / /, $strArrTargets[$i];	# split line using spaces, [0]=1), [1]=value, [2]=hyphen, [3]=percentage
		my $val = ($splitter[1]);
		push(@targetVals, $val);
	}

	# push all the entry values onto the simpleTemplate
	push(@simpleTemplate, "enter ");
	for my $i (0 .. $#entryVals) {
		push(@simpleTemplate,"$entryVals[$i] ");
	}
	# push all the target values onto the simpleTemplate
	push(@simpleTemplate, "\nstop $sl\n");
	push(@simpleTemplate, "targets ");
	for my $i (0 .. $#targetVals) {
		push(@simpleTemplate, "$targetVals[$i] ");
	}
	
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
	my $wantedToRiskAmount = $_[9];

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
	
	# the risked amount
	if ($wantedToRiskAmount <= 0) { die "\nerror: wantedToRiskAmount is <= 0\n"; }
	
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
			'not=s',	# optional: number of targets (override config file number of targets)
			'dev=s'		# optional: dynamic entry value for dynamic risk fixed position size
          ) or die "Invalid command line arguments!";
my $pathToFile = $args{file};
my $weightingFactorEntries = $args{ewf};		# not in the trade config file
my $weightingFactorTargets = $args{twf};		# not in the trade config file
my $numberOfEntriesCommandLine = $args{aoe};	# in the config file, but override config file value if command line value given
my $numberOfTargetsCommandLine = $args{not};	# in the config file, but override config file value if command line value given
my $dynamicEntryValue = $args{dev};				# not in the trade config file (only an optional command line argument)


unless ($args{file}) 	{ die "Missing --file!\n"; }			# --file (-f) FileName 
unless ($args{ewf}) 	{ $weightingFactorEntries=0; }			# --ewf  (-e) entries weighting factor (for spreading percentages)
unless ($args{twf}) 	{ $weightingFactorTargets=0; }			# --twf  (-t) targets weighting factor (for spreading percentages)
unless ($args{aoe}) 	{ $numberOfEntriesCommandLine=0; }		# --aoe  (-a) amount of entries 
unless ($args{not}) 	{ $numberOfTargetsCommandLine=0; }		# --not  (-n) number of targets 
unless ($args{dev}) 	{ $dynamicEntryValue=0; }				# --dev  (-d) dynamic entry value  

# read trade file
my %configHash = readTradeConfigFile($pathToFile);

# if number of entries/targets is given on the command line, override the number of entries/targets given in the config file
if ($numberOfEntriesCommandLine != 0) { $configHash{numberOfEntries} = $numberOfEntriesCommandLine; }
if ($numberOfTargetsCommandLine != 0) { $configHash{numberOfTargets} = $numberOfTargetsCommandLine; }

# check entries and targets make logical sense & determine if trade is a long or a short
my $isTradeALong = checkValuesFromConfigFile(	$configHash{numberOfEntries},
												$configHash{numberOfTargets},
												$configHash{highEntry},
												$configHash{lowEntry},
												$configHash{highTarget},
												$configHash{lowTarget},
												$configHash{stopLoss},
												$configHash{leverage},
												$configHash{noDecimalPlacesForEntriesTargetsAndSLs},
												$configHash{wantedToRiskAmount}
											);
											
# old and simple way of using Cornix Free Text, generate a version of this too as well as the advanced template
my @cornixTemplateSimple = createCornixFreeTextSimpleTemplate($configHash{coinPair},
																	$configHash{leverage},
																	$configHash{highEntry},
																	$configHash{lowEntry},
																	$configHash{highTarget},
																	$configHash{lowTarget},
																	$configHash{stopLoss},
																	$configHash{noDecimalPlacesForEntriesTargetsAndSLs},
																	$configHash{numberOfEntries},
																	$configHash{numberOfTargets},
																	$isTradeALong);

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
													$configHash{wantedToRiskAmount},
													$isTradeALong,
													$weightingFactorEntries,
													$weightingFactorTargets,
													$dynamicEntryValue);
													
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
close $fh;
	