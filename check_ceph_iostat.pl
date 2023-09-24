#!/usr/bin/perl

# (c) 2023 TAFEU GmbH www.tafeu.de
# ceph io stats monitoring / performance data for nagios
#
# v0.1 2023-09-20
# - quick development for ceph version 16.2.13 pacific (stable)
#
# TODO?: warn/crit
# TODO?: monitorg $statusdata->{'pgmap'}->{'data_bytes'}, bytes_used, num_objects..

use warnings;
use strict;
use Monitoring::Plugin;
use JSON;
#use Data::Dumper;
use Number::Bytes::Human;
use Try::Tiny;

my $np = Monitoring::Plugin->new( shortname => "CEPH_IO" );

$np = Monitoring::Plugin->new(
  usage => "Usage: %s [ -h ] [ -e|--exe <CEPH EXE> ] [ -c|--critical=<threshold> ] [ -w|--warning=<threshold> ]",
  version => '0.1'
);

$np->add_arg(
  spec => 'exe|e=s',
  help => q(Path to ceph binary),
  required => 1,
  default => '/usr/bin/ceph'
);

$np->add_arg(
  spec => 'id|i=s',
  help => q(ceph client id),
  required => 1,
  default => 'nagios'
);

$np->add_arg(
  spec => 'keyring|k=s',
  help => q(ceph client keyring file),
  required => 1,
  default => '/var/lib/nagios/ceph.client.nagios.keyring'
);

$np->getopts;

if (! -x $np->opts->get('exe')) {
   $np->plugin_exit( UNKNOWN, "ceph binary is not executable. missing?" );
}

if (! -r $np->opts->get('keyring')) {
   $np->plugin_exit( UNKNOWN, "ceph client keyring file missing or unable to read" );
}


open(my $fh, $np->opts->get('exe')." status -f json --id ".$np->opts->get('id')." --keyring ".$np->opts->get('keyring')." |") or $np->plugin_exit( UNKNOWN, "unable to execute ceph binary");
my $json = do { local $/; <$fh> };
close ($fh);

my $statusdata = '';
try {
  $statusdata = JSON->new->utf8->decode($json);
} catch {
  $np->plugin_exit( UNKNOWN, "could not read json: $json");
};

if ($statusdata) {
    #foreach ( 'write_bytes_sec', 'read_bytes_sec', 'write_op_per_sec', 'read_op_per_sec' ) {  print "$_", " => ", $statusdata->{'pgmap'}->{$_}, "\n"; } print "\n";
    #print Dumper($statusdata->{'pgmap'});

    my $human = Number::Bytes::Human->new(bs => 1024, si => 1,
          suffixes => [' B', ' KiB', ' MiB', ' GiB', ' TiB', ' PiB', ' EiB', ' ZiB', ' YiB']); # to have space after the number

    my $iostatline = $human->format( $statusdata->{'pgmap'}->{'read_bytes_sec'}). '/s rd, '.
                $human->format( $statusdata->{'pgmap'}->{'write_bytes_sec'}). '/s wr, '.
                $statusdata->{'pgmap'}->{'read_op_per_sec'}. ' op/s rd, '.
                $statusdata->{'pgmap'}->{'write_op_per_sec'}. ' op/s wr';
    # json is missing keys if we have a longer time values of 0 for a key, ex read_bytes_sec
    #if ( defined($statusdata->{'pgmap'}->{'read_bytes_sec'}) && defined($statusdata->{'pgmap'}->{'write_bytes_sec'}) && defined($statusdata->{'pgmap'}->{'read_op_per_sec'}) && defined($statusdata->{'pgmap'}->{'write_op_per_sec'}) ) {
    if (defined($statusdata->{'pgmap'})) {
        $np->add_perfdata( label => "rd", value => $statusdata->{'pgmap'}->{'read_bytes_sec'}, uom => "Bytes" );
        $np->add_perfdata( label => "wr", value => $statusdata->{'pgmap'}->{'write_bytes_sec'}, uom => "Bytes" );
        $np->add_perfdata( label => "read iops", value => $statusdata->{'pgmap'}->{'read_op_per_sec'} );
        $np->add_perfdata( label => "write iops", value => $statusdata->{'pgmap'}->{'write_op_per_sec'} );

        $np->plugin_exit( OK, $iostatline);
   }
   $np->plugin_exit( UNKNOWN, "unexpected output, iostatline: $statusdata->{'pgmap'}");
}

$np->plugin_exit( UNKNOWN, "unexpected output, iostatline: $json");
