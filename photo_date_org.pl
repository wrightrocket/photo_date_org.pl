#!/usr/bin/perl 
# set the above the path of your perl interpreter on Linux or Unix systems
#
# By Keith Wright
# 11/30/2014
# 01/31/2015
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
# allow use of given
use feature "switch";

# This program will not run with the standard perl distribution
# Modules must be installed in order to run this program
#
# To install modules use the cpan command
# or the package manager for your distribution
# of your operating system or perl
# 
# In ActiveState Perl use the ppm command
#
# To learn more about these  modules search at: 
# http://search.cpan.org/
#
# The following modules were not installed
# by default and had to be installed as
# a prerequisite to compile the other modules.
#
# They are not always part of a distribution.
# Install these before the other modules.

use Params::Validate;
use Try::Tiny;
use Test::Fatal;
use Test::Warnings;
use Module::Build;
use DateTime::Locale;
use DateTime::TimeZone;

# These modules may also need to be installed
# They are the ones that are really used
# Install these after installing the above modules

use File::Find qw(find);
use Image::EXIF::DateTime::Parser;
use Image::ExifTool qw(ImageInfo);
use DateTime;

# These modules should be part of a standard distribution
# They probably will not need to be installed 

use Data::Dumper;
use File::Copy;
use Cwd;

# These variables can be set on off (0 or 1)
# They should only be used by hackers
my $DEBUG = 0; # 1 to print debug output, 0 to not
my $VERBOSE = 1; # 1 to print output, 0 to run silently except errors
my $PROGRESS = 0; # 1 to show progress, 0 to run silently except errors
my $GO = 0; # 1 to automatically confirm, 0 to confirm before running
my $OVERWRITE = 0; # 1 to overwrite destination files, 0 to skip
my $DELETE = 0; # 1 to delete original files, 0 to retain them

# These are the regular expressions that are currently available
# This list is expanding over time
my $avireg = qr/(\.avi$)/i; # regular expression to match avi files
my $dvreg = qr/(\.dv$)/i; # regular expression to match dv files
my $flvreg = qr/(\.flv$)/i; # regular expression to match flv files
my $gifreg = qr/(\.gif$)/i; # regular expression to match gif files
my $jpgreg = qr/(\.jpe?g$)/i; # regular expression to match jpeg/jpg files
my $m2vreg = qr/(\.m2v$)/i; # regular expression to match m2v files
my $m4vreg = qr/(\.m4v$)/i; # regular expression to match m4v files
my $modreg = qr/(\.mod$)/i; # regular expression to match mod files
my $movreg = qr/(\.mov$)/i; # regular expression to match quicktime files
my $mp4reg = qr/(\.mp4$)/i; # regular expression to match mp4 files
my $mpgreg = qr/(\.mpe?g$)/i; # regular expression to match mpeg/mpg files
my $nefreg = qr/(\.nef$)/i; # regular expression to match Nikon raw nef files
my $pngreg = qr/(\.png$)/i; # regular expression to match png files
my $threegpreg = qr/(\.3gp$)/i; # regular expression to match 3gp files
my $vobreg = qr/(\.vob$)/i; # regular expression to match 3gp files
# Add your own regular expression above and then add it to the array below
my @regs = ($jpgreg, $nefreg, $pngreg, $gifreg, $threegpreg, $avireg, 
	$mpgreg, $m2vreg, $m4vreg, $mp4reg, $movreg, $modreg, $flvreg, $dvreg, $vobreg);

# This are variables used for statistics in the "finished" report
my $files_processed = 0; # track total number of files
my $files_copied = 0; # track the number of files copied
my $files_errors = 0; # track the number of files copied with errors
my $files_skipped = 0; # track the number of files skipped
my $size_copied = 0; # total size copied
my $size_skipped = 0; # total size of files skipped
my $end_time = 0;
my $total_time = 0;
my %extensions = ();
my @copies = ();
my @errors = ();
my @skips = ();

# These variables set the default values if not passed as arguments
# for the directories to copy from and to ($source_dir and $dest_dir)
my $curdir = &getcwd; # get the current working directory "."
my $source_dir = $curdir; # use the current directory to process by default
# $dest_dir is where the files will be copied and this directory will be excluded
# my $dest_dir = $curdir . "/org"; # use ./org for subdirectories to create
my $dest_dir = "/nas/photos/org/"; # hard-coded example

