#!/usr/bin/env perl

#  Author: Nicholas Hubbard
#  Email:  nhub73@keemail.me
#  WWW:    https://github.com/NicholasBHubbard/yabsm
#
#  This script is used for taking and deleting a single snapshot.
#  
#  Remember that snapshot names are: 'day=yyyy_mm_dd,time=hh_mm'
#
#  Exactly five command line arguments are required:
#  1: '--subvmmtpoint' = home would be /home, root would be /
#  2: '--subvname'     = the yabsm name of the subvolume to snapshot
#  3: '--snapdir'      = root snapshot directory, typically /.snapshots
#  4: '--timeframe'    = can be one of: (hourly, daily, midnight, monthly)
#  5: '--keeping'      = number of snapshots being kept in this timeframe
#
#  This script is not meant to be used by the end user.

die "Permission denied\n" if ($<);

use strict;
use warnings;
use 5.010;

use Getopt::Long;

                 ####################################
                 #     PROCESS INPUT PARAMETERS     #
                 ####################################

my $SUBVOL_MOUNTPOINT_ARG;
my $SNAPSHOT_ROOT_DIR_ARG;
my $YABSM_SUBVOL_NAME_ARG;
my $TIMEFRAME_ARG;
my $SNAPS_TO_KEEP_ARG;

GetOptions ('subvmntpoint=s'  => \$SUBVOL_MOUNTPOINT_ARG,
            'snapdir=s'       => \$SNAPSHOT_ROOT_DIR_ARG,
            'subvname=s'      => \$YABSM_SUBVOL_NAME_ARG,
            'timeframe=s'     => \$TIMEFRAME_ARG,
            'keeping=i'       => \$SNAPS_TO_KEEP_ARG);

# All the options must be defined.
foreach ($SUBVOL_MOUNTPOINT_ARG,
	 $SNAPSHOT_ROOT_DIR_ARG,
	 $YABSM_SUBVOL_NAME_ARG,
	 $TIMEFRAME_ARG,
	 $SNAPS_TO_KEEP_ARG) {
    die '[!] missing one of: { --mntpoint, --snapdir, '
                            . '--subvname, --timeframe, '
	                    . '--keeping }'
			    if ! defined;
}

# $TARGET_DIRECTORY could look like '/.snapshots/home/midnight'
my $TARGET_DIRECTORY =
  "${SNAPSHOT_ROOT_DIR_ARG}/${YABSM_SUBVOL_NAME_ARG}/$TIMEFRAME_ARG";

                 ####################################
                 #               MAIN               #
                 ####################################

take_new_snapshot();
delete_appropriate_snapshots(); 

                 ####################################
                 #          SNAPSHOT CREATION       #
                 ####################################

sub take_new_snapshot {

    # take a single read-only snapshot

    my $snapshot_name = create_snapshot_name();

    system( 'btrfs subvolume snapshot -r ' 
	    . $SUBVOL_MOUNTPOINT_ARG # the path to take a snapshot of
	    . " $TARGET_DIRECTORY/$snapshot_name"); 
    return;
}

sub create_snapshot_name { 
    
    my ($min, $hr, $day, $mon, $yr) =
      map { sprintf '%02d', $_ } (localtime)[1..5]; # sprintf to always pad 0-9
    
    $mon++;      # month count starts at zero. 
    $yr += 1900; # year represents years since 1900. 
    
    return "day=${yr}_${mon}_${day},time=${hr}:$min";
}

                 ####################################
                 #         SNAPSHOT DELETION        #
                 ####################################

# An array of strings 'yyyy_mm_dd'
my @EXISTING_SNAPS =
  grep { $_ = $1 if /([^\/]+$)/ } glob "$TARGET_DIRECTORY/*";

sub delete_appropriate_snapshots {
    
    my $num_snaps = scalar @EXISTING_SNAPS;

    # We expect there to be 1 more snap than what should be kept because we just
    # took a snapshot.
    if ($num_snaps == $SNAPS_TO_KEEP_ARG + 1) { 
        delete_snapshot( earliest_snap() );
	return;
    }

    # We haven't reached the snapshot quota yet so we don't delete anything.
    elsif ($num_snaps <= $SNAPS_TO_KEEP_ARG) { return } 

    # User changed their preferences to keep less snapshots. 
    else { 
	
	while ($num_snaps > $SNAPS_TO_KEEP_ARG) {

            my $earliest_snap = earliest_snap();
            
            delete_snapshot( $earliest_snap );
            
            @EXISTING_SNAPS = grep { $_ ne $earliest_snap } @EXISTING_SNAPS;

	    $num_snaps--;
        }
	return;
    } 
}

sub delete_snapshot {

    # Delete a single snapshot
    
    # Just a string like: 'yyyy_mm_dd'
    my $snap_to_delete = shift;

    system("btrfs subvolume delete $TARGET_DIRECTORY/$snap_to_delete");

    return;
}

sub earliest_snap {

    # Shift out a snapshot to get things rolling
    my $earliest_snap  = shift @EXISTING_SNAPS;
    
    foreach (@EXISTING_SNAPS) {
        $earliest_snap = $_ if snapshot_earlier_than($_, $earliest_snap);
    }
    return $earliest_snap;
}

sub snapshot_earlier_than { 

    my $snap1 = shift;
    my $snap2 = shift;

    my @snap1_as_nums = $snap1 =~ m/([0-9]+)/g;
    my @snap2_as_nums = $snap2 =~ m/([0-9]+)/g;

    # Take the lexical order. We know the arrays are equal length.
    for (my $i = 0; $i < scalar @snap1_as_nums; $i++) {
      return 1 if $snap1_as_nums[$i] < $snap2_as_nums[$i];
  }
    return 0;
}
