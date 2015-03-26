#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 34;
use Test::Exception;

use Bio::Metadata::Validator;

# test a bad config
my $c = Bio::Metadata::Config->new( config_file => 't/data/09_unknown.conf',
                                    config_name => 'if' );
my $r = Bio::Metadata::Reader->new( config => $c );
my $v = Bio::Metadata::Validator->new;
my $m = $r->read_csv('t/data/09_unknown_simple.csv');

# simple unknown values
$c->config_name('unknown');
is( $v->validate($m), 0, 'simple input file marked as invalid' );
is( $m->invalid_row_count, 2, 'got expected number of invalid rows (2)' );

is( $m->row_errors->[0], undef, 'no error when not using "unknown"' );
is( $m->row_errors->[1], undef, 'no error with correctly used "unknown" term' );
is( $m->row_errors->[2], undef, 'no error with alternative "unknown" term' );
is( $m->row_errors->[3], undef, 'no error with unquoted "not available" unknown' );

like( $m->row_errors->[4], qr/^\[errors found on row 5] \[value in field 'two' is not valid]/, 'error with an unrecognised "unknown" term' );
like( $m->row_errors->[5], qr/^\[errors found on row 6] \[value in field 'one' is not valid]/, 'error with an "unknown" term in a field that does not allow it' );

# "if" relationships
$m = $r->read_csv('t/data/09_unknown_if.csv');
$c->config_name('if');
is( $v->validate($m), 0, '"if" input file marked as invalid' );
is( $m->invalid_row_count, 3, 'got expected number of invalid rows (3)' );

like( $m->row_errors->[1], qr/^\[errors found on row 2] \[field 'two' .*?]/, 'error with a missing "if" dependency' );
like( $m->row_errors->[2], qr/^\[errors found on row 3] \[field 'one' .*?]/, 'error with a invalid "if" field' );

is( $m->row_errors->[3], undef, 'no error with alternative "unknown" term in "if" field' );
is( $m->row_errors->[4], undef, 'no error with correctly used unknown in "if" field' );
is( $m->row_errors->[5], undef, 'no error with unknown in "if" field and missing value in dependency field' );
is( $m->row_errors->[6], undef, 'no error with correctly used unknown in "if" dependency' );

like( $m->row_errors->[7], qr/^\[errors found on row 8] \[value in field 'one' .*?]/, 'error with an invalid "unknown" value' );

# "one_of" relationships
$c->config_name('one_of');
$m = $r->read_csv('t/data/09_unknown_one_of.csv');
is( $v->validate($m), 1, '"one of" input file marked as valid' );
is( $m->invalid_row_count, 0, 'got expected number of invalid rows (0)' );

is( $m->row_errors->[0], undef, 'no error when not using "unknown"' );
is( $m->row_errors->[1], undef, 'no error with unknown in required field in "one of"' );
is( $m->row_errors->[2], undef, 'no error with an "unknown" and a valid value in a group' );
is( $m->row_errors->[3], undef, 'no error with both fields "unknown" in a group' );
is( $m->row_errors->[4], undef, 'no error with one "unknown" and one valid field in a group' );

# "some_of" relationships
$c->config_name('some_of');
$m = $r->read_csv('t/data/09_unknown_some_of.csv');
is( $v->validate($m), 0, '"some of" input file marked as invalid' );
is( $m->invalid_row_count, 1, 'got expected number of invalid rows (1)' );

is(   $m->row_errors->[0], undef, 'no error when not using "unknown"' );
like( $m->row_errors->[1], qr/^\[errors found on row 2] \[at least one field out of 'one', 'two'/, 'error with only "unknown" term in "some of"' );
is(   $m->row_errors->[2], undef, 'no error when using one "unknown" and a valid value' );
is(   $m->row_errors->[3], undef, 'no error when using two "unknown" terms in "some of"' );
is(   $m->row_errors->[4], undef, 'no error with no values in "some of" when all fields are optional' );
is(   $m->row_errors->[5], undef, 'no error with just an "unknown" in "some of" when all fields are optional' );
is(   $m->row_errors->[6], undef, 'no error when using one "unknown" and one valid value in "some of"' );
is(   $m->row_errors->[7], undef, 'no error when using one "unknown" and two valid values in "some of"' );

done_testing;

