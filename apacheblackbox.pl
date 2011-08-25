#!/usr/bin/perl

# See embedded perldoc for more information or visit http://www.devco.net/pubwiki/ApacheBlackbox 

use Getopt::Long qw(:config auto_help);
use Pod::Usage;

$starttime = time();

$reportLocation = "";
$reportFrequency = 60;
$skipregex = "";
$storeregex = "";
$storeurldetail = 0;
$stripurltofile = 0;
$logfile = "";

$Fmt=<<EOFMT
^([^/]+)\\ (\\S)\\ \\[([^:]+):(\\d+:\\d+:\\d+)\\ ([^\\]]+)\\]\\s
"(\\S+)\\ (.*?)\\ (\\S+)"\\ (\\d+)/(\\d+)\\ (\\d+)/(\\d+)\\s
(\\d+)/(\\d+)\\ (\\d+)/(\\d+)/(\\d+)\$
EOFMT
;

GetOptions(
	"output=s"    	=> \$reportLocation,
	"frequency=i" 	=> \$reportFrequency,
	"skip=s"        => \$skipregex,
	"show=s"        => \$storeregex,
	"detail"      	=> \$storeurldetail,
	"fileonly"    	=> \$stripurltofile,
	"logfile=s"	=> \$logfile,
	"help"        	=> \$help
) or pod2usage(2);

if ($help || !$reportLocation) {
	pod2usage(-exitstatus => 0, -verbose => 2)
}

# Test the output file
open (LOG, "> $reportLocation") || die("Cannot write to report location ($reportlocation): $!\n");
	print (LOG "parser.uptime=" . (time() - $starttime) . "\n");
	print (LOG "parser.generatedtime=" . time() . "\n");
	print (LOG "parser.settings.skip=$skipregex\n");
	print (LOG "parser.settings.show=$storeregex\n");
	print (LOG "parser.settings.fileonly=$stripurltofile\n");
	print (LOG "parser.settings.output=$reportLocation\n");
	print (LOG "parser.settings.fequency=$reportFrequency\n");
	print (LOG "parser.settings.detail=$storeurldetail\n");
	print (LOG "parser.settings.logfile=$logfile\n");
close (LOG);

$connectionClosed = $connectionKeepAlive = $connectionAborted = 0;
$requestCount = $totalBytesIn = $totalBytesOut = $totalContentSize = 0;
$totalRequestTime = $methods{GET} = $methods{POST} = 0;

@statuscodes = ("100", "101", "200", "201", "202", "203", "204", "205", "206", "300", "301", "302", "303", "304", "305", "306", "307", "400", "401", "402", "403", "404", "405", "406", "407", "408", "409", "410", "411", "412", "413", "414", "415", "416", "417", "500", "501", "502", "503", "504", "505");

$SIG{ALRM} = \&reportState;

if ($logfile) {
	use File::Tail;
	use Proc::Daemon;
	
	my $line;

	if (-r $logfile) {
		Proc::Daemon::Init;
		
		alarm($reportFrequency);

		my $file = File::Tail->new($logfile);
		while (defined($line=$file->read)) {
			processLine($line);
		}
	}
} else {
	my $line;
	alarm($reportFrequency);

	while ($line = <STDIN>)
	{
		processLine($line);
	}
}

&reportState();

sub processLine {
	$line = shift;

        ($remoteIp, $connectionStatus, $date, $time, $gmtOffset, $requestMethod,
         $url, $protocol, $statusBeforeRedir, $statusAfterRedir, $processId, $threadId,
         $seconds, $microseconds, $bytesIn, $bytesOut, $bytesContent)= $line =~ /$Fmt/x;

	$skip = 0; $store = 1;

	if ($skipregex) {
		if ($url =~ /$skipregex/) { $skip = 1; }
	}

	if ($storeregex) {
		unless ($url =~ /$storeregex/) { $store = 0; }
	}

	if ($stripurltofile) {
		if ($url =~ /^(.+?)\?/) {
			$url = $1;
		}
	}

	unless ($skip) {
		$requestCount++;
		$status{$statusAfterRedir}++;
		$methods{$requestMethod}++;

		$totalBytesIn += $bytesIn;
		$totalBytesOut += $bytesOut;
		$totalContentSize += $bytesContent;

		$totalRequestTime += $microseconds / 1000000;

		if ($storeurldetail && $store) {
			$pages{$url}{status}{$statusAfterRedir}++;
			$pages{$url}{totalTime} += $microseconds / 1000000;
			$pages{$url}{requests}++;
		}

		if ($connectionStatus eq "-") {
			$connectionClosed++;
		} elsif ($connectionStatus eq "+") {
			$connectionKeepAlive++;
		} elsif ($connectionStatus eq "X") {
			$connectionAborted++;
		}
	}
}

