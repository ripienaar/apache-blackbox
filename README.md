SYNOPSIS
========

<pre>
apacheblackbox.pl [options] --output=file

Options:
  --output             the output file to create
  --detail             enable the storing of full details for each unique request
  --skip               regular expression for requests that will not count to any stats
  --show               regular expression for requests that will have full detail
  --fileonly           strip parameters from requests for storing detail
  --logfile            use a logfile instead of STDIN
  --help               full documentation
</pre>

DESCRIPTION
===========

This is a parser for apache log files that is intended to be used in a pipe from within apache.  The basic idea is that you define a custom log format that contains performance and size details for each request, this parser will understand this format and produce regular statistics based on the input.

The statistics gets written to a file, see _--output_, in the format:

<pre>
 variable=value
</pre>

A sample from an actual run below:

<pre>
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
</pre>

There are many more variables kept with self explanatory names.  In addition to overall stats details for each unique URL can be kept.  The list of URLs to be considered for statistics can be manipulated using the _--skip_ and _--show_ options, how to deal with parameters in the requests can be modified using the _--fileonly_ option.

Most of the values are always incrementing counters, they will overflow back to zero when the limits of the data storage is reached, these are best used in a _DERIVE_ data format in a RRD file using tools such as Cacti.

OPTIONS
=======

--output
--------

The output file to create

--detail
--------

When enabled a detailed block of stats will be kept for each url accessed, 2 other options modify the behaviour of this see _--show_ and _--fileonly_

--skip
------

This takes a regular expression of pages that stats should not be kept for.  You can use this to keep stats for everything except for example images by using something like _\.jpg|\.gif$_.  Requests matching this regular expression will not count towards any stats, not detailed stats and not the totals for the server.

--show
------

If _--detail_ is enabled all unique requests will get a block of stats individual to that request, this will often result in a large list of unexpected statistics being kept for no good reason, you can restrict it to only keeping statistics for files ending in .php by using a regular expression like _\.php$_.   With this in place you will only get performance stats for your PHP scripts.


--fileonly
----------

If _--detail_ is enabled statistics for each unique request will be kept, determining uniqueness will include the parameters passed to the script as part of the URL, often this is not desirable using this option the parameters gets discarded and all requests - regardless of parameters - will be considered as one requests and thus count only to one detailed stats block.

--logfile
---------

By default the intention is to use CustomLog in Apache and pipe the log lines to this script, this is the most robust option as Apache will start the parser should it exit etc, in some cases it might be desirable to just parse a log file instead.  Supplying the _--logfile_ option with a path to a file will enable this.

_--help_

This help page.

INSTALLATION
============

Installation is usually just a matter of copying the file anywhere on your file system.  Documentation can be viewed with perldoc, to use _--help_ you need _Pod::Usage_. If you want to parse log files rather than pipe to STDIN you will also need the _Proc::Daemon_ and _File::Tail_ Perl modules.

To activate this script you need to have _mod_logio_ enabled in your apache configuration:

<pre>
	LoadModule logio_module modules/mod_logio.so
</pre>

With this enabled you can now configure a custom log format to write compatible log entries to this script, you can do this inside a VirtualHost, various other places where CustomLog is valid in an apache config file:

<pre>
	&lt;IfModule mod_logio.c&gt;
		CustomLog "| /path/to/apacheblackbox.pl --output /var/www/blackbox.txt --detail"  "%a %X %t \"%r\" %s/%>s %{pid}P/%{tid}P %T/%D %I/%O/%B"
	&lt;/IfModule&gt;
</pre>

As you can see any of the above options simply get passed to the script from the Apache CustomLog lines, you can further select only certain requests to be passed to this log using the normal apache methods such as -Location_ blocks etc:

<pre>
	&lt;Location /cgi-bin&gt;
		SetEnv blackboxlog 1
	&lt;/Location&gt;

	&lt;IfModule mod_logio.c&gt;
		CustomLog "| /path/to/apacheblackbox.pl --output /var/www/blackbox.txt --detail --show \\'script.pl\\'"  "%a %X %t \"%r\" %s/%>s %{pid}P/%{tid}P %T/%D %I/%O/%B" env=blackboxlog
	&lt;/IfModule&gt;
</pre>

Combining the Apache control blocks with the options to this script such as _--skip_ and _--show_ gives you very fine grained control over what stats to record and can be used using the same basic script on many virtual hosts and sets of files on the same machine concurrently.

If you need to consider logs from several virtual hosts as one or simply wish to also store the log on your disk you can instruct the script to read the logfile from disk using the _--logfile_ option.  You would then make a CustomLog that save to a file and just run in the parser, when called with the _--logfile_ option it will daemonize to the background.  While we've not had stability problems with the script you may want to monitor it is running either through process list, via the _parser.generatedtime_ variable or the age of the output file.

CREDITS
=======

This is based on a basic concept found here: http://www.onlamp.com/pub/a/apache/2004/04/22/blackbox_logs.html

AUTHOR
======

Written by R.I.Pienaar, visit http://www.devco.net/ for more info.
