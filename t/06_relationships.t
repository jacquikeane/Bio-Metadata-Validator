#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::Metadata::Validator;

# test a bad config
my $c = Bio::Metadata::Config->new( config_file => 't/data/06_relationships.conf',
                                    config_name => 'broken' );
my $r = Bio::Metadata::Reader->new( config => $c );
my $v = Bio::Metadata::Validator->new;
my $m = $r->read_csv('t/data/06_if.csv');

throws_ok { $v->validate($m) }
  qr/fields with an 'if' dependency/, 'exception when validating against bad config ("if" field is not boolean)';

# "if" relationships
$c->config_name('if');
is( $v->validate($m), 0, 'broken "if" relationship input file marked as invalid' );
is( $m->invalid_row_count, 10, 'got expected number of invalid rows (10)' );

like( $m->invalid_rows->[1]->[-1], qr/^\[errors found on row 2] \[field 'one' .*?]$/, 'error with missing value for "if" true' );
like( $m->invalid_rows->[2]->[-1], qr/^\[errors found on row 3] \[field 'two' .*?] \[field 'three'/, 'two errors with two missing "if" dependencies' );
like( $m->invalid_rows->[3]->[-1], qr/^\[errors found on row 4] \[field 'three' .*?]$/, 'error with one missing dependency' );
like( $m->invalid_rows->[4]->[-1], qr/^\[errors found on row 5] \[field 'two' .*?]$/, 'error with other missing dependency' );

like( $m->invalid_rows->[6]->[-1], qr/^\[errors found on row 7] \[field 'four' .*? \[field 'five'.*?/, 'two errors with two missing "if" dependencies' );
like( $m->invalid_rows->[7]->[-1], qr/^\[errors found on row 8] \[field 'five' .*?]/, 'error with "false" dependency value supplied when "if" is true' );
like( $m->invalid_rows->[8]->[-1], qr/^\[errors found on row 9] \[field 'four' .*?]/, 'error with other missing dependency' );

like( $m->invalid_rows->[9]->[-1], qr/^\[errors found on row 10] \[field 'four' should not be completed.*?]/, 'one error with "false" dependency value supplied when "if" is true' );
like( $m->invalid_rows->[10]->[-1], qr/^\[errors found on row 11] \[field 'two' should not be completed.*?]/, 'one error with "true" dependency value supplied when "if" is false' );

like( $m->invalid_rows->[13]->[-1], qr/^\[errors found on row 14] \[field 'seven'.*? \[field 'eight'.*?]$/, 'two errors with second "if" when dependency columns not correct' );

# "one_of" relationships
$c->config_name('one_of');
$m = $r->read_csv('t/data/06_one_of.csv');
is( $v->validate($m), 0, 'broken "one of" relationship input file marked as invalid' );
is( $m->invalid_row_count, 3, 'got expected number of invalid rows (3)' );

like( $m->invalid_rows->[1]->[-1], qr/^\[errors found on row 2\] \[exactly one field out of 'ten', 'eleven' should.*?]$/, 'error when two columns of a "one-of" group is present' );
like( $m->invalid_rows->[2]->[-1], qr/^\[errors found on row 3\] \[value in field 'twelve' is not valid/, 'error due to invalid field' );
like( $m->invalid_rows->[2]->[-1], qr/^\[errors found on row 3\] .*? \[exactly one field out of 'twelve'.*?found 2.*?]$/, 'error when two columns of a three-column "one-of" group are present' );
like( $m->invalid_rows->[3]->[-1], qr/\[exactly one field out of 'twelve'.*?found 3.*?]$/, 'error when three columns of a three-column "one-of" group are present' );

# "some_of" relationships
$c->config_name('some_of');
$m = $r->read_csv('t/data/06_some_of.csv');
is( $v->validate($m), 0, 'broken "some of" relationship input file marked as invalid' );
is( $m->invalid_row_count, 3, 'got expected number of invalid rows (3)' );

like( $m->invalid_rows->[1]->[-1], qr/^\[errors found on row 2] \[at least one field out of 'fifteen'.*?]$/, 'error when no columns in a three-field "some-of" group are found' );
like( $m->invalid_rows->[2]->[-1], qr/^\[errors found on row 3] \[at least one field out of 'eighteen'.*?]$/, 'error when no columns in a two-field "some-of" group are found' );
like( $m->invalid_rows->[3]->[-1], qr/^\[errors found on row 4] \[value in field 'fifteen' is not valid]/, 'check for error with invalid value' );

is( $m->row_count, 4, 'extra, unfilled row ignored' );

done_testing();

