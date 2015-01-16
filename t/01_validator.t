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
is( scalar @{$manifest->rows->[1]}, 3, 'found three elements in invalid row (includes error message)' );

stdout_like( sub { $v->print_validation_report($manifest) }, qr/invalid/, 'report shows broken manifest as invalid' );
stdout_like( sub { $v->print_validation_report($manifest) }, qr/Found 1 invalid row\./, 'report shows expected number of invalid rows' );

# check that we see column descriptions when "verbose_errors" is true
is( $v->verbose_errors, 0, '"verbose_errors" starts false' );
lives_ok { $v->verbose_errors(1) } 'no exception when setting "verbose_errors" true';
is( $v->verbose_errors, 1, '"verbose_errors" set true' );

lives_ok { $v->validate($manifest) } 'validates file with verbose error flag set true';
$DB::single = 1;

#TODO-------------------------------------------------------------------------------
#TODO- terminally broken -----------------------------------------------------------
#TODO-------------------------------------------------------------------------------
#TODO check the validation errors in the "invalid_rows" slot in the manifest; there
#TODO are too many errors in there

like( $v->invalid_rows->[2], qr/\[value in field 'one' is not valid; field description: 'Testing description'\]/, 'invalid column flagged without description' );

# check everything works with a working config and manifest
ok( $v->validate_csv('t/data/01_working_manifest.csv'), 'valid input file marked as valid' );

is( $v->valid, 1, '"valid" flag correctly shows 1' );
is( $v->validated_file, 't/data/01_working_manifest.csv', 'new filename stored' );

stdout_like( sub { $v->print_validation_report }, qr/(?<!in)valid/, 'report shows valid manifest as valid' );

# validate a data structure

my $rows = [
  [ 1, 'two' ],
  [ 0, 'two' ],
];

ok( $v->validate_rows($rows), 'correctly validates rows' );
is( $v->validated_file, '', 'validated filename cleared' );
stdout_like( sub { $v->print_validation_report }, qr/(?<!in)valid/, 'report shows valid manifest as valid' );

push @$rows, [ 'a', 'two' ];
isnt( $v->validate_rows($rows), 1, 'correctly invalidates rows' );
like( $v->invalid_rows->[0]->[2], qr/\[value in field 'one' is not valid/, 'found error message in "invalid_rows"' );
stdout_like( sub { $v->print_validation_report }, qr/invalid/, 'report shows invalid manifest as invalid' );

done_testing();

