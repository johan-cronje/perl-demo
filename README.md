# README #

Script to test Maxmind geo lookup on an Apache access log.

## Running the solution ##

`perl logreport.pm --logfile [Path to Apache access log] --geodb [Path to GeoLite2 database]`

for example:

`perl logreport.pm --logfile access.log --geodb GeoLite2-City.mmdb`

For detailed documentation use perldoc:

`perldoc logreport.pm`
`perldoc LogFile.pm`
`perldoc LogLine.pm`

## Setup ##

* ### Dependencies ###

    Install required perl modules using cpan or cpanm:

    + Moo
    + MooX::Options
    + Carp
    + GeoIP2::Database::Reader

## Design Overview ##

* ###LogFile###

    Loads & processes the log file. It also provides utility methods to extract the required statistics.

    #### ATTRIBUTES: ####
    | | |
    |-|-|
    | logfile | Path to Apache log in combined format to process |
    | geodb | Path to MaxMind GeoIP2 City database |
    | limit | Stop after n results |
    | debug | Display progress & statistics |

    #### METHODS: ####
    | | | |
    |-|-|-|
    | load | PUBLIC | Load and process log file |
    | top10_countries | PUBLIC | Returns sorted array of hashref elements containing top 10 countries with most visitors |
    | top10_us_states | PUBLIC | Returns sorted array of hashref elements containing top 10 US states with most visitors |
    | _valid_page | PRIVATE | Tests if a supplied URL should be ignored |
    | _geo_lookup | PRIVATE | Do a Geo lookup on a supplied IP address |
    | _top10_locations | PRIVATE | Utility function for the top10_countries & top10_us_states methods. Determines top 10 countries with most visitors |
    | _top_page | PRIVATE | Utility function for the top10_countries & top10_us_states methods. Determines URL with the most visitors |
 
* ###LogLine###

    Parses log lines

    #### ATTRIBUTES: ####
    | | |
    |-|-|
    | logline | Required attribute containing log line to be parsed |
    | ip | Remote IP address |
    | time | Time the request was received |
    | method | HTTP method |
    | url | URL path requested |
    | protocol | Request protocol |
    | code | Status |
    | bytes | Size of response in bytes, excluding HTTP headers |
    | referrer | Referer |
    | ua| User agent |

    #### METHODS: ####
    | | | |
    |-|-|-|
    | parse | PUBLIC | Parses the log line passed during instantiation |
    