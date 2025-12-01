package ShipAnimation;
use strict;
use warnings;
use File::Basename;
use File::Spec;

# Get the directory where this module is located
our $MODULE_DIR = dirname(__FILE__);
our $FRAME_DIR = File::Spec->catdir($MODULE_DIR, 'ascii_frames');
our @FRAMES;
our $CURRENT_FRAME = 0;

sub load_frames {
    opendir(my $dh, $FRAME_DIR) or die "Cannot open $FRAME_DIR: $!";
    my @files = sort grep { /^taipan_frame\d+\.txt$/ } readdir($dh);
    closedir($dh);

    foreach my $file (@files) {
        my $path = "$FRAME_DIR/$file";
        open my $fh, '<', $path or die "Cannot read $path: $!";
        my @lines = <$fh>;
        close $fh;
        chomp @lines;
        push @FRAMES, \@lines;
    }

    return scalar @FRAMES;
}

sub get_frame {
    my $frame_num = shift // $CURRENT_FRAME;
    return $FRAMES[$frame_num % scalar @FRAMES];
}

sub next_frame {
    $CURRENT_FRAME = ($CURRENT_FRAME + 1) % scalar @FRAMES;
    return get_frame($CURRENT_FRAME);
}

sub reset {
    $CURRENT_FRAME = 0;
}

1;
