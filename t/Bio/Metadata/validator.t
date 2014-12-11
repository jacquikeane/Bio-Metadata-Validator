#!env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use File::Slurp;

use_ok('Bio::Metadata::Validator');

# check the configuration file/string

throws_ok { Bio::Metadata::Validator->new( project => 'hicf' ) }
  qr/You must supply either /, 'exception on missing configuration';

my $nef = "non-existent-file-$$";
throws_ok { Bio::Metadata::Validator->new( config_file => $nef, project => 'hicf' ) }
  qr/Could not find the specified configuration file/, 'exception on missing config file';

throws_ok { Bio::Metadata::Validator->new( config_file => 't/data/broken.conf', project => 'hicf' ) }
  qr/Could not load configuration file/, 'exception on invalid config file';

my $config = read_file('t/data/broken.conf');
throws_ok { Bio::Metadata::Validator->new( config_string => $config, project => 'hicf' ) }
  qr/Could not load configuration from string/, 'exception on invalid config string';

# finally, load a valid configuration file and check we get the expected
# parameters from it
my $v;
lives_ok { $v = Bio::Metadata::Validator->new( config_file => 't/data/hicf.conf', project => 'hicf' ) }
  'no exception with valid config file';
is( $v->_config->{field}->[5]->{type}, 'Str', 'specified config sets correct type (Str) for scientific_name' );

# check the input file

throws_ok { $v->validate($nef) }
  qr/Could not find the specified input file/, 'exception on missing input file';

SKIP: {
  skip 'slow tests (set $ENV{RUN_SLOW_TESTS} to true to run)', 1
    if ( not defined $ENV{RUN_SLOW_TESTS} or not $ENV{RUN_SLOW_TESTS} );

  throws_ok { $v->validate('t/data/broken_manifest.csv') }
    qr/Found 5 invalid rows in input file/, 'exception on broken input file';

  like  ( $v->validated_csv->[2],  qr/\['raw_data_accession' is a required field]$/, 'required field correctly flagged' );
  like  ( $v->validated_csv->[3],  qr/\[value in field 'raw_data_accession' is not a valid 'raw data accession']$/, 'invalid column type correctly flagged' );
  like  ( $v->validated_csv->[4],  qr/\[at least one field out of 'tax_id'/, '"one_of" dependency correctly flagged' );
  like  ( $v->validated_csv->[5],  qr/\[column 14 should not be completed if the 'host_associated' field is set to true]/, 'correctly flagged presence of both "then" and "else" fields' );
  like  ( $v->validated_csv->[6],  qr/(\[column \d+ must be valid if the 'host_associated' field is set to true]\s*){3}$/, 'columns required through dependency correctly flagged' );

  lives_ok { $v->validate('t/data/working_manifest.csv') } 'no exception with valid input file';
}

done_testing();

