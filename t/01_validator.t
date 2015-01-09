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
  qr/you must supply either /, 'exception on missing configuration';

my $nef = "non-existent-file-$$";
throws_ok { Bio::Metadata::Validator->new( config_file => $nef ) }
  qr/could not find the specified configuration file/, 'exception on missing config file';

throws_ok { Bio::Metadata::Validator->new( config_file => 't/data/01_broken.conf' ) }
  qr/could not load configuration file/, 'exception on invalid config file';

my $config = read_file('t/data/01_broken.conf');
throws_ok { Bio::Metadata::Validator->new( config_string => $config ) }
  qr/could not load configuration from string/, 'exception on invalid config string';

# finally, load a valid configuration file

# start with a single config
my $v;
lives_ok { $v = Bio::Metadata::Validator->new( config_file => 't/data/01_single.conf' ) }
  'no exception with config file with a single config';
is( $v->_config->{field}->[0]->{type}, 'Bool', 'specified config sets correct type (Bool) for field' );

# and one with multiple configs
lives_ok { $v = Bio::Metadata::Validator->new( config_file => 't/data/01_multiple.conf', config_name => 'one' ) }
  'no exception with config file with multiple configs';
is( $v->_config->{field}->[0]->{type}, 'Str', 'specified config sets correct type (Str) for field' );

lives_ok { $v->config_name('two') } 'no exception when changing active config';
is( $v->_config->{field}->[0]->{type}, 'Int', 'new active config sets correct type (Int) for field' );

# check the input file

throws_ok { $v->validate($nef) }
  qr/couldn't find the specified input file/, 'exception on missing input file';

$v = Bio::Metadata::Validator->new( config_file => 't/data/01_single.conf' );

is( $v->validate('t/data/01_broken_manifest.csv'), 0, 'broken input file is invalid' );
is( $v->all_rows->[1] =~ tr/,/,/, 1, 'found a single separator on valid row' );
is( $v->all_rows->[2] =~ tr/,/,/, 2, 'found an extra separator on invalid row' );

is( $v->validated_file, 't/data/01_broken_manifest.csv', 'validated filename stored' );

is( $v->valid, 0, '"valid" flag correctly shows 0' );
stdout_like( sub { $v->validation_report('t/data/01_broken_manifest.csv') }, qr/invalid/, 'report shows broken manifest as invalid' );
stdout_like( sub { $v->validation_report('t/data/01_broken_manifest.csv') }, qr/Found 1 invalid row\./, 'report shows expected number of invalid rows' );

my $num_invalid_rows = scalar @{$v->invalid_rows};
is( $num_invalid_rows, 1, 'found expected number of invalid rows (1)' );

# check the method to write out the validated rows

# first, write all rows
my $all_rows_fh  = File::Temp->new;
lives_ok { $v->write_validated_file( $all_rows_fh->filename ) } 'writes validated file ok';

my @all_rows = read_file( $all_rows_fh->filename );
is( scalar @all_rows, 3, 'output file has correct number of rows' );
unlike( $all_rows[1],  qr/\[.*?]$/, 'no error on row 1 of output file' );
like  ( $all_rows[2],  qr/\[value in field 'one' is not valid]$/, 'invalid field correctly flagged in output file' );

# now, write just invalid rows
my $invalid_rows_fh = File::Temp->new;
is( $v->write_invalid, 0, '"write_invalid" starts false' );
lives_ok { $v->write_invalid(1) } 'no exception when setting "write_invalid" true';
is( $v->write_invalid, 1, '"write_invalid" set true' );
lives_ok { $v->write_validated_file( $all_rows_fh->filename ) } 'writes validated file ok';

my @invalid_rows = read_file( $all_rows_fh->filename );
is( scalar @invalid_rows, 1, 'output file has correct number of invalid rows' );
like( $invalid_rows[0],  qr/\[value in field 'one' is not valid]$/, 'invalid field correctly flagged in output file with invalid rows' );

# check that we see column descriptions when "verbose_errors" is true
$invalid_rows_fh = File::Temp->new;
is( $v->verbose_errors, 0, '"verbose_errors" starts false' );
lives_ok { $v->verbose_errors(1) } 'no exception when setting "verbose_errors" true';
is( $v->verbose_errors, 1, '"verbose_errors" set true' );
lives_ok { $v->validate( 't/data/01_broken_manifest.csv' ) } 'validates file with verbose error flag set true';
like( $v->all_rows->[2], qr/\[value in field 'one' is not valid; field description: 'Testing description'\]/, 'invalid column flagged without description' );

# make sure the validated filename is stored correctly
is( $v->validated_file, 't/data/01_broken_manifest.csv', 'filename stored' );

# check everything works with a working config and manifest
ok( $v->validate('t/data/01_working_manifest.csv'), 'valid input file marked as valid' );

is( $v->validated_file, 't/data/01_working_manifest.csv', 'new filename stored' );

stdout_like( sub { $v->validation_report('t/data/01_working_manifest.csv') },
  qr/(?<!in)valid/, 'report shows valid manifest as valid' );

# get a new, clean object to test calling validation_report without first calling validate
$v = Bio::Metadata::Validator->new( config_file => 't/data/01_multiple.conf',
                                    config_name => 'one' );

stdout_like( sub { $v->validation_report('t/data/01_working_manifest.csv') },
  qr/(?<!NOT )valid/, '"validation_report" works without validating first' );

# check optional/required fields
$v->config_name('required');
is( $v->validate('t/data/01_required.csv'), 0, 'error when correctly invalidating invalid CSV' );

  like( $v->all_rows->[1], qr/\[value in field 'two' is not valid]/, 'error with invalid required field' );
  like( $v->all_rows->[2], qr/\[value in field 'three' is not valid]/, 'error with invalid optional field' );
  like( $v->all_rows->[3], qr/\[field 'two' is a required field]/, 'error with empty required field' );
unlike( $v->all_rows->[4], qr/\[.*?]/, 'no error with empty optional field' );
unlike( $v->all_rows->[5], qr/\[.*?]/, 'no error with trailing empty fields' );

done_testing();

