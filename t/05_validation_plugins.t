#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use Bio::Metadata::Validator;

my $plugins = [ qw(
  Int
  Str
  Enum
  DateTime
  Ontology
  Bool
) ];

foreach my $plugin ( @$plugins ) {
  use_ok("Bio::Metadata::Validator::Plugin::$plugin");
}

is  ( Bio::Metadata::Validator::Plugin::Int->validate( 42    ), 1, '"Int" validates 42 correctly' );
is  ( Bio::Metadata::Validator::Plugin::Int->validate(  0    ), 1, '"Int" validates 0 correctly' );
is  ( Bio::Metadata::Validator::Plugin::Int->validate( -1    ), 1, '"Int" validates -1 correctly' );
is  ( Bio::Metadata::Validator::Plugin::Int->validate( -10   ), 1, '"Int" validates -10 correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( '--1' ), 1, '"Int" invalidates "--1" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( '-'   ), 1, '"Int" invalidates "-" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( 'a'   ), 1, '"Int" invalidates "a" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( {}    ), 1, '"Int" invalidates "{}" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( ''    ), 1, '"Int" invalidates "" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( ' '   ), 1, '"Int" invalidates " " correctly' );

my $c = Bio::Metadata::Config->new( config_file => 't/data/02_plugins.conf',
                                    config_name => 'int' );
my $v = Bio::Metadata::Validator->new(config => $c);
my $r = Bio::Metadata::Reader->new(config => $c);
my $m = $r->read_csv('t/data/02_int.csv');

is( $v->validate($m), 0, 'found invalid Int fields in test CSV' );

like( $m->invalid_rows->[0]->[-1], qr/value in field 'int' is not valid/, 'error with field that fails basic test for integer' );
like( $m->invalid_rows->[1]->[-1], qr/value in field 'top_limit' is not valid/, 'error with int > limit' );
like( $m->invalid_rows->[2]->[-1], qr/value in field 'bottom_limit' is not valid/, 'error with int < limit' );
like( $m->invalid_rows->[3]->[-1], qr/value in field 'bound' is not valid/, 'error with int < lower bound' );
like( $m->invalid_rows->[4]->[-1], qr/value in field 'bound' is not valid/, 'error with int > upper bound' );

