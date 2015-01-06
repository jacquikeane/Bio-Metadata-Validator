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

is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'a'   ), 1, '"Str" validates "a" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'abc' ), 1, '"Str" validates "abc" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'a b' ), 1, '"Str" validates "a b" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'a:b' ), 1, '"Str" validates "a:b" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 0     ), 1, '"Str" validates 0 correctly' );
isnt( Bio::Metadata::Validator::Plugin::Str->validate( {}    ), 1, '"Str" invalidates "{}" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Str->validate( ''    ), 1, '"Str" invalidates "" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Str->validate( ' '   ), 1, '"Str" invalidates " " correctly' );

my $v = Bio::Metadata::Validator->new( config_file => 't/data/plugins.conf' );
$v->validate('t/data/plugins.csv');

like( $v->all_rows->[1], qr/value in field 'regex' is not valid/, 'error with field that fails regex' );
like( $v->all_rows->[2], qr/value in field 'int' is not valid/, 'error with bad integer' );
like( $v->all_rows->[3], qr/value in field 'top_limit' is not valid/, 'error with integer larger than top limit' );
like( $v->all_rows->[4], qr/value in field 'bottom_limit' is not valid/, 'error with integer smaller than lower limit' );
like( $v->all_rows->[5], qr/value in field 'bound' is not valid/, 'error with integer above top limit when both bounds specified' );
like( $v->all_rows->[6], qr/value in field 'bound' is not valid/, 'error with integer above top limit when both bounds specified' );
like( $v->all_rows->[6], qr/value in field 'bound' is not valid/, 'error bad integer' );
unlike( $v->all_rows->[7], qr/value in field '.*?' is not valid/, 'no error on valid row' );

# I guess this a valid test case for the Str validator, but I've no idea how to
# decide whether an arbitrary unicode character constitutes a word character
isnt( Bio::Metadata::Validator::Plugin::Str->validate( '§'   ), 1, '"Str" invalidates "§" correctly' );

is  ( Bio::Metadata::Validator::Plugin::Enum->validate( 'ABC', { values => [ qw( ABC DEF ) ] } ), 1, '"Enum" validates "ABC" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Enum->validate( 'ABC', { values => [ qw( ABC ) ] } ), 1, '"Enum" validates "ABC" correctly against single field' );
isnt( Bio::Metadata::Validator::Plugin::Enum->validate( 'abc', { values => [ qw( ABC DEF ) ] } ), 1, '"Enum" invalidates "abc" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Enum->validate( '',    { values => [ qw( ABC DEF ) ] } ), 1, '"Enum" invalidates "" correctly' );

is  ( Bio::Metadata::Validator::Plugin::DateTime->validate( '2014-12-04' ), 1, '"DateTime" validates "2014-12-04" correctly' );
is  ( Bio::Metadata::Validator::Plugin::DateTime->validate( '2014-12-04T12:28:33+00:00' ), 1, '"DateTime" validates "2014-12-04T12:28:33+00:00" correctly' );
is  ( Bio::Metadata::Validator::Plugin::DateTime->validate( '20141204T122833' ), 1, '"DateTime" validates "20141204T122833" correctly' );
isnt( Bio::Metadata::Validator::Plugin::DateTime->validate( '04-12-14' ), 1, '"DateTime" invalidates "04-12-14" correctly' );
isnt( Bio::Metadata::Validator::Plugin::DateTime->validate( 'wibble' ), 1, '"DateTime" invalidates "wibble" correctly' );

SKIP: {
  skip 'slow tests (set $ENV{RUN_SLOW_TESTS} to true to run)', 8
    if ( not defined $ENV{RUN_SLOW_TESTS} or not $ENV{RUN_SLOW_TESTS} );

  diag 'running slow tests';

  require Test::CacheFile;
  Test::CacheFile::cache( 'http://purl.obolibrary.org/obo/subsets/envo-basic.obo', 'envo-basic.obo' );
  Test::CacheFile::cache( 'http://purl.obolibrary.org/obo/gaz.obo', 'gaz.obo' );
  Test::CacheFile::cache( 'http://www.brenda-enzymes.info/ontology/tissue/tree/update/update_files/BrendaTissueOBO', 'bto.obo' );

  $v = Bio::Metadata::Validator->new( config_file => 't/data/ontology.conf' );

  is( $v->validate('t/data/ontology.csv'), 0, 'file is marked as invalid when parsing CSV bad ontology field' );

  like  ( $v->all_rows->[1], qr/value in field 'envo_term' is not valid/, 'error with bad ontology field' );

  unlike( $v->all_rows->[2], qr/value in field 'envo_term' is not valid/, 'no error with valid EnvO term' );
  like  ( $v->all_rows->[3], qr/value in field 'envo_term' is not valid/, 'error with invalid EnvO term' );

  unlike( $v->all_rows->[4], qr/value in field 'gaz_term' is not valid/, 'no error with valid GAZ ontology field' );
  like  ( $v->all_rows->[5], qr/value in field 'gaz_term' is not valid/, 'error with invalid GAZ ontology field' );

  unlike( $v->all_rows->[6], qr/value in field 'bto_term' is not valid/, 'no error with valid BRENDA ontology field' );
  like  ( $v->all_rows->[7], qr/value in field 'bto_term' is not valid/, 'error with invalid BRENDA ontology field' );
}

is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 1       ), 1, '"Bool" validates 1 correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'yes'   ), 1, '"Bool" validates "yes" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'true'  ), 1, '"Bool" validates "true" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 0       ), 1, '"Bool" validates 0 correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'no'    ), 1, '"Bool" validates "no" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Bool->validate( 'false' ), 1, '"Bool" validates "false" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Bool->validate( 2       ), 1, '"Bool" invalidates 2 correctly' );
isnt( Bio::Metadata::Validator::Plugin::Bool->validate( {}      ), 1, '"Bool" invalidates {} correctly' );
isnt( Bio::Metadata::Validator::Plugin::Bool->validate( 'abc'   ), 1, '"Bool" invalidates "abc" correctly' );

done_testing;

