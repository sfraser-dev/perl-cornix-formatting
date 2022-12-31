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
	}
	close $info;
	return %dataHash;
}

############################################################################
############################################################################
sub createCornixFreeTextSimpleTemplate {
	my $pair=$_[0];
	my $leverage=$_[1];
	my $entryValue=$_[2];
	my $targetValue=$_[3];
	my $stopLoss=$_[4];
	my $noDecimalPlacesForEntriesTargetsAndSLs=$_[5];
	my @simpleTemplate; 

	push (@simpleTemplate, "########################### simple template\n");
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
	
	say"entryValue=$entryValue";
	say"targetValue=$targetValue";
	say"stopLoss=$stopLoss";
	say"leverage=$leverage";
	say"noDecimalPlacesForEntriesTargetsAndSLs=$noDecimalPlacesForEntriesTargetsAndSLs";
	say"wantedToRiskAmount=$wantedToRiskAmount";
	
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
	
	return $isTradeALong;
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
												$configHash{wantedToRiskAmount}
											);
											
# old and simple way of using Cornix Free Text, generate a version of this too as well as the advanced template
my @cornixTemplateSimple = createCornixFreeTextSimpleTemplate($configHash{coinPair},
																	$configHash{leverage},
																	$configHash{entryValue},
																	$configHash{targetValue},
																	$configHash{stopLoss},
																	$configHash{noDecimalPlacesForEntriesTargetsAndSLs});
																	
# print templates to screen
say @cornixTemplateSimple;

# print template to file
my $scriptName = basename($0);
my $fileName = createOutputFileName($scriptName, $configHash{coinPair}, $isTradeALong);
my $fh;
open ($fh, '>', $fileName) or die ("Could not open file '$fileName' $!");
say $fh @cornixTemplateSimple;
