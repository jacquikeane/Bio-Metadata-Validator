#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::Metadata::Config;

use_ok('Bio::Metadata::Manifest');

my $m;
throws_ok { $m = Bio::Metadata::Manifest->new }
  qr/Attribute \(config\) is required/, 'exception when instantiating without a config';

my $config = Bio::Metadata::Config->new( config_file => 't/data/01_single.conf' );

lives_ok { $m = Bio::Metadata::Manifest->new( config => $config ) }
   'no exception when instantiating with a config';

$m->add_row( [ 1, 2 ] );
$m->add_invalid_row( [ 1, 2 ] );

is( $m->row_count, 1, 'starting with one row' );
is( $m->invalid_row_count, 1, 'starting with one invalid row' );
ok( $m->is_invalid, '"is_invalid" correctly shows false' );

$m->reset;

is( $m->row_count, 1, 'still one unvalidated row' );
is( $m->has_invalid_rows, 0, 'no invalid rows' );
isnt( $m->is_invalid, 1, '"is_invalid" correctly shows true' );

# not much more testing to be done here; the functionality of the class comes entirely
# from Moose.

done_testing();