& main(@ARGV); # Start the program by executing the main function

sub main {
	$File::Find::dont_use_nlink=1; # always stat directories
	&check_arg; # if $GO is not equal to one then arguments or assumptions will be confirmed
	find(\&process_file, $source_dir); # find every file get the date and copy new or different sized files
	($VERBOSE || $PROGRESS) && &finished; # print a summary report if $VERBOSE
}

sub confirm {
	if (! $GO || $VERBOSE) {
		print "Do you want to continue? (y/n) ";
		my $answer = <STDIN>;
		my @letters = split ('', $answer);
		$answer = lc $letters[0];
		$DEBUG && print "\$answer = $answer\n";
		if (lc $answer eq 'y') {
			return 1;
		} else {
			return 0;
		}
	} else {
		return 1;
	}
} 

sub time_total {
	$end_time = time();
	return $end_time - $^T;
}

sub print_extensions {
	print "The following file extensions were not processed:\n";
	print "File Extension\t\tFiles Found\n\n";
	my $times = 1;
	for my $ext (keys %extensions) {
		$times = $extensions{$ext};
		print "\t$ext\t\t$times\t\n";
	}
	print "\n";
}

sub finished {
	print "\n\nReport for processing $source_dir\n";
	print "Files processed:  $files_processed \n";
	print "Files copied: $files_copied\n";
	print Dumper(@copies);
	print "Size of files copied: $size_copied\n";
	print "Files with errors on copy: $files_errors\n";
	print Dumper(@errors);
	print "Files skipped: $files_skipped\n";
	# print Dumper(@skips);
	print "Size of files skipped: $size_skipped\n";
	%extensions && &print_extensions; # print skipped extensions if any
	$total_time = &time_total;
	print "Time in seconds directory was processed: $total_time\n\n";
}

sub check_arg {
	$VERBOSE && print "Usage photo_date_org.pl <SOURCE_DIR> <DESTINATION_DIR>\n";
	$VERBOSE && print "The following defaults will be used:\n\n";
	if (@ARGV) {
		if ($ARGV[0] && $ARGV[1]) {
			$source_dir = $ARGV[0];		
			$dest_dir = $ARGV[1];		
		} else {
			$source_dir = $ARGV[0];		
		}
	}
	($VERBOSE || $PROGRESS) && print "SOURCE_DIR: $source_dir\n";
	($VERBOSE || $PROGRESS) && print "DESTINATION_DIR: $dest_dir\n"; 
       
	if (! &confirm) {
		print "Goodbye!\n";
		exit;
	}
}

sub make_dirs {
	my $time_shot = shift;
	my $datetime = DateTime->from_epoch(epoch => $time_shot);
	my $month = $datetime -> month;
	my $year = $datetime -> year;
	my $day = $datetime -> day;
	mkdir "$dest_dir/$year";
	mkdir "$dest_dir/$year/$month" || warn "$dest_dir/$year/$month exists";
	mkdir "$dest_dir/$year/$month/$day";
	return "$dest_dir/$year/$month/$day"; 
}

sub do_copy_file {
	my $source = shift;
	my $dest = shift;
	my $s_size = shift;
	$VERBOSE && print "Copying $source to destination $dest\n\n";
	if (copy($source, $dest)) {
		$size_copied += $s_size;
		$files_copied++;
		$PROGRESS && (!$VERBOSE) && print "c";
		push @copies, "$dest/$source";
		if ($DELETE) {
			my $size = (stat("$dest/$source"))[7] || 0;
			if ($s_size = $size) {
				$VERBOSE && print "DELETING: Deleting file as \$DELETE is true\n";
				unlink $source or warn "DELETE FAILED: Could not unlink $source: $!";
				$VERBOSE && print "DELETED SOURCE FILE: copy is same size as original\n";
			} else {
				$VERBOSE && print "RETAINING FILE: copy differs in size from original\n";
			}
		} else {
				$VERBOSE && print "RETAINING FILE: Retaining file as \$DELETE is false\n";
			
		}
	} else {
		warn "$/$_ $!\n"; 
		$files_errors++;
		$PROGRESS && (!$VERBOSE) && print "e";
		push @errors, $source;
	}
}

