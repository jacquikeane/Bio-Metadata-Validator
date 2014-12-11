#!env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::Metadata::Validator;

# "if" relationships

my $v = Bio::Metadata::Validator->new( config_file => 't/data/broken_relationships.conf', project => 'hicf' );
throws_ok { $v->validate('t/data/relationships.csv') }
  qr/Fields with an 'if' dependency/, 'exception when validating against bad config ("if" column is not boolean)';

$v = Bio::Metadata::Validator->new( config_file => 't/data/relationships.conf', project => 'hicf' );
throws_ok { $v->validate('t/data/relationships.csv') }
  qr/ invalid rows? in input file/, 'exception on broken relationship input file';

like  ( $v->validated_csv->[1],  qr/\[column 1 .*?]$/, 'error with missing value for "if" true' );

unlike( $v->validated_csv->[2],  qr/\[column /, 'no error on valid row; "if" column true' );
like  ( $v->validated_csv->[3],  qr/\[column 2 .*? \[column 3 .*?]$/, 'two errors with two missing "if" dependencies' );
like  ( $v->validated_csv->[4],  qr/\[column 3 .*?]$/, 'error with one missing dependency' );
like  ( $v->validated_csv->[5],  qr/\[column 2 .*?]$/, 'error with other missing dependency' );

unlike( $v->validated_csv->[6],  qr/\[column /, 'no error on valid row; "if" column false' );
like  ( $v->validated_csv->[7],  qr/\[column 4 .*? \[column 5.*?]$/, 'two errors with two missing "if" dependencies' );
like  ( $v->validated_csv->[8],  qr/\[column 5 .*?]$/, 'error with "false" dependency value supplied when "if" is true' );
like  ( $v->validated_csv->[9],  qr/\[column 4 .*?]$/, 'error with other missing dependency' );

like  ( $v->validated_csv->[10], qr/\[column 4 should not be completed .*?]$/, 'one error with "false" dependency value supplied when "if" is true' );
like  ( $v->validated_csv->[11], qr/\[column 2 should not be completed .*?]$/, 'one error with "true" dependency value supplied when "if" is false' );

unlike( $v->validated_csv->[12], qr/\[column /, 'no error with valid second "if"; "if" column true' );
unlike( $v->validated_csv->[13], qr/\[column /, 'no error with valid second "if"; "if" column false' );
like  ( $v->validated_csv->[14], qr/\[column 7 .*| \[column 8.*?]$/, 'two errors with second "if" when dependency columns not correct' );

# "one_of" relationships

unlike( $v->validated_csv->[15], qr/\[exactly one field out of 'ten', 'eleven' should.*?]$/, 'no error when one column of "one-of" group is present' );
like  ( $v->validated_csv->[16], qr/\[exactly one field out of 'ten', 'eleven' should.*?]$/, 'error when two columns of a "one-of" group is present' );
like  ( $v->validated_csv->[17], qr/\[exactly one field out of 'twelve'.*?found 2.*?]$/, 'error when two columns of a three-column "one-of" group are present' );
like  ( $v->validated_csv->[18], qr/\[exactly one field out of 'twelve'.*?found 3.*?]$/, 'error when three columns of a three-column "one-of" group are present' );

# "some_of" relationships

like  ( $v->validated_csv->[19], qr/\[at least one field out of 'eighteen'.*?]$/, 'error when no columns in a three-column "some-of" group are found' );

# make sure that we're checking for the presence of a value in a field, rather than
# always a *valid* value
like  ( $v->validated_csv->[20], qr/\[value in field 'twelve' is not a valid Int] \[exactly one field out of 'twelve'.*?found 2/, 'error when two columns in a three-column "one-of" group are found, one valid, one invalid' );

done_testing();