is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'a'   ), 1, '"Str" validates "a" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'abc' ), 1, '"Str" validates "abc" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'a b' ), 1, '"Str" validates "a b" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'a:b' ), 1, '"Str" validates "a:b" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 0     ), 1, '"Str" validates 0 correctly' );
isnt( Bio::Metadata::Validator::Plugin::Str->validate( ''    ), 1, '"Str" invalidates "" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Str->validate( ' '   ), 1, '"Str" invalidates " " correctly' );

# I guess this a valid test case for the Str validator, but I've no idea how to
# decide whether an arbitrary unicode character constitutes a word character
TODO: {
  todo_skip "can't test whether unicode is sensible string text", 1;
  isnt( Bio::Metadata::Validator::Plugin::Str->validate( '§'   ), 1, '"Str" invalidates "§" correctly' );
}

$c->config_name('str');
$m = $r->read_csv('t/data/02_str.csv');

is( $v->validate($m), 0, 'found invalid Str fields in test CSV' );

is( $m->invalid_row_count, 1, 'got expected number of invalid rows' );
like( $m->invalid_rows->[0]->[-1], qr/\[errors found on row 8\] \[value in field 'amr_regex'/,
  'error with invalid AMR string' );

is  ( Bio::Metadata::Validator::Plugin::Enum->validate( 'ABC', { values => [ qw( ABC DEF ) ] } ), 1, '"Enum" validates "ABC" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Enum->validate( 'ABC', { values => [ qw( ABC ) ] } ), 1, '"Enum" validates "ABC" correctly against single field' );
isnt( Bio::Metadata::Validator::Plugin::Enum->validate( 'abc', { values => [ qw( ABC DEF ) ] } ), 1, '"Enum" invalidates "abc" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Enum->validate( '',    { values => [ qw( ABC DEF ) ] } ), 1, '"Enum" invalidates "" correctly' );

is  ( Bio::Metadata::Validator::Plugin::DateTime->validate( '2014-12-04' ), 1, '"DateTime" validates "2014-12-04" correctly' );
is  ( Bio::Metadata::Validator::Plugin::DateTime->validate( '2014-12-04T12:28:33+00:00' ), 1, '"DateTime" validates "2014-12-04T12:28:33+00:00" correctly' );
is  ( Bio::Metadata::Validator::Plugin::DateTime->validate( '20141204T122833' ), 1, '"DateTime" validates "20141204T122833" correctly' );
isnt( Bio::Metadata::Validator::Plugin::DateTime->validate( '04-12-14' ), 1, '"DateTime" invalidates "04-12-14" correctly' );
isnt( Bio::Metadata::Validator::Plugin::DateTime->validate( 'wibble' ), 1, '"DateTime" invalidates "wibble" correctly' );

is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 1       ), 1, '"Bool" validates 1 correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'yes'   ), 1, '"Bool" validates "yes" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'YES'   ), 1, '"Bool" validates "YES" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'true'  ), 1, '"Bool" validates "true" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 0       ), 1, '"Bool" validates 0 correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'no'    ), 1, '"Bool" validates "no" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'NO'    ), 1, '"Bool" validates "NO" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'false' ), 1, '"Bool" validates "false" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Bool->validate( 2       ), 1, '"Bool" invalidates 2 correctly' );
isnt( Bio::Metadata::Validator::Plugin::Bool->validate( undef   ), 1, '"Bool" invalidates undef correctly' );
isnt( Bio::Metadata::Validator::Plugin::Bool->validate( {}      ), 1, '"Bool" invalidates {} correctly' );
isnt( Bio::Metadata::Validator::Plugin::Bool->validate( 'abc'   ), 1, '"Bool" invalidates "abc" correctly' );

SKIP: {
  skip 'slow tests (set $ENV{RUN_SLOW_TESTS} to true to run)', 8
    if ( not defined $ENV{RUN_SLOW_TESTS} or not $ENV{RUN_SLOW_TESTS} );

  diag 'running slow tests';

  require Test::CacheFile;
  Test::CacheFile::cache( 'http://purl.obolibrary.org/obo/subsets/envo-basic.obo', 'envo-basic.obo' );
  Test::CacheFile::cache( 'http://purl.obolibrary.org/obo/gaz.obo', 'gaz.obo' );
  Test::CacheFile::cache( 'http://www.brenda-enzymes.info/ontology/tissue/tree/update/update_files/BrendaTissueOBO', 'bto.obo' );

  $v = Bio::Metadata::Validator->new( config_file => 't/data/02_ontology.conf' );

  is( $v->validate_csv('t/data/02_ontology.csv'), 0, 'file is marked as invalid when parsing CSV bad ontology field' );

  like  ( $v->all_rows->[1], qr/value in field 'envo_term' is not valid/, 'error with bad ontology field' );

  unlike( $v->all_rows->[2], qr/value in field 'envo_term' is not valid/, 'no error with valid EnvO term' );
  like  ( $v->all_rows->[3], qr/value in field 'envo_term' is not valid/, 'error with invalid EnvO term' );

  unlike( $v->all_rows->[4], qr/value in field 'gaz_term' is not valid/, 'no error with valid GAZ ontology field' );
  like  ( $v->all_rows->[5], qr/value in field 'gaz_term' is not valid/, 'error with invalid GAZ ontology field' );

  unlike( $v->all_rows->[6], qr/value in field 'bto_term' is not valid/, 'no error with valid BRENDA ontology field' );
  like  ( $v->all_rows->[7], qr/value in field 'bto_term' is not valid/, 'error with invalid BRENDA ontology field' );
}

done_testing;

