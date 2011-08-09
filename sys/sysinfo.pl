#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  sysinfo.pl
#
#        USAGE:  ./sysinfo.pl  
#
#  DESCRIPTION:  Sys::Statistics::Linux
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  anderslee (Anders Lee), anderslee@yeah.net
#      COMPANY:  just for fun
#      VERSION:  1.0
#      CREATED:  08/07/2011 06:02:33 PM
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use diagnostics;
use Modern::Perl;

use POSIX qw(strftime);

use Storable qw(nstore retrieve);

use constant PATH => "/data/";


#=======================================================================

while (1) {
        do_the_job();
}

sub do_the_job {
        my $today = strftime ("%Y%m%d", localtime(time));
        my $now = strftime ("%H%M", localtime(time));

        my $path = ensure_environment($today, $now);

        lxs($path.".db");

        sleep 300;
}

sub ensure_environment {
        my ($today, $now) = @_;

        my $year = substr $today, 0, 4;
        my $month = substr $today, 4, 2;
        my $day = substr $today, 6, 2;

        my $hour = substr $now, 0, 2;
        my $minute = substr $now, 2, 2;

        my $path =
                PATH."/$year/$month/$day/$hour/$minute";

        mkdir PATH."/$year"
                unless (-e PATH."/$year");

        mkdir PATH."/$year/$month"
                unless (-e PATH."/$year/$month");

        mkdir PATH."/$year/$month/$day"
                unless (-e PATH."/$year/$month/$day");

        mkdir PATH."/$year/$month/$day/$hour"
                unless (-e PATH."/$year/$month/$day/$hour");

        return $path;
}


sub lxs {
	my ($path) = @_;

	my %dd;
	
	#use Data::Dumper qw(Dumper);
	
	use Sys::Statistics::Linux;
	
	my $lxs = Sys::Statistics::Linux->new(
	        sysinfo => 1,
	        cpustats => 1,
	        netstats => 1,
	        memstats => 1,
	        sockstats => 1,
	        diskstats => 1,
	        diskusage => 1,
	        pgswstats => 1,
	        #processes => 1,   # cat $PID
	        procstats => 1,
	        loadavg => 1,
	        filestats => 1,
	);
	
	
	my $stat = $lxs->get;
	
	my $info = $stat->{sysinfo};
	
	for my $item (qw{memtotal uptime hostname swaptotal interfaces}) {
	        $dd{cpuinfo}{$item} = $info->{$item};
	                #if defined $info->{$item};
	}
	
	my $cpustats = $stat->{cpustats};
	
	for my $cpu (keys %$cpustats) {
	        for my $item (qw{idle total user}) {
	                $dd{cpustats}{$cpu}{$item} = $cpustats->{$cpu}->{$item};
	                        #if defined $cpustats->{$cpu}->{$item};
	        }
	}
	
	my $memstats = $stat->{memstats};
	
	for my $item (qw{memusedper memtotal swaptoal swapusedper}){
	        $dd{memstats}{$item} = $memstats->{$item};
	                #if defined $memstats->{$item};
	}
	
	my $netstats = $stat->{netstats};
	
	for my $if(keys %$netstats) {
	        #next unless $if =~ m/lo/;
	        for my $item (qw{ttpcks ttbyt rxbyt rxpcks rxerrs rxdrop txpcks txbyt txerrs txdrop}) {
	                $dd{netstats}{$if}{$item} = $netstats->{$if}->{$item}
	                        if defined $netstats->{$if}->{$item};
	        }
	}
	
	my $netinfo = $stat->{netinfo};
	
	for my $if (keys %$netinfo) {
	        #next if $if =~ m/lo/;
	        for my $item (qw{ttpcks ttbyt rxbyt rxpcks rxerrs rxdrop txpcks txbyt txerrs txdrop}) {
	                $dd{netinfo}{$if}{$item} = $netinfo->{$if}->{$item}
	                        if defined $netinfo->{$if}->{$item};
	        }
	}
	
	my $sockstats = $stat->{sockstats};
	
	for my $item (keys %$sockstats) {
	        $dd{sockstats}{$item} = $sockstats->{$item};
	                #if defined $sockstats->{$item};
	}
	
	my $diskusage = $stat->{diskusage};
	
	for my $part (keys %$diskusage) {
	        next unless $part =~ m/sd/;
	        for my $item (qw{mountpoint total usageper}) {
	                $dd{diskusage}{$part}{$item} = $diskusage->{$part}->{$item};
	                        #if defined $diskusage->{$part}->{$item};
	        }
	}
	
	my $diskstats = $stat->{diskstats};
	
	for my $part (keys %$diskstats) {
	        next unless $part =~ m/sd/;
	        for my $item (qw{rdbyt wrtbyt}) {
	                $dd{diskstats}{$part}{$item} = $diskstats->{$part}->{$item};
	                        #if defined $diskstats->{$part}->{$item};
	        }
	}
	
	my $pgswstats = $stat->{pgswstats};
	
	for my $item (qw{pgfault pgmajfault pswpin pswpout pspgin pspgout}) {
	        $dd{pgswstats}{$item} = $pgswstats->{$item};
	}
	
	my $procstats = $stat->{procstats};
	
	for my $item (keys %$procstats) {
	        $dd{procstats}{$item} = $procstats->{$item};
	}
	
	my $filestats = $stat->{filestats};
	
	for my $item (keys %$filestats) {
	        $dd{filestats}{$item} = $filestats->{$item};
	}
	
	my $loadavg = $stat->{loadavg};
	
	for my $item (keys %$loadavg) {
	        $dd{loadavg}{$item} = $loadavg->{$item};
	}
	
	nstore \%dd, $path;
}
