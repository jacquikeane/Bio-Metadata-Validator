#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use File::Temp;
use File::Slurp qw( read_file );

use Bio::Metadata::Config;

use_ok('Bio::Metadata::Manifest');

my $m;
throws_ok { $m = Bio::Metadata::Manifest->new }
  qr/Attribute \(config\) is required/, 'exception when instantiating without a config';

my $config = Bio::Metadata::Config->new( config_file => 't/data/01_single.conf' );

lives_ok { $m = Bio::Metadata::Manifest->new( config => $config ) }
   'no exception when instantiating with a config';

$m->add_row( [ 1, 2 ] );
$m->add_row( [ 3, 4 ] );
$m->set_invalid_row( 1, [ 3, 4, '[error message]' ] );

is( $m->row_count, 2, 'starting with two rows' );
is( $m->invalid_row_count, 1, 'starting with one invalid row' );
ok( $m->is_invalid, '"is_invalid" correctly shows false' );

my $fh = File::Temp->new;
$fh->close;

diag 'writing rows to ' . $fh->filename;

$m->write_csv( $fh->filename );

my $file_contents = read_file( $fh->filename );

my $expected_contents = <<EOF;
one,two
1,2
3,4 [error message]
EOF

is( $file_contents, $expected_contents, 'output file is correct' );

$m->reset;

is( $m->row_count, 2, 'still two rows' );
is( $m->has_invalid_rows, 0, 'no invalid rows' );
is( $m->is_invalid, 0, '"is_invalid" correctly shows false' );

done_testing();

