package LogLine;

use Moo;
use Carp qw(croak);

=pod
 
=head1 NAME
 
LogLine.pm - Module to parse a line from an Apache access log files

=head1 SYNOPSIS

my $line_obj = LogLine->new( logline => LINE );
$line_obj->parse;
my $url = $line_obj->url;

=head1 AUTHOR

Johan Cronje - johan@cronje.com

=head1 DESCRIPTION

This module provides a method to parse a line from an Apache access log into several
attributes coresponding to the data columns in the log file.

LogFormat 

C<"%h %l %u %t \"%r\" %>s %b \"%{Referer}i\" \"%{User-agent}i\"">

as defined in L<http://httpd.apache.org/docs/current/mod/mod_log_config.html>

=head2 Attributes

=over 12

=item C<logline>

String containing a line from an Apache access log file in Apache combined log format

=back

=cut

has logline => (
    is => 'ro',
    required => 1,
);

## Labels for extracted data
my @cols = qw(ip time method url protocol code bytes referrer ua);

## Quick way to create attributes from the @cols array
has $_ => ( is => 'rw' ) for (@cols);

=head2 Public Methods

=over

=item C<parse>

Parse log line into components. Set attribute value for each component.

=cut

sub parse {
    my $self = shift;

    my %val; ## Hash to hold grep results

    ## Credit to stackoverflow.com for regex
    ($val{ip},
     $val{time},
     $val{method},
     $val{url},
     $val{protocol},
     $val{alt_url},
     $val{code},
     $val{bytes},
     $val{referrer},
     $val{ua}) = $self->logline =~
        m/
            ^(\S+)\s                    # remote hostname (ip)
            \S+\s+                      # remote logname (-)
            (?:\S+\s+)+                 # remote user (-)
            \[([^]]+)\]\s               # time (time)
            "(\S*)\s?                   # method (method)
            (?:((?:[^"]*(?:\\")?)*)\s   # URL (url)
            ([^"]*)"\s|                 # protocol (protocol)
            ((?:[^"]*(?:\\")?)*)"\s)    # or, URL with no protocol (alt_url)
            (\S+)\s                     # status code (code)
            (\S+)\s                     # response size (bytes)
            "((?:[^"]*(?:\\")?)*)"\s    # referrer (referrer)
            "(.*)"$                     # user agent (ua)
        /x;
    croak "Couldn't match $_" unless $val{ip};
    $val{alt_url} ||= '';
    $val{url} ||= $val{alt_url};

    ## Set all attribute values
    $self->$_($val{$_}) for (@cols);

    return 1;
}

=back

=cut

1;
