#!env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use_ok('Bio::Metadata::Validator');

# try loading non-existent files
my $nef = "non-existent-file-$$";

# check the configuration file

throws_ok { Bio::Metadata::Validator->new( config_file => $nef, project => 'hicf' ) }
  qr/Could not find the specified configuration file/, 'exception on missing config file';

# try a broken configuration
throws_ok { Bio::Metadata::Validator->new( config_file => 't/data/broken.conf', project => 'hicf' ) }
  qr/Could not load configuration file/, 'exception on invalid config file';

# finally, load a valid configuration file and check we get the expected
# parameters from it
my $v = Bio::Metadata::Validator->new( config_file => 't/data/hicf.conf', project => 'hicf' );
is( $v->_config->{field}->[5]->{type}, 'Str', 'specified config sets correct type (Str) for scientific_name' );

# check the input file

throws_ok { $v->validate($nef) }
  qr/Could not find the specified input file/, 'exception on missing input file';

SKIP: {
  skip 'slow tests (set $ENV{RUN_SLOW_TESTS} to true to run)', 1
    if not defined $ENV{RUN_SLOW_TESTS};

  throws_ok { $v->validate('t/data/broken_manifest.csv') }
    qr/Found 1 invalid row in input file/, 'exception on broken input file';
}

# check relationships

$v = Bio::Metadata::Validator->new( config_file => 't/data/relationships.conf', project => 'hicf' );

throws_ok { $v->validate('t/data/relationships.csv') }
  qr/ invalid row?(s) in input file/, 'exception on broken relationship input file';

diag( "testing 'if' relationships" );

  like( $v->validated_csv->[1],  qr/\[column 1 /, 'error with missing value for "if" true' );

unlike( $v->validated_csv->[2],  qr/\[column /, 'no error on valid row; "if" column true' );
  like( $v->validated_csv->[3],  qr/\[column 2 .*? \[column 3/, 'two errors with two missing "if" dependencies' );
  like( $v->validated_csv->[4],  qr/\[column 3 /, 'error with one missing dependency' );
  like( $v->validated_csv->[5],  qr/\[column 2 /, 'error with other missing dependency' );

unlike( $v->validated_csv->[6],  qr/\[column /, 'no error on valid row; "if" column false' );
  like( $v->validated_csv->[7],  qr/\[column 4 .*? \[column 5/, 'two errors with two missing "if" dependencies' );
  like( $v->validated_csv->[8],  qr/\[column 5 /, 'error with "false" dependency value supplied when "if" is true' );
  like( $v->validated_csv->[9],  qr/\[column 4 /, 'error with other missing dependency' );

  like( $v->validated_csv->[10], qr/\[column 4 should not be completed /, 'one error with "false" dependency value supplied when "if" is true' );
  like( $v->validated_csv->[11], qr/\[column 2 should not be completed /, 'one error with "true" dependency value supplied when "if" is false' );

unlike( $v->validated_csv->[12], qr/\[column /, 'no error with valid second "if"; "if" column true' );
unlike( $v->validated_csv->[13], qr/\[column /, 'no error with valid second "if"; "if" column false' );
  like( $v->validated_csv->[14], qr/\[column 7 .*| \[column 8/, 'two errors with second "if" when dependency columns not correct' );

#   like( $v->validated_csv->[12], qr/either column 6 or column 7/, 'one error when both "either" and "or" columns valid' );
#   like( $v->validated_csv->[13], qr/one of column 6 or column 7/, 'one error when neither "either" or "or" columns is valid' );
# unlike( $v->validated_csv->[14], qr/\[column /, 'no error when one column of "either-or" pair valid' );
# unlike( $v->validated_csv->[15], qr/\[column /, 'no error when other column of "either-or" pair valid' );

done_testing();

