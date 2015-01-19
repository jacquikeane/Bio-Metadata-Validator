#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use File::Slurp;
use Test::Output;
use Test::CacheFile;
use File::Temp;

use_ok('Bio::Metadata::Validator');

# check the configuration file/string

throws_ok { Bio::Metadata::Validator->new() }
  qr/Attribute \(config\) is required /, 'exception on missing configuration file';

throws_ok { Bio::Metadata::Validator->new( config => {} ) }
  qr/Attribute \(config\) does not pass the type constraint/,
  'exception on missing config file';

# finally, load a valid configuration

# start with a single config
my $config = Bio::Metadata::Config->new( config_file => 't/data/01_single.conf' );
my $v;
lives_ok { $v = Bio::Metadata::Validator->new( config => $config ) }
  'no exception with config file with a single config';

is( $v->config->config->{field}->[0]->{type}, 'Bool', 'specified config sets correct type (Bool) for field' );

# validating input CSV files

throws_ok { $v->validate } qr/must supply a Bio::Metadata::Manifest/,
  'exception when calling "validate" without a manifest';

# check an input file

my $reader = Bio::Metadata::Reader->new( config => $config );
my $manifest = $reader->read_csv('t/data/01_broken_manifest.csv');

is( $v->validate($manifest), 0, 'broken input file is invalid' );

is( scalar @{$manifest->rows},         2, 'found expected number of rows in "all_rows" (2)' );
is( scalar @{$manifest->invalid_rows}, 1, 'found expected number of invalid rows in "invalid_rows" (1)' );

is( scalar @{$manifest->rows->[0]}, 2, 'found two elements in valid row' );
is( scalar @{$manifest->invalid_rows->[0]}, 3, 'found three elements in invalid row (includes error message)' );

stdout_like( sub { $v->print_validation_report($manifest) }, qr/invalid/, 'report shows broken manifest as invalid' );
stdout_like( sub { $v->print_validation_report($manifest) }, qr/Found 1 invalid row\./, 'report shows expected number of invalid rows' );

# check that we see column descriptions when "verbose_errors" is true
is( $v->verbose_errors, 0, '"verbose_errors" starts false' );
lives_ok { $v->verbose_errors(1) } 'no exception when setting "verbose_errors" true';
is( $v->verbose_errors, 1, '"verbose_errors" set true' );

is( $manifest->is_invalid, 1, 'manifest "is_invalid" flag correctly shows 1' );

lives_ok { $v->validate($manifest) } 'validates file with verbose error flag set true';

like( $manifest->invalid_rows->[0]->[2], qr/^\[errors found on row 2\]/, 'flags errors on row 2' );
like( $manifest->invalid_rows->[0]->[2], qr/\[value in field 'one' is not valid; field description: 'Testing description'\]/, 'invalid column flagged without description' );

# check everything works with a working config and manifest
$manifest = $reader->read_csv('t/data/01_working_manifest.csv');
ok( $v->validate($manifest), 'valid input file marked as valid' );

is( $manifest->is_invalid, 0, 'manifest "is_invalid" flag correctly shows 0' );

stdout_like( sub { $v->print_validation_report($manifest) }, qr/(?<!in)valid/, 'report shows valid manifest as valid' );

done_testing();

