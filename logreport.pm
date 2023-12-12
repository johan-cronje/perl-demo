#!/usr/bin/perl

use Moo;
use MooX::Options;
use 5.010;

=pod
 
=head1 NAME
 
logreport.pm - Script to analyze an Apache log file.

=head1 SYNOPSIS

perl logreport.pm --logfile APACHE_LOGFILE --geodb GEOLITE2_DATABASE
 
=head1 AUTHOR

Johan Cronje - johan@cronje.com

=head1 DESCRIPTION

This script analyzes an Apache access log file by doing a Geo lookup on the visitors IP address.
Statistics are produced for the number of visitors & the page requested most for each country, 
as well as each US state.

=cut

use LogFile qw(load top10_countries top10_us_states);

=head2 Command line switches

=over 12

=item C<logfile>

Path to an Apache access log file in Apache combined log format

=item C<geodb>

Path to a Maxmind GeoIP2 City database, e.g. I<GeoLite2-City.mmdb>

=back

=cut

option 'logfile' => (
    is => 'ro',
    format => 's',
    required => 1,
    doc => "name of logfile to process"
);

option 'geodb' => (
    is => 'ro',
    format => 's',
    required => 1,
    doc => "name of the Maxmind GeoIP2 City database"
);

=head2 Public Methods

=over

=item C<run>

Main execution point of the script. Controls loading the log file and producing the reports.

=back

=cut

sub run {
    my $self = shift;

    ## Instantiate LogFile object with required parameters
    my $log_obj = LogFile->new( logfile => $self->logfile, geodb => $self->geodb, limit => 0, debug => 1 );
    ## Process log file
    $log_obj->load;

    ### PRINT REPORTS ###
    $self->_global_report( $log_obj );
    $self->_us_report( $log_obj );

    return;
}

=head2 Private Methods

=over

=item C<_global_report>

Prints the top 10 countries with the most visitors in descending order

=over

=item B<Parameters:>

=over

=item C<log_obj>

Handle to a I<LogFile> object

=back

=back

=cut

sub _global_report {
    my $self = shift;
    my $log_obj = shift;

    ## Get array with top 10 countries
    my @top10_countries = $log_obj->top10_countries();

    ## Print top 10 countries with most visitors ##
    print "\nTop 10 Countries for visitors:\n\n";
    $self->_report_body( ["Country", "Visitors", "Most Visited Page"], \@top10_countries );

    return;
}

=item C<_us_report>

Prints the top 10 US states with the most visitors in descending order

=over

=item B<Parameters:>

=over

=item C<log_obj>

Handle to a I<LogFile> object

=back

=back

=cut

sub _us_report {
    my $self = shift;
    my $log_obj = shift;

    ## Get array with top 10 states
    my @top10_states = $log_obj->top10_us_states();
    # print Dumper(\@top10_states); $JDC

    ## Print top 10 US states with most visitors
    print "\n\nTop 10 US States for visitors:\n\n";
    $self->_report_body( ["State", "Visitors", "Most Visited Page"], \@top10_states );

    return;
}

=item C<_report_body>

Utility method to handle formatting & printing of report data

=over

=item B<Parameters:>

=over

=item C<header>

Array reference containing 3 column headings

=item C<data>

Array reference containing report data as returned by B<top10_countries> & B<top10_states> methods in I<LogFile> object

=back

=back

=cut


sub _report_body {
    my $self = shift;
    my $header = shift;
    my $data = shift;

    printf "%-15s %6s %-10s\n", $header->[0], $header->[1], $header->[2];
    printf "%s %s %s\n", "-" x 15, "-" x 8, "-" x 17;
    foreach my $item (@$data) {
        printf "%-15s %8d %s\n", $item->{location}, $item->{visitors}, $item->{top_page};
    }
    return;
}

=back

=cut

main->new_with_options->run;

1;