package LogFile;

use Moo;
use Carp qw(croak);
use GeoIP2::Database::Reader;

use LogLine qw(parse);

=pod
 
=head1 NAME
 
LogFile.pm - Module to load & process Apache access log files

=head1 SYNOPSIS

my $log_obj = LogFile->new( logfile => LOGFILE, geodb => GEODB );
$log_obj->load;

$self->_global_report( $log_obj );
$self->_us_report( $log_obj );
 
=head1 AUTHOR

Johan Cronje - johan@cronje.com

=head1 DESCRIPTION

This module provides methods to load, analyze an Apache access log. In addition methods are provided to 
calculate statistics for the number of visitors & the page requested most for each country or US state.

=head2 Attributes

=over 12

=item C<logfile>

Path to an Apache access log file in Apache combined log format

=item C<geodb>

Path to a Maxmind GeoIP2 City database, e.g. I<GeoLite2-City.mmdb>

=item C<limit>

I<For testing purposes.> Limit processing file to a certain number of results. Defaults to 0 for all lines in log file.

=item C<debug>

I<For testing purposes.> Output information to assist debugging. 1=On/0=Off. Defaults to 0.

=back

=cut

has logfile => (
    is => 'ro',
    required => 1,
    isa => sub { croak 'Invalid log file' unless -f $_[0] },
);

has geodb => (
    is => 'ro',
    required => 1,
    isa => sub { croak 'Invalid GeoIP2 database' unless -f $_[0] },
);

has limit => (
    is => 'ro',
    default => 0,
);

has debug => (
    is => 'rw',
    default => 0,
);

my $global_stats; ## Hashref to store global stats
my $usa_stats; ## Hashref to store US stats

=head2 Public Methods

=over

=item C<load>

Opens & loads Apache log file. Also processes log file to calculate statistics uses in report methods.
This method has to be called before any other methods are used.

=cut

sub load {
    my $self = shift;

    ## Start GeoIP2 Reader
    $self->{reader} = GeoIP2::Database::Reader->new(
        file    => $self->geodb,
        locales => [ 'en' ]
    );

    # Open logfile for readind
    open( my $fh, '<', $self->logfile )
        or die "Can't open '", $self->logfile, "' $!";

    my %lines = ( processed => 0, total => 0, ignored => 0, nogeo => 0); ## hash to hold load stats

    ## Read in line at a time
    while (my $line = <$fh>) {
        chomp $line;

        $lines{total}++; ## Count total lines loaded
        if ( $self->debug ) {
            print $lines{total},"\n" unless $lines{total} % 1000; ## Show progress every 1000 lines
        }
        
        ## Load & parse the line using the LogLine class
        my $line_obj = LogLine->new( logline => $line );
        $line_obj->parse;

        ## Trap blank URLs
        my $url = $line_obj->url || 'unknown';

        ## Ignore all requests for images, CSS, JavaScript and paths ending in .rss or .atom
        unless ( $self->_valid_page( $url ) ) {
            $lines{ignored}++; ## Count total lines ignored
            next;
        }

        ## Get Geo data from database
        my ($city_mod, $country_name, $country_iso2 ) = $self->_geo_lookup( $line_obj->ip );
        unless ( defined $city_mod ) { ## Ignore row if we have no Geo data
            $lines{nogeo}++; ## Count total lines with no IP lookup
            next;
        }

        ## Gather stats for log line

        ## Count visitors by country
        $global_stats->{$country_name}->{visitors}++;
        ## Count page visitors by country
        $global_stats->{$country_name}->{pages}->{$url}->{visitors}++;

        ## Collect state data for US
        if( $country_iso2 eq 'US' ) {
            my $state_name = $city_mod->most_specific_subdivision()->name() || 'unknown';
            ## Count visitors by state
            $usa_stats->{$state_name}->{visitors}++;
            ## Count page visitors by state
            $usa_stats->{$state_name}->{pages}->{$url}->{visitors}++;
        }

        $lines{processed}++; ## Count lines processed
        ## End processing if limit attribute is set
        last if $lines{processed} - $self->limit == 0;
    }
    close( $fh );
    
    printf "%d/%d lines processed (%d Ignored, %d Failed Geo Lookup)\n", $lines{processed}, $lines{total}, $lines{ignored}, $lines{nogeo}
        if $self->debug;

    return;
}

=item C<top10_countries>

Calculates the top 10 countries with the most visitors and the page with the most visits (excluding the root '/').

=over

=item B<Returns:>

Array of hashrefs in the format [{location => COUNTRY, visitors => VISITORS, top_page => URL},{...},{...}].

=back

=cut

sub top10_countries {
    my $self = shift;
    return $self->_top10_locations( $global_stats );
}

=item C<top10_us_states>

Calculates the top 10 US states with the most visitors and the page with the most visits (excluding the root '/').

=over

=item B<Returns:>

Array of hashrefs in the format [{location => STATE, visitors => VISITORS, top_page => URL},{...},{...}].

=back

=back

=cut

sub top10_us_states {
    my $self = shift;
    return $self->_top10_locations( $usa_stats );
}

=head2 Private Methods

=over

=item C<_valid_page>

Utility method to ensure a provided URL points to a valid page, ignoring all requests for images, CSS, JavaScript & more

=over

=item B<Parameters:>

=over

=item C<url>

The URL contained in a Apache access log line

=back

=back

=over

=item B<Returns:>

B<TRUE> for a valid URL, B<FALSE> for an invalid URL

=back

=cut

sub _valid_page {
    my $self = shift;
    my $url = shift;

    return not $url =~ m"(/[a-f0-9]+/css/|/[a-f0-9]+/images/|/[a-f0-9]+/js/|/entry-images/|/images/|/user-images/|/static/|/robots\.txt|/favicon\.ico|.rss$|.atom$)";
}

=item C<_geo_lookup>

Utulity method to perform a Geo lookup on a provided IP adress

=over

=item B<Parameters:>

=over

=item C<ip>

Valid IP address, e.g. 207.46.13.94

=back

=back

=over

=item B<Returns:>

Array containing ( I<GeoIP2::Model::City> object, COUNTRY_NAME, COUNTRY_ISO2_CODE )

=back

=cut

sub _geo_lookup {
    my $self = shift;
    my $ip = shift;

    my $city_mod;

    ## Get Geo data from database
    eval {
        $city_mod = $self->{reader}->city( ip => $ip ); # Get GeoIP2::Model::City object
    };
    return undef unless defined $city_mod; ## Fail if no location found

    my $city_rec = $city_mod->city(); ## Get GeoIP2::Record::City object
    my $country_rec = $city_mod->country(); ## Get GeoIP2::Record::Country object

    ## Get city & country names or 'unknown' if not available
    my $country_name = $country_rec->name() || 'unknown';
    my $country_iso2 = $country_rec->iso_code || 'unknown';

    return ( $city_mod, $country_name, $country_iso2 );
}

=item C<_top10_locations>

Utility method to calculate the top 10 locations with the most visitors.

=over

=item B<Parameters:>

=over

=item C<stats>

Hashref containing data calculated by the public B<load> method.

=back

=back

=over

=item B<Returns:>

Array of hashrefs in the format [{location => LOCATION, visitors => VISITORS, top_page => URL},{...},{...}]

=back

=cut

sub _top10_locations {
    my $self = shift;
    my $stats = shift;

    my @locations;

    ## Sort hash by the number of visitors from each location (DESC), then by the location name (ASC)
    ## into an array of ordered hash keys
    my @visits = sort {
        $stats->{$b}->{visitors} <=> $stats->{$a}->{visitors}
        or
        lc($stats->{$a}) cmp lc($stats->{$b})
    } keys %$stats;

    ## Create an array containing the top 10 locations with the most visitors
    ## by using the first 10 keys in the array created in the previous step
    my $cnt = 0;
    foreach my $k (@visits) {
        ## For the current location, get the page requested most often
        my $top_page = $self->_top_page( $stats->{$k}->{pages} );

        ## Add hashrefs to the array to be returned
        push @locations, { location => $k, visitors => $stats->{$k}->{visitors}, top_page => $top_page->{url} };
        $cnt++;
        last if $cnt >= 10;
    }
    return @locations;
}

=item C<_top_page>

Utility method to calculate the most frequently requested URL for a location

=over

=item B<Parameters:>

=over

=item C<pages>

Hashref containing data calculated by the public B<load> method. Specifically the B<$hash->{location}->{pages}> element.

=back

=back

=over

=item B<Returns:>

Hashref in the format {url => URL, visitors => VISITORS}

=back

=cut

sub _top_page {
    my $self = shift;
    my $pages = shift;

    my $page;

    ## Sort hash by the number of visitors to each page (DESC), then by the page name (ASC)
    ## into an array of ordered hash keys
    my @pages = sort {
        $pages->{$b}->{visitors} <=> $pages->{$a}->{visitors}
        or
        $pages->{$a} <=> $pages->{$b}
    } keys %$pages;

    ## Create a hashref with the first page (that is not root '/') 
    ## by using the array created in the previous step
    foreach my $k (@pages) {
        next if $k eq '/';
        $page = { url => $k, visitors=> $pages->{$k}->{visitors} };
        last;
    }

    ## If there are no pages other than '/', set page to 'none'
    $page = { url => 'none', visitors => 0 } unless $page;

    return $page;
}

=back

=cut

1;