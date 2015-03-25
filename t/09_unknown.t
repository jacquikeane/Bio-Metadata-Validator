#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 36;
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
is( $v->validate($m), 0, '"one of" input file marked as invalid' );
is( $m->invalid_row_count, 4, 'got expected number of invalid rows (4)' );

is( $m->row_errors->[0], undef, 'no error when not using "unknown"' );
is( $m->row_errors->[1], undef, 'no error when using "unknown" correctly' );
is( $m->row_errors->[2], undef, 'no error when using alternative "unknown" term' );

like( $m->row_errors->[3], qr/^\[errors found on row 4\] \[value in field 'two'.*?\[exactly one field out of 'one', 'two' should.*?]$/,
  'error with a disallowed "unknown" in a "one of" column' );
like( $m->row_errors->[4], qr/^\[errors found on row 5\] \[value in field 'two'.*?\[exactly one field out of 'one', 'two' should.*?]$/,
  'error with one allowed, one disallowed "unknown" terms in a "one of"' );
like( $m->row_errors->[5], qr/^\[errors found on row 6\] \[exactly one field out of 'three', 'four' should.*?]$/,
  'error with a disallowed "unknown" in a "one of" column' );
like( $m->row_errors->[6], qr/^\[errors found on row 7\] \[exactly one field out of 'three', 'four' should.*?]$/,
  'error with two allowed "unknown" terms in a "one of"' );

# "some_of" relationships
$c->config_name('some_of');
$m = $r->read_csv('t/data/09_unknown_some_of.csv');
is( $v->validate($m), 0, '"some of" input file marked as invalid' );
is( $m->invalid_row_count, 2, 'got expected number of invalid rows (2)' );

is(   $m->row_errors->[0], undef, 'no error when not using "unknown"' );
is(   $m->row_errors->[1], undef, 'no error when using one "unknown" correctly' );
is(   $m->row_errors->[2], undef, 'no error when using alternative "unknown" term' );
like( $m->row_errors->[3], qr/^\[errors found on row 4] \[value in field 'one'/, 'error with an invalid "unknown" term' );
is(   $m->row_errors->[4], undef, 'no error when using one "unknown" and a valid value' );
is(   $m->row_errors->[5], undef, 'no error when using two "unknown" terms correctly' );
like( $m->row_errors->[6], qr/^\[errors found on row 7] \[value in field 'four'/, 'error with "unknown" in column where it is not allowed' );
is(   $m->row_errors->[7], undef, 'no error with "unknown" in three-field "one of"' );

done_testing;