sub reportState {
	open (LOG, ">$reportLocation");

	print (LOG "parser.uptime=" . (time() - $starttime) . "\n");
	print (LOG "parser.generatedtime=" . time() . "\n");
	print (LOG "parser.settings.skip=$skipregex\n");
	print (LOG "parser.settings.show=$storeregex\n");
	print (LOG "parser.settings.fileonly=$stripurltofile\n");
	print (LOG "parser.settings.output=$reportLocation\n");
	print (LOG "parser.settings.fequency=$reportFrequency\n");
	print (LOG "parser.settings.detail=$storeurldetail\n");

	print (LOG "apache.stats.requestcount=$requestCount\n");
	print (LOG "apache.stats.totalbytesin=$totalBytesIn\n");
	print (LOG "apache.stats.totalbytesout=$totalBytesOut\n");
	print (LOG "apache.stats.totalcontentsize=$totalContentSize\n");
	if (($totalBytesIn > 0) && ($requestCount > 0)) {
		print (LOG "apache.stats.averagebytesin=".($totalBytesIn / $requestCount)."\n");
	} else {
		print (LOG "apache.stats.averagebytesin=0\n");
	}

	if (($totalBytesOut > 0) && ($requestCount > 0)) {
		print (LOG "apache.stats.averagebytesout=".($totalBytesOut / $requestCount)."\n");
	} else {
		print (LOG "apache.stats.averagebytesout=0\n");
	}
			
	if (($totalRequestTime > 0) && ($requestCount > 0)) {
		print (LOG "apache.stats.averagetime=".($totalRequestTime / $requestCount)."\n");
	} else {
		print (LOG "apache.stats.averagetime=0\n");
	}

	print (LOG "apache.stats.totaltime=$totalRequestTime\n");
	print (LOG "apache.connections.closed=$connectionClosed\n");
	print (LOG "apache.connections.keepalive=$connectionKeepAlive\n");
	print (LOG "apache.connections.aborted=$connectionAborted\n");
	print (LOG "apache.requests.get=$methods{GET}\n");
	print (LOG "apache.requests.post=$methods{POST}\n");

	$aggr{100} = $aggr{200} = $aggr{300} = $aggr{400} = $aggr{500} = 0;

	foreach (grep(/^1/, @statuscodes)) { $aggr{100} += $status{$_}; }
	foreach (grep(/^2/, @statuscodes)) { $aggr{200} += $status{$_}; }
	foreach (grep(/^3/, @statuscodes)) { $aggr{300} += $status{$_}; }
	foreach (grep(/^4/, @statuscodes)) { $aggr{400} += $status{$_}; }
	foreach (grep(/^5/, @statuscodes)) { $aggr{500} += $status{$_}; }

	print(LOG "apache.status.1xx=$aggr{100}\n");
	print(LOG "apache.status.2xx=$aggr{200}\n");
	print(LOG "apache.status.3xx=$aggr{300}\n");
	print(LOG "apache.status.4xx=$aggr{400}\n");
	print(LOG "apache.status.5xx=$aggr{500}\n");

	foreach (@statuscodes) {
		unless ($status{$_}) { $status{$_} = 0; }

		print (LOG "apache.status.$_=$status{$_}\n");
	}


	if ($storeurldetail) {
		foreach $u (keys(%pages)) {
			%page = %{$pages{$u}};
			%statuses = %{$page{status}};

			print(LOG "apache.requests.$u.served=$page{requests}\n");
			print(LOG "apache.requests.$u.totaltime=$page{totalTime}\n");
			print(LOG "apache.requests.$u.averagetime=" . ($page{totalTime} / $page{requests}) . "\n");
	
			$aggr{100} = $aggr{200} = $aggr{300} = $aggr{400} = $aggr{500} = 0;
			foreach (grep(/^1/, @statuscodes)) { $aggr{100} += $statuses{$_}; }
			foreach (grep(/^2/, @statuscodes)) { $aggr{200} += $statuses{$_}; }
			foreach (grep(/^3/, @statuscodes)) { $aggr{300} += $statuses{$_}; }
			foreach (grep(/^4/, @statuscodes)) { $aggr{400} += $statuses{$_}; }
			foreach (grep(/^5/, @statuscodes)) { $aggr{500} += $statuses{$_}; }

			print(LOG "apache.requests.$u.1xx=$aggr{100}\n");
			print(LOG "apache.requests.$u.2xx=$aggr{200}\n");
			print(LOG "apache.requests.$u.3xx=$aggr{300}\n");
			print(LOG "apache.requests.$u.4xx=$aggr{400}\n");
			print(LOG "apache.requests.$u.5xx=$aggr{500}\n");

			foreach (@statuscodes) {
				unless ($statuses{$_}) { $statuses{$_} = 0; }
			
				print(LOG "apache.requests.$u.$_=$statuses{$_}\n");
			}
		}
	}

	close (LOG);

	alarm($reportFrequency);
}

=head1 SYNOPSIS
apacheblackbox.pl [options] --output=file

Options:
  --output             the output file to create
  --detail             enable the storing of full details for each unique request
  --skip               regular expression for requests that will not count to any stats
  --show               regular expression for requests that will have full detail
  --fileonly           strip parameters from requests for storing detail
  --logfile            use a logfile instead of STDIN
  --help               full documentation

