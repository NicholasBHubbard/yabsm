#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  Testing for Yabsm.pm

use strict;
use warnings;
use 5.010;

use Test::More 'no_plan';

use FindBin '$Bin';
use lib "$Bin";
use Yabsm;

use experimental 'smartmatch';

use Time::Piece;

                 ####################################
                 #               TESTS              #
                 ####################################

test_all_snapshots();
sub test_all_snapshots {

    # In order to run this test you must have yabsm configured to be taking
    # snapshots of a subvolume 'root', and your snapshot root directory must 
    # be '/.snapshots'.
    
    my @yabsm_all_snapshots = Yabsm::all_snapshots('root', 'hourly');

    my @ls_all_snapshots = `ls /.snapshots/yabsm/root/hourly/`;

    is ( scalar @yabsm_all_snapshots,
	 scalar @ls_all_snapshots,
	 'all_snapshots()'
       );
}

test_all_subvols();
sub test_all_subvols {

    # This test only runs on my system.

    my $s = join '', Yabsm::all_subvols();

    ok ( $s =~ /^root$/, 'all_subvols()' );
}
 
test_snap_later();
sub test_snap_later {

    my $snap1 = '/some/path/day=2020_04_12,time=00:00';
    my $snap2 = 'day=2020_03_12,time=00:00';
    
    ok ( Yabsm::snap_later($snap1,$snap2), 'snap_later()' );
}

test_snap_earlier();
sub test_snap_earlier {

    my $snap1 = '/some/path/day=2020_03_12,time=00:00';
    my $snap2 = 'day=2021_03_12,time=00:00';
    
    ok ( Yabsm::snap_earlier($snap1,$snap2), 'snap_earlier()' );
}

test_snap_later_or_eq();
sub test_snap_later_or_eq {

    my $snap1 = 'day=2020_03_13,time=00:00';
    my $snap2 = 'day=2020_03_13,time=00:00';
    my $snap3 = 'day=2020_03_12,time=00:00';
    
    my $cond1 = Yabsm::snap_later_or_eq($snap1, $snap2);
    my $cond2 = Yabsm::snap_later_or_eq($snap2, $snap3);

    ok ( $cond1 && $cond2, 'snap_later_or_eq()' );
}

test_snap_earlier_or_eq();
sub test_snap_earlier_or_eq {

    my $snap1 = 'day=2020_03_12,time=00:00';
    my $snap2 = 'day=2020_03_12,time=00:00';
    my $snap3 = 'day=2020_03_13,time=00:00';
    
    my $cond1 = Yabsm::snap_earlier_or_eq($snap1, $snap2);
    my $cond2 = Yabsm::snap_earlier_or_eq($snap2, $snap3);

    ok ( $cond1 && $cond2, 'snap_earlier_or_eq()' );
}

test_snap_equal();
sub test_snap_equal {

    my $snap1 = '/some/path/day=2020_03_12,time=00:00';
    my $snap2 = 'day=2020_03_12,time=00:00';
    
    ok ( Yabsm::snap_equal($snap1, $snap2), 'snap_equal()' );
}

test_latest_snap();
sub test_latest_snap {

    my @snaps = ('day=2023_03_12,time=00:00',
		 'day=2024_03_12,time=00:00',
		 'day=2022_03_12,time=00:00',
		 'day=2020_03_12,time=00:00',
		 'day=2021_03_12,time=00:00'
		);

    my $earliest_snap = Yabsm::latest_snap(\@snaps);

    ok ( $earliest_snap eq 'day=2024_03_12,time=00:00', 'latest_snap()' );
}

test_earliest_snap();
sub test_earliest_snap {

    my @snaps = ('day=2024_03_12,time=00:00',
		 'day=2023_03_12,time=00:00',
		 'day=2022_03_12,time=00:00',
		 'day=2020_03_12,time=00:00',
		 'day=2021_03_12,time=00:00'
		);

    my $earliest_snap = Yabsm::earliest_snap(\@snaps);

    ok ( $earliest_snap eq 'day=2020_03_12,time=00:00', 'earliest_snap()' );
}

test_sort_snapshots();
sub test_sort_snapshots {

    my @unsorted = ('day=2024_03_12,time=00:00',
		    'day=2022_03_12,time=00:00',
		    'day=2021_03_12,time=00:00',
		    'day=2020_03_12,time=00:00',
		    'day=2023_03_12,time=00:00'
		   );

    my @solution = (
		    'day=2024_03_12,time=00:00',
		    'day=2023_03_12,time=00:00',
		    'day=2022_03_12,time=00:00',
		    'day=2021_03_12,time=00:00',
		    'day=2020_03_12,time=00:00'
		   );

    my @sorted = Yabsm::sort_snapshots(\@unsorted);

    ok ( @solution ~~ @sorted, 'sort_snapshots()' );
}

test_nums_to_snap();
sub test_nums_to_snap {

    my $t = Yabsm::nums_to_snap(2020, 3, 2, 23, 15);

    ok( $t eq 'day=2020_03_02,time=23:15', 'nums_to_snap()' );
}

test_snap_to_nums();
sub test_snap_to_nums {

    my $time = 'day=2020_03_02,time=23:15';

    my @nums = Yabsm::snap_to_nums($time);

    my @solution = ('2020','03','02','23','15');

    ok ( @solution ~~ @nums, 'snap_to_nums()' );
}

test_snap_to_time_obj();
sub test_snap_to_time_obj {
    
    my $time = 'day=2020_03_02,time=23:15';

    my $time_obj = Yabsm::snap_to_time_obj($time);

    my $yr = $time_obj->year;

    ok ( $yr eq '2020', 'snap_to_time_obj()' );
}

test_time_obj_to_snap();
sub test_time_obj_to_snap {

    my $time_obj =
      Time::Piece->strptime("2020/3/06/12/0",'%Y/%m/%d/%H/%M');

    my $time = Yabsm::time_obj_to_snap($time_obj);

    ok ( $time eq  'day=2020_03_06,time=12:00', 'time_obj_to_snap()' );
}