sub copy_file {
	my $source = shift;
	my $dest = shift;
	my $s_size = shift;
	my $path = "$dest/$source";
	my $filepath = $source;
	
	if (-r $path) {
		$DEBUG && print"Path: $path\n";
		my $size = (stat($filepath))[7] || 0;
		$DEBUG && print"Size: $size\n";
		my $d_size = ($size || (-s $path) || 0);
		$VERBOSE && print "Comparing size of $path\n";
		if ($s_size == $d_size) {
		    	if ($OVERWRITE) {
		    		$VERBOSE && print "FILES ARE IDENTICAL: Copying as \$OVERWRITE is true\n";
				&do_copy_file($source, $dest, $s_size);
			} else {
		        	$VERBOSE && print "FILES ARE IDENTICAL: Skipping as \$OVERWRITE is false\n";
				$PROGRESS && (!$VERBOSE) && print "s";
				$files_skipped++;
				$size_skipped += $s_size;
				push @skips, $filepath;
		    	}	
		} else { 
		    	if ($OVERWRITE) {
		    		$VERBOSE && print "FILES ARE DIFFERENT SIZE: Copying as \$OVERWRITE is true\n";
				&do_copy_file($source, $dest, $s_size);
			} else {
		        	$VERBOSE && print "FILES ARE DIFFERENT SIZE: Skipping as \$OVERWRITE is false\n";
				$PROGRESS && (!$VERBOSE) && print "s";
				$files_skipped++;
				$size_skipped += $s_size;
				push @skips, $filepath;
		    	}	

		}
		if ($DELETE) {
			if ($s_size = $d_size) {
				$VERBOSE && print "DELETING: Deleting file as \$DELETE is true\n";
				unlink $source or warn "DELETE FAILED: Could not unlink $source: $!";
				$VERBOSE && print "DELETED SOURCE FILE: copy is same size as original\n\n";
			} else {
				$VERBOSE && print "RETAINING FILE: copy differs in size from original\n";
			}
		} else {
				$VERBOSE && print "RETAINING FILE: Retaining file as \$DELETE is false\n\n";
			
		}
	} else {
		&do_copy_file($filepath, $dest, $s_size)
	}
}

sub fix_date {
	my $date = shift;
	$DEBUG && $date && print "\$date: $date\n";
	if ($date) {
		# Fix problem with date unknown
		$date = "";

		# Fix problem with dates separated by colons
		$date =~ s/(\d{4}):(\d{1,2}):(\d{1,2}) (\d{2}:\d{2}:\d{2})/$1-$2-$3 $4/;

		# if non-standard format of 07/29/2011 17:56:37
		# change from mm/dd/yyyy HH:MM:SS to yyyy-mm-dd HH:MM:SS
		if ($date =~/^(\d{2})\/(\d{2})\/(\d{4}) (.*)$/) {
			$date = "$3-$2-$1 $4";
		}
		
		# Fix problem with trailing newline
		chomp $date;
	
		# Fix problem with all zeros date 0000-00-00 00:00:00
		if ($date =~ /(0{4})-(0{2})-(0{2})/) {
			$date = "";
		}
		# Fix problem with 2011:06:26 19:02-07:00
		$date =~ s/([0123456789:]+) ([0123456789:]{5})-([0123456789:]+)/$1 $2:00-$3/; 
		
		# Fix problem with Sat Apr 18 14:32:56 2009
		if ($date =~ /\w+ (\w+) (\d+) ([0123456789:])+ (\d{4})/) {
			my $month = $1;
			my $mon = "01";
			given ($month) {
				$mon = "01" if /jan/i;
				$mon = "02" if /feb/i;
				$mon = "03" if /mar/i;
				$mon = "04" if /apr/i;
				$mon = "05" if /may/i;
				$mon = "06" if /jun/i;
				$mon = "07" if /jul/i;
				$mon = "08" if /aug/i;
				$mon = "09" if /sep/i;
				$mon = "10" if /oct/i;
				$mon = "11" if /nov/i;
				$mon = "12" if /dec/i;
			}			
			$date = "$4-$mon-$2 $3";
			$DEBUG && print "Date problem Sat Apr 18 14:32:56 2009\n"; 
		}
		# Fix problem with incomplete time
		# 2009-04-18 6
		if ($date =~ /(\d+)-(\d+)-(\d+) ?([0123456789:]{0,2})/) {
			$date = "$1-$2-$3 00:00:00";
		}

	}
	$DEBUG && print "Date Info in \$date: $date\n";
	return $date;
}

