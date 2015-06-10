#!/usr/bin/env perl

use strict;
use warnings;

# use Test::More tests => 25;
use Test::More;
use Test::Exception;

use Bio::Metadata::Validator;

# test a bad checklist
my $c = Bio::Metadata::Checklist->new( config_file => 't/data/06_broken.conf' );
my $r = Bio::Metadata::Reader->new( checklist => $c );
my $v = Bio::Metadata::Validator->new;
my $m = $r->read_csv('t/data/06_if.csv');

throws_ok { $v->validate($m) }
  qr/fields with an 'if' dependency/, 'exception when validating against bad checklist ("if" field is not boolean)';

# "if" relationships
$c = Bio::Metadata::Checklist->new( config_file => 't/data/06_if.conf' );
$r->checklist($c);
$m = $r->read_csv('t/data/06_if.csv');
is( $v->validate($m), 0, 'broken "if" relationship input file marked as invalid' );
is( $m->invalid_row_count, 10, 'got expected number of invalid rows (10)' );

like( $m->row_errors->[1], qr/^\[errors found on row 2] \[field 'one' .*?]$/, 'error with missing value for "if" true' );
like( $m->row_errors->[2], qr/^\[errors found on row 3] \[field 'two' .*?] \[field 'three'/, 'two errors with two missing "if" dependencies' );
like( $m->row_errors->[3], qr/^\[errors found on row 4] \[field 'three' .*?]$/, 'error with one missing dependency' );
like( $m->row_errors->[4], qr/^\[errors found on row 5] \[field 'two' .*?]$/, 'error with other missing dependency' );

like( $m->row_errors->[6], qr/^\[errors found on row 7] \[field 'four' .*? \[field 'five'.*?/, 'two errors with two missing "if" dependencies' );
like( $m->row_errors->[7], qr/^\[errors found on row 8] \[field 'five' .*?]/, 'error with "false" dependency value supplied when "if" is true' );
like( $m->row_errors->[8], qr/^\[errors found on row 9] \[field 'four' .*?]/, 'error with other missing dependency' );

like( $m->row_errors->[9], qr/^\[errors found on row 10] \[field 'four' should not be completed.*?]/, 'one error with "false" dependency value supplied when "if" is true' );
like( $m->row_errors->[10], qr/^\[errors found on row 11] \[field 'two' should not be completed.*?]/, 'one error with "true" dependency value supplied when "if" is false' );

like( $m->row_errors->[13], qr/^\[errors found on row 14] \[field 'seven'.*? \[field 'eight'.*?]$/, 'two errors with second "if" when dependency columns not correct' );

# "one_of" relationships
$c = Bio::Metadata::Checklist->new( config_file => 't/data/06_one_of.conf' );
$r->checklist($c);
$m = $r->read_csv('t/data/06_one_of.csv');
is( $v->validate($m), 0, 'broken "one of" relationship input file marked as invalid' );
is( $m->invalid_row_count, 4, 'got expected number of invalid rows (4)' );

is(   $m->row_errors->[0], undef, 'no errors with valid fields in "one of"' );
like( $m->row_errors->[1], qr/^\[errors found on row 2\] \[exactly one field out of 'one', 'two' should.*?]$/, 'error when two columns of "one-of" present' );
like( $m->row_errors->[2], qr/^\[errors found on row 3\] \['one' is a required field\]\s+\[exactly one field out of 'one', 'two' should.*?]$/, 'error when no columns of "one-of" present and one is required' );
like( $m->row_errors->[3], qr/^\[errors found on row 4\].*?\[exactly one field out of 'three'.*?found 2.*?]$/, 'error when two columns of three-column "one-of" present' );
like( $m->row_errors->[4], qr/\[exactly one field out of 'three'.*?found 3.*?]$/, 'error when three columns of three-column "one-of" present' );
is(   $m->row_errors->[5], undef, 'no errors with no valid fields in "one of" with all optional fields' );

# "some_of" relationships
$c = Bio::Metadata::Checklist->new( config_file => 't/data/06_some_of.conf' );
$r->checklist($c);
$m = $r->read_csv('t/data/06_some_of.csv');
is( $v->validate($m), 0, 'broken "some of" relationship input file marked as invalid' );
is( $m->invalid_row_count, 2, 'got expected number of invalid rows (2)' );

is(   $m->row_errors->[0], undef, 'no error with valid fields in "some of"' );
is(   $m->row_errors->[1], undef, 'no error when both fields in a two-field "some-of" group present' );
like( $m->row_errors->[2], qr/^\[errors found on row 3] \['one' is a required field\]\s+\[at least one field out of 'one'.*?]$/, 'error when no columns in a three-field "some-of" group present' );
like( $m->row_errors->[3], qr/^\[errors found on row 4] \['one' is a required field\]$/, 'error with empty required field in "some-of" group' );
is(   $m->row_errors->[4], undef, 'no error with all fields empty in "some-of" with no required fields' );
is(   $m->row_errors->[5], undef, 'no error with all fields full in three-field "some-of"' );

done_testing;

