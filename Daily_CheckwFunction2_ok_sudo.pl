#!/usr/bin/env perl

#use strict;
use Getopt::Long;

sub ERROR;
sub check_disk_space();
sub check_disk_mirrors();
sub check_free_memory();

my $flash_check = 0;
my $free_memory_threshold = undef();
my %disk_thresholds;

GetOptions ("flash_check" => \$flash_check,
        "free_memory=i" => \$free_memory_threshold,
        "disk_threshold=s%" => \%disk_thresholds);
# GetOptions ("length=i" => \$length, # numeric
# "file=s" => \$data, # string
# "verbose" => \$verbose); # flag

my $hostname = `hostname`;
my $os = `uname -s`;
chomp($os);

print "Testing started for $hostname.\n";
if ($os !~ /^(hp-ux|sunos|Linux)$/i) {
        ERROR "OS '$os' is not supported";
}

#>>>> OMar modification -- start <<<<<
#please modifiy the shell script location aand the logfile location
# Modify the shell script and log file locations
my $shell_script1 = '~/NDC_Bkup-copy.sh';
my $log_file1 = '~/Backup-ndc.log';
my $shell_script2 = '~/SDC_Bkup-copy.sh';
my $log_file2 = '~/Backup-sdc.log';
#>>>> Omar Modification -- end <<<<

my $success = 1;
if (!check_disk_space()) { $success = 0; }
if (!check_disk_mirrors()) { $success = 0; }
if (!check_free_memory()) { $success = 0; }

#>>>> OMar modification -- start <<<<<
if(!run_script_and_print_log($shell_script1, $log_file1)) { $success = 0; }
if(!run_script_and_print_log($shell_script2, $log_file2)) { $success = 0; }
#>>> omar modification -- end <<<<<

print "Testing completed.\n";
if ($success) {
        print "SERVER_STATUS: All Tests Completed Successfully.\n";
} else {
        print "SERVER_STATUS: There Were Errors.\n";
}

exit;

# Now the Checks and Functions...

#>>>> omar Modification -- start <<<<<
# Subroutine to run a shell script and print the contents of a log file
 sub run_script_and_print_log {
     my ($shell_script, $log_file) = @_;

# Run the shell script with sudo
my $cmd = "sudo $shell_script";
system($cmd) == 0
    or die "Failed to execute $cmd: $!";

# Run the shell script
# system($shell_script) == 0
#      or die "Failed to execute $shell_script: $!";

 # Check if the log file exists
 if (-e $log_file) {
 # Open the log file for reading
        open my $fh, '<', $log_file
                 or die "Could not open log file $log_file: $!";
 # Print the contents of the log file
        while (my $line = <$fh>) {
               print $line;
               }
 # Close the file handle
       close $fh;
               } else {
               die "Log file $log_file does not exist.";
               }
 }
#>>>> omar modification -- end <<<<

sub ERROR {
        my $message = join(" ", @_);
        chomp($message);
        print "ERROR:   $message\n";
        exit(0);
}

sub check_disk_space() {
        print "Preforming Disk Space Check.\n";
        my $default_threshold = 78;
        my $command = 'df -Pk'; # Use df -k as its closest to the HP-UX output
        if ($os =~ /hp-ux/i) { $command = 'bdf'; }
        my $results = `$command`;

        print $results;

        # Hack add on to check that either /flash or /flash2 is mounted...
        my $flash_found = 0;

        my $success =1;
        my @results = split("\n", $results);
        my $header = shift(@results);
        foreach my $line (@results) {
                chomp($line);
                my ($filesystem, $kbytes, $used, $available, $percent_used, $mounted_on) = split(" ", $line);
                if ($mounted_on =~ /^\/flash2?$/) {
                        $flash_found = 1;
                }
                $percent_used =~ s/%//ig;

                # Check to see if they have specifed a specific threshold for this partition...
                my $threshold = $default_threshold;
                if (exists($disk_thresholds{$filesystem})) {
                        print "INFO: For $filesystem threshold chaned to " . $disk_thresholds{$filesystem} . " from default of $threshold.\n";
                        $threshold = $disk_thresholds{$filesystem};
                }
                if ($percent_used > $threshold) {
                        # Ignore CD-Roms...
                        if ($mounted_on !~ /cdrom/i) {
                                print "WARNING: $filesystem ($mounted_on) has $percent_used% used (over threshold of $threshold%).\n";
                                $success = 0;
                        }
                }
        }

        # Check to make sure we found a mounted flash partition...
        if ($flash_check && !$flash_found) {
                print "WARNING: Flash partition not mounted.\n";
                $success = 0;
        }

        if ($success) {
                print "STATUS: Disk Space Check Test Successful.\n";
        } else {
                print "STATUS: Disk Space Check Test Completed with Errors.\n";
        }
        return $success;
}

