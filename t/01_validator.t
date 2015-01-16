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
  qr/Attribute \(config_file\) is required /, 'exception on missing configuration file';

my $nef = "non-existent-file-$$";
throws_ok { Bio::Metadata::Validator->new( config_file => $nef, config_name => 'dummy' ) }
  qr/could not find the specified configuration file/, 'exception on missing config file';

throws_ok { Bio::Metadata::Validator->new( config_file => 't/data/01_broken.conf', config_name => 'broken' ) }
  qr/could not load configuration file/, 'exception on invalid config file';

# finally, load a valid configuration file

# start with a single config
my $v;
lives_ok { $v = Bio::Metadata::Validator->new( config_file => 't/data/01_single.conf', config_name => 'one' ) }
  'no exception with config file with a single config';
is( $v->config->{field}->[0]->{type}, 'Bool', 'specified config sets correct type (Bool) for field' );

# specify a config but not a name
lives_ok { $v = Bio::Metadata::Validator->new( config_file => 't/data/01_single.conf' ) }
  'no exception on instantiating with a config file but no name';

is( $v->config->{field}->[0]->{name}, 'one', 'config loaded' );

# and one with multiple configs
lives_ok { $v = Bio::Metadata::Validator->new( config_file => 't/data/01_multiple.conf', config_name => 'one' ) }
  'no exception with config file with multiple configs';
is( $v->config->{field}->[0]->{type}, 'Str', 'specified config sets correct type (Str) for field' );

lives_ok { $v->config_name('two') } 'no exception when changing active config';
is( $v->config->{field}->[0]->{type}, 'Int', 'new active config sets correct type (Int) for field' );

# validating input CSV files

# first, check that the "print_validation_report" method throws an exception
# when we call it before having validated anything

throws_ok { $v->print_validation_report } qr/nothing validated yet/,
  'exception from "print_validation_report" before validating anything';

# check an input file

throws_ok { $v->validate_csv($nef) }
  qr/couldn't find the specified input file/, 'exception on missing input file';

$v = Bio::Metadata::Validator->new( config_file => 't/data/01_single.conf', config_name => 'one' );

is( $v->validate_csv('t/data/01_broken_manifest.csv'), 0, 'broken input file is invalid' );

is( $v->valid, 0, '"valid" flag correctly shows 0' );
is( scalar @{$v->all_rows},     3, 'found expected number of rows in "all_rows" (3)' );
is( scalar @{$v->invalid_rows}, 1, 'found expected number of invalid rows in "invalid_rows" (1)' );

is( $v->all_rows->[1] =~ tr/,/,/, 1, 'found a single separator on valid row' );
is( $v->all_rows->[2] =~ tr/,/,/, 2, 'found an extra separator on invalid row' );

is( $v->validated_file, 't/data/01_broken_manifest.csv', 'validated filename stored' );

stdout_like( sub { $v->print_validation_report }, qr/invalid/, 'report shows broken manifest as invalid' );
stdout_like( sub { $v->print_validation_report }, qr/Found 1 invalid row\./, 'report shows expected number of invalid rows' );

# check that we see column descriptions when "verbose_errors" is true
is( $v->verbose_errors, 0, '"verbose_errors" starts false' );
lives_ok { $v->verbose_errors(1) } 'no exception when setting "verbose_errors" true';
is( $v->verbose_errors, 1, '"verbose_errors" set true' );
lives_ok { $v->validate_csv( 't/data/01_broken_manifest.csv' ) } 'validates file with verbose error flag set true';
like( $v->all_rows->[2], qr/\[value in field 'one' is not valid; field description: 'Testing description'\]/, 'invalid column flagged without description' );

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

