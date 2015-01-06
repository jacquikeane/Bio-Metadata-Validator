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

throws_ok { Bio::Metadata::Validator->new( config_file => 't/data/broken.conf' ) }
  qr/could not load configuration file/, 'exception on invalid config file';

my $config = read_file('t/data/broken.conf');
throws_ok { Bio::Metadata::Validator->new( config_string => $config ) }
  qr/could not load configuration from string/, 'exception on invalid config string';

# finally, load a valid configuration file and check we get the expected
# parameters from it
my $v;
lives_ok { $v = Bio::Metadata::Validator->new( config_file => 't/data/hicf.conf' ) }
  'no exception with valid config file';
is( $v->_config->{field}->[5]->{type}, 'Str', 'specified config sets correct type (Str) for scientific_name' );

# check the input file

throws_ok { $v->validate($nef) }
  qr/couldn't find the specified input file/, 'exception on missing input file';

# cache the ontology files
cache( 'http://purl.obolibrary.org/obo/subsets/envo-basic.obo', 'envo-basic.obo' );
cache( 'http://purl.obolibrary.org/obo/gaz.obo', 'gaz.obo' );
cache( 'http://www.brenda-enzymes.info/ontology/tissue/tree/update/update_files/BrendaTissueOBO', 'bto.obo' );

is( $v->validate('t/data/broken_manifest.csv'), 0, 'broken input file is invalid' );

is( $v->_validated_file_checksum, '71b6c7ba3f3dd236a3d48f439bf27673', 'checksum set' );

is( $v->valid, 0, '"valid" flag correctly shows 0' );
stdout_like( sub { $v->validation_report('t/data/broken_manifest.csv') }, qr/invalid/, 'report shows broken manifest as invalid' );
stdout_like( sub { $v->validation_report('t/data/broken_manifest.csv') }, qr/found 5 invalid rows/, 'report shows expected number of invalid rows' );

my $num_invalid_rows = scalar @{$v->invalid_rows};
is( $num_invalid_rows, 5, 'found expected number of invalid rows (5)' );

like( $v->all_rows->[2], qr/\['raw_data_accession' is a required field]$/, 'required field correctly flagged' );
like( $v->all_rows->[3], qr/\[at least one field out of 'tax_id'/, '"one_of" dependency correctly flagged' );
like( $v->all_rows->[4], qr/\[column 14 should not be completed if the 'host_associated' field is set to true]/, 'correctly flagged presence of both "then" and "else" fields' );
like( $v->all_rows->[5], qr/(\[column \d+ must be valid if the 'host_associated' field is set to true]\s*){3}$/, 'columns required through dependency correctly flagged' );
like( $v->all_rows->[6], qr/\[value in field 'sample_accession' is not valid\]/, 'invalid column flagged without description' );

# check the method to write out the validated rows

# first, write all rows
my $all_rows_fh  = File::Temp->new;
lives_ok { $v->write_validated_file( $all_rows_fh->filename ) } 'writes validated file ok';

my @all_rows = read_file( $all_rows_fh->filename );
is( scalar @all_rows, 8, 'output file has correct number of rows' );
unlike( $all_rows[1],  qr/\[.*?]$/, 'no error on row 1 of output file' );
like  ( $all_rows[2],  qr/\['raw_data_accession' is a required field]$/, 'required field correctly flagged in output file' );

# now, write just invalid rows
my $invalid_rows_fh = File::Temp->new;
is( $v->write_invalid, 0, '"write_invalid" starts false' );
lives_ok { $v->write_invalid(1) } 'no exception when setting "write_invalid" true';
is( $v->write_invalid, 1, '"write_invalid" set true' );
lives_ok { $v->write_validated_file( $all_rows_fh->filename ) } 'writes validated file ok';

my @invalid_rows = read_file( $all_rows_fh->filename );
is( scalar @invalid_rows, 5, 'output file has correct number of invalid rows' );
like( $invalid_rows[0],  qr/\['raw_data_accession' is a required field]$/, 'required field correctly flagged in output file with invalid rows' );

# check that we see column descriptions when "verbose_errors" is true
$invalid_rows_fh = File::Temp->new;
is( $v->verbose_errors, 0, '"write_invalid" starts false' );
lives_ok { $v->verbose_errors(1) } 'no exception when setting "write_invalid" true';
is( $v->verbose_errors, 1, '"write_invalid" set true' );
lives_ok { $v->validate( 't/data/broken_manifest.csv' ) } 'validates file with verbose error flag set true';
like( $v->all_rows->[6], qr/\[value in field 'sample_accession' is not valid\]/, 'invalid column flagged without description' );

# check everything works with a working config and manifest
ok( $v->validate('t/data/working_manifest.csv'), 'valid input file marked as valid' );

is( $v->valid, 1, '"valid" flag correctly shows 1' );
isnt( $v->_validated_file_checksum, '4e0ef99335fbb4bd619b551797c976cc', 'checksum reset' );

stdout_like( sub { $v->validation_report('t/data/working_manifest.csv') },
  qr/(?<!in)valid/, 'report shows valid manifest as valid' );

# get a new, clean object
$v = Bio::Metadata::Validator->new( config_file => 't/data/hicf.conf' );
throws_ok { Bio::Metadata::Validator->new( config_string => $config ) }
  qr/could not load configuration from string/, 'exception on invalid config string';
stdout_like( sub { $v->validation_report('t/data/working_manifest.csv') },
  qr/(?<!NOT )valid/, '"validation_report" works without validating first' );

done_testing();

