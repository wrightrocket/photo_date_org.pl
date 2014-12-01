#/usr/bin/perl 
# set the above the path of your perl interpreter on Linux or Unix systems
#
# By Keith Wright
# 11/30/1994
#
# photo_date_org.pl
#
# Program organizes jpg and nef files under the current working directory, "org" subdirectory
#
# Organizes photos by year, month and day
# Creates a directory for each year found
# Creates a subdirectory for each month found
# Creates a subdirectory for each day found
# Copies files to subdirectory to day

use warnings;
use strict;
use File::Find qw(find);
use Image::EXIF;
use Image::EXIF::DateTime::Parser;
use Data::Dumper;
use DateTime;
use File::Copy;
use Cwd;

my $VERBOSE = 1; # whether to print more or less output
my $jpgreg = qr/(jpg$)/i; # regular expression for jpg files
my $nefreg = qr/(nef$)/i; # regular expression for nef files

my $basedir = &getcwd; # the starting directory where the subdirectories will be created
$basedir .= "/org";
mkdir $basedir;

find(\&get_date, @ARGV);

sub make_dirs {
	my $time_shot = shift;
	my $datetime = DateTime->from_epoch(epoch => $time_shot);
	my $month = $datetime -> month;
	my $year = $datetime -> year;
	my $day = $datetime -> day;
	mkdir "$basedir/$year";
	mkdir "$basedir/$year/$month";
	mkdir "$basedir/$year/$month/$day";
	return "$basedir/$year/$month/$day"; 
}

sub copy_file {
	my $source = shift;
	my $dest = shift;
	my $path = "$dest/$source";
	if (-r $path) {
		print "Skipping as $path file exists\n";
	} else {
		print "Copying $source\n";
		copy($source, $dest) or warn "$/$_ $!\n"; 
	}
}

sub get_date {
	my $file = $File::Find::name;  # store the full path for later
	print "$file\n";
	if ($_ =~ $jpgreg) { # match all cases of jpg (must use explicit $_ reference)
		my $exif_obj = Image::EXIF->new($_);
		my $other_info = $exif_obj->get_other_info();
		if ($other_info) {
			my $date_info = $$other_info{'Image Generated'};
			if (defined $date_info) {
				my $parser = Image::EXIF::DateTime::Parser->new;
				my $time_shot = $parser->parse($date_info);
				my $dest = &make_dirs($time_shot);
				&copy_file($_, $dest);
			}
		}
	} elsif ($_ =~ $nefreg) {
		my $raw_date = `exiftool -CreateDate $_`;
		my @date_info = split(": ", $raw_date);
		my $parser = Image::EXIF::DateTime::Parser->new;
		my $time_shot = $parser->parse($date_info[1]);
		my $dest = &make_dirs($time_shot);
		&copy_file($_, $dest);
	} else {
		# print "This is unexpected for $file\n";
	}
}