sub check_disk_mirrors() {
        print "Preforming Disk Mirror Check.\n";

        my $success = 1;

        if ($os !~ /sunos/i) {
                print "No Checks defined for OS '$os', assuming all is good.\n";
        } else {
                # A solaris server!!!
                my $command = '/usr/sbin/metastat';
                my $results = `$command`;
                print $results;

                $command = '/usr/sbin/metastat | grep "State:" | grep -v Okay |wc -l';
                $results = `$command`;
                chomp($results);
                $results =~ s/^\s*(\d+)\s*$/$1/;

                if ($results) {
                        # An error was found!
                        print "WARNING: Disk Mirror in unexpected state found, please check the detailed logs for more information.\n";
                        $success = 0;
                }
        }

        if ($success) {
                print "STATUS: Disk Mirror Memory Check Test Successful.\n";
        } else {
                print "STATUS: Disk Mirror Check Test Completed with Errors.\n";
        }
        return $success;
}

sub check_free_memory_hpux() {
        print "OS Type HP-UX.\n";
        my $threshold = 60;
        if (defined($free_memory_threshold) && $free_memory_threshold > 0) {
                print "INFO: Free Memory Threshold changed to $free_memory_threshold from default of $threshold.\n";
                $threshold = $free_memory_threshold;
        }
        my $command = '/usr/sbin/swapinfo -Mt';
        my $results = `$command`;

        print $results;

        my $success = 1;
        chomp($results);
        my @results = split("\n", $results);

        # Grab the last line as that is the data..
        my $line = $results[-1];
        chomp($line);
        my @data = split(" ", $line);

        my $value = $data[4];
        chomp($value);
        $value =~ s/\%//;
        if ($value > $threshold) {
                print "WARNING: Free memory at " . $value . "% (over threshold $threshold%).\n";
                $success = 0;
        }

        return $success;
}

sub check_free_memory_sunos() {
        print "OS Type SunOS.\n";
        my $threshold = 140000;
        my $command = 'vmstat';
        my $results = `$command`;

        print $results;

        my $success = 1;
        chomp($results);
        my @results = split("\n", $results);

        # Free memory is the 5th column

        # Grab the last line as that is the data..
        my $line = $results[-1];
        chomp($line);
        my @data = split(" ", $line);

        if ($data[4] < $threshold) {
                print "WARNING: Free memory at " . $data[4] . " (under threshold $threshold).\n";
                $success = 0;
        }

        return $success;
}

sub check_free_memory() {
        print "Preforming Free Memory Check.\n";

        my $success;

        if ($os =~ /hp-ux/i) { $success = check_free_memory_hpux(); }
        else { $success = check_free_memory_sunos(); }

        if ($success) {
                print "STATUS: Free Memory Check Test Successful.\n";
        } else {
                print "STATUS: Free Memory Check Test Completed with Errors.\n";
        }
        return $success;
}

__END__;

############################
# Set to yesterdays date
###########################

TZ=NZ+12 #Copyright Shane Forshaw
###########################
YEARLONG=`date +%Y`
YEAR=`date +%y`
DATE=`date +%m%d`
DATETIME=`date +%y%m%d`
MONTH=`date +%m`
DAY=`date +%d`
HOUR=`date +%H`
MIN=`date +%M`
############################
YESTERDAY=`date +%y%m%d`
case $MONTH in
01) MTH="Jan" ;;
02) MTH="Feb" ;;
03) MTH="Mar" ;;
04) MTH="Apr" ;;
05) MTH="May" ;;
06) MTH="Jun" ;;
07) MTH="Jul" ;;
08) MTH="Aug" ;;
09) MTH="Sep" ;;
10) MTH="Oct" ;;
11) MTH="Nov" ;;
12) MTH="Dec" ;;
esac

MONTHLONG=$MTH" "$DAY
MONTHCORRECT=$DAY" "$MTH
##############################
# Section 1

LIMIT=80
NAME=`uname -n`
SERVCHECK="/tmp/Daily_Check.txt"

echo "Server Check Script for ${NAME} ${MONTHCORRECT}

#############################
" > ${SERVCHECK}
echo "Section 1:
________________

Checks ${NAME} filesystem - df -h to give the partion table
" >> $SERVCHECK

df -h >> ${SERVCHECK}
echo "

###############################################################
" >> ${SERVCHECK}
echo "Section 2:
________________

Checks ${NAME} error messages - from /var/adm

" >> ${SERVCHECK}
cat /var/adm/messages |grep "$MONTHLONG" >> ${SERVCHECK}
echo "

###############################################################
" >> ${SERVCHECK}

echo "Section 3:
________________

Checks metastat command - looks for any entries where the State: does NOT equal Okay.

E.g. # metastat | grep State: | grep -v Okay | wc -l
" >> ${SERVCHECK}

metchk=`/usr/sbin/metastat | grep "State:" | grep -v Okay |wc -l`

if [ $metchk -eq 0 ]
        then
echo "
The metastat command appears OK - all State: entries are Okay.


################################################################
" >> ${SERVCHECK}
else
echo "
###################################################################################################
                ****** WARNING ******
There is an issue with the metastat command - please run the metastat command and resolve the issue.
                *********************
###################################################################################################

################################################################
" >> ${SERVCHECK}
fi

#/usr/bin/sar -f /var/adm/sa/sa$DAY -i 3600 -ur >> ${SERVCHECK}

#mailx -s "Server Heath Checks" bruce.rhodes@transpower.co.nz < ${SERVCHECK}
#rm ${SERVCHECK}