sub get_raw_date_and_copy {
	my $file = shift;
	my $size = shift;
	$DEBUG && print "\$file variable: $file\n";
	# my $raw_date = `exiftool -CreateDate "$file"`; 
	# avoiding the system command and using a module is much faster
	my $exifTool = new Image::ExifTool;
	$exifTool->ExtractInfo($file);
	my $raw_date = $exifTool->GetValue('CreateDate') || "";
	$raw_date = &fix_date($raw_date);
	$DEBUG && print "CreateDate: $raw_date\n";
	
	if (! $raw_date) {
		# my $raw_date = `exiftool -DateTimeOriginal "$file"`;
		$raw_date = $exifTool->GetValue('DateTimeOriginal');
		$raw_date = &fix_date($raw_date);
	 	$DEBUG || $VERBOSE && $raw_date && print "DateTimeOriginal of $raw_date used\n";
	} else {
	 	$DEBUG || $VERBOSE && $raw_date && print "CreateDate of $raw_date used\n";
	}

	if (!$raw_date) { # if the CreateDate or DateTimeOriginal is not available
		# try the ImageGenerated tag
		$raw_date = $exifTool->GetValue('ImageGenerated');
		$raw_date = &fix_date($raw_date);
                $DEBUG && $raw_date && print "ImageGenerated of $raw_date used\n";
		if (!$raw_date) { # if the CreateDate or DateTimeOriginal or ImageGenerated is not available
			# use the date from the folder org yyyy-m?m-d?d
			if ("$file" =~ /(\d{4})\/(\d{1,2})\/(\d{1,2})\//) {
				$raw_date = "$1-$2-$3 00:00:00";
				$DEBUG || $VERBOSE && $raw_date && print "Folder date used: $raw_date\n";
			} else { # Use FileModificationDate as final fallback way to determine date
				$raw_date = $exifTool->GetValue('FileModifyDate');
				$DEBUG || $VERBOSE && $raw_date && print "File modification date used: $raw_date\n";
			}
		}
	}

	my $parser = Image::EXIF::DateTime::Parser->new;
	my $time_shot = $parser->parse($raw_date);
	my $dest = &make_dirs($time_shot);
	&copy_file($_, $dest, $size);
}

sub process_file {
	my $file = qq($File::Find::name);  # store the full path for later
	$DEBUG && print"Original file name: $_\n";
	$_ = qq($_); # add double quotes for handling odd file names
	my $filepath = $curdir."/".$file;
	$filepath = qq($filepath);
	$DEBUG && print"Filepath: $filepath\n";
	my $size = (stat($filepath))[7] || 0;
	$DEBUG && print"Filesize: $size\n";
	if (-d "$filepath") {
		$VERBOSE && print "Found directory: $file\n\n";
		$PROGRESS && (!$VERBOSE) && print "d";
		return 0; # Don't process directory files
	} elsif (! $size) {
		$VERBOSE && print "Found empty file: $file\n";
		$PROGRESS && (!$VERBOSE) && print "0";
		$files_skipped++;
		return 0; # Don't process empty files
		
	} 
	$VERBOSE && print "Processing source file: $file\n";
	# $PROGRESS && (!$VERBOSE) && print ".";
	$files_processed++; # track total number of files
	my $nomatch = 1;
	for my $reg (@regs) { # use regular expressions in @regs to match file
		if ($_ =~ $reg) {
			$nomatch = 0;
			$DEBUG && print "Matching RE: $reg\n";
			&get_raw_date_and_copy($filepath, $size);
			last;
		}
	}
	if ($nomatch) { # Bypass all files that don't match the regular expressions
		$size_skipped += $size;
		$files_skipped++;
		push @skips, $filepath;
		/.*\.(\w+)$/ ; # match the file name extension group
		$VERBOSE && print "Bypassing unknown extension: $1\n\n";
		if ($1 && defined $extensions{$1}) { # increment the number found 
			$extensions{$1} = ++$extensions{$1};
		} elsif ($1) { # define the key and set the value to one for the first found
			$extensions{$1} = 1;
		} else {
			$DEBUG && print "This is unexpected for $_\n\n";
		}
	}
}