=head1 DESCRIPTION

This is a parser for apache log files that is intended to be used in a pipe from within apache.  The basic idea is that you define a custom log format that contains performance and size details for each request, this parser will understand this format and produce regular statistics based on the input.

The statistics gets written to a file, see B<--output>, in the format:

 variable=value

A sample from an actual run below:

	parser.uptime=50
	parser.generatedtime=1204722895
	apache.requests.get=1359263
	apache.requests.post=50980
	apache.status.1xx=0
	apache.status.2xx=1123841
	apache.status.3xx=307707
	apache.status.4xx=444
	apache.status.5xx=22
	apache.status.100=0
	apache.status.101=0
	apache.status.200=1123740

There are many more variables kept with self explanatory names.  In addition to overall stats details for each unique URL can be kept.  The list of URLs to be considered for statistics can be manipulated using the B<--skip> and B<--show> options, how to deal with parameters in the requests can be modified using the B<--fileonly> option.

Most of the values are always incrementing counters, they will overflow back to zero when the limits of the data storage is reached, these are best used in a B<DERIVE> data format in a RRD file using tools such as Cacti.

=head1 OPTIONS

=over 8

=item B<--output>

The output file to create

=item B<--detail>

When enabled a detailed block of stats will be kept for each url accessed, 2 other options modify the behaviour of this see B<--show> and B<--fileonly>

=item B<--skip>

This takes a regular expression of pages that stats should not be kept for.  You can use this to keep stats for everything except for example images by using something like '\.jpg|\.gif$'.  Requests matching this regular expression will not count towards any stats, not detailed stats and not the totals for the server.

=item B<--show>

If B<--detail> is enabled all unique requests will get a block of stats individual to that request, this will often result in a large list of unexpected statistics being kept for no good reason, you can restrict it to only keeping statistics for files ending in .php by using a regular expression like '\.php$'.   With this in place you will only get performance stats for your PHP scripts.


=item B<--fileonly>

If B<--detail> is enabled statistics for each unique request will be kept, determining uniqueness will include the parameters passed to the script as part of the URL, often this is not desirable using this option the parameters gets discarded and all requests - regardless of parameters - will be considered as one requests and thus count only to one detailed stats block.

=item B<--logfile>

By default the intention is to use CustomLog in Apache and pipe the log lines to this script, this is the most robust option as Apache will start the parser should it exit etc, in some cases it might be desirable to just parse a log file instead.  Supplying the B<--logfile> option with a path to a file will enable this.

=item B<--help>

This help page.

=back

=head1 INSTALLATION

Installation is usually just a matter of copying the file anywhere on your file system.  Documentation can be viewed with perldoc, to use B<--help> you need B<Pod::Usage>. If you want to parse log files rather than pipe to STDIN you will also need the B<Proc::Daemon> and B<File::Tail> Perl modules.

To activate this script you need to have B<mod_logio> enabled in your apache configuration:

	LoadModule logio_module modules/mod_logio.so

With this enabled you can now configure a custom log format to write compatible log entries to this script, you can do this inside a VirtualHost, various other places where CustomLog is valid in an apache config file:

	<IfModule mod_logio.c>
		CustomLog "| /path/to/apacheblackbox.pl --output /var/www/blackbox.txt --detail"  "%a %X %t \"%r\" %s/%>s %{pid}P/%{tid}P %T/%D %I/%O/%B"
	</IfModule>

As you can see any of the above options simply get passed to the script from the Apache CustomLog lines, you can further select only certain requests to be passed to this log using the normal apache methods such as B<Location> blocks etc:

	<Location /cgi-bin>
		SetEnv blackboxlog 1
	</Location>

	<IfModule mod_logio.c>
		CustomLog "| /path/to/apacheblackbox.pl --output /var/www/blackbox.txt --detail --show \\'script.pl\\'"  "%a %X %t \"%r\" %s/%>s %{pid}P/%{tid}P %T/%D %I/%O/%B" env=blackboxlog
	</IfModule>

Combining the Apache control blocks with the options to this script such as B<--skip> and B<--show> gives you very fine grained control over what stats to record and can be used using the same basic script on many virtual hosts and sets of files on the same machine concurrently.

If you need to consider logs from several virtual hosts as one or simply wish to also store the log on your disk you can instruct the script to read the logfile from disk using the B<--logfile> option.  You would then make a CustomLog that save to a file and just run in the parser, when called with the B<--logfile> option it will daemonize to the background.  While we've not had stability problems with the script you may want to monitor it is running either through process list, via the B<parser.generatedtime> variable or the age of the output file.

=head1 CREDITS

This is based on a basic concept found here: http://www.onlamp.com/pub/a/apache/2004/04/22/blackbox_logs.html

=head1 AUTHOR

Written by R.I.Pienaar, visit http://www.devco.net/pubwiki/ApacheBlackbox/ for more info.

=cut
