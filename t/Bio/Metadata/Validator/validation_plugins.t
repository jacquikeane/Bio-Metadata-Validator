#!env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

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

is  ( Bio::Metadata::Validator::Plugin::Int->validate( 42  ), 1, '"Int" validates 42 correctly' );
is  ( Bio::Metadata::Validator::Plugin::Int->validate(  0  ), 1, '"Int" validates 0 correctly' );
is  ( Bio::Metadata::Validator::Plugin::Int->validate( -1  ), 1, '"Int" validates -1 correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( 'a' ), 1, '"Int" invalidates "a" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( {}  ), 1, '"Int" invalidates "{}" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( ''  ), 1, '"Int" invalidates "" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Int->validate( ' ' ), 1, '"Int" invalidates " " correctly' );

is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'a'   ), 1, '"Str" validates "a" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'abc' ), 1, '"Str" validates "abc" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'a b' ), 1, '"Str" validates "a b" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 'a:b' ), 1, '"Str" validates "a:b" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Str->validate( 0     ), 1, '"Str" validates 0 correctly' );
isnt( Bio::Metadata::Validator::Plugin::Str->validate( {}    ), 1, '"Str" invalidates "{}" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Str->validate( ''    ), 1, '"Str" invalidates "" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Str->validate( ' '   ), 1, '"Str" invalidates " " correctly' );

# I guess this a valid test case for the Str validator, but I've no idea how to
# decide whether an arbitrary unicode character constitutes a word character
isnt( Bio::Metadata::Validator::Plugin::Str->validate( '§'   ), 1, '"Str" invalidates "§" correctly' );

is  ( Bio::Metadata::Validator::Plugin::Enum->validate( 'ABC', { values => [ qw( ABC DEF ) ] } ), 1, '"Enum" validates "ABC" correctly' );
is  ( Bio::Metadata::Validator::Plugin::Enum->validate( 'ABC', { values => [ qw( ABC ) ] } ), 1, '"Enum" validates "ABC" correctly against single field' );
isnt( Bio::Metadata::Validator::Plugin::Enum->validate( 'abc', { values => [ qw( ABC DEF ) ] } ), 1, '"Enum" invalidates "abc" correctly' );
isnt( Bio::Metadata::Validator::Plugin::Enum->validate( '',    { values => [ qw( ABC DEF ) ] } ), 1, '"Enum" invalidates "" correctly' );

is  ( Bio::Metadata::Validator::Plugin::DateTime->validate( '2014-12-04' ), 1, '"DateTime" validates "2014-12-04" correctly' );
is  ( Bio::Metadata::Validator::Plugin::DateTime->validate( '2014-12-04T12:28:33+00:00' ), 1, '"DateTime" validates "2014-12-04T12:28:33+00:00" correctly' );
isnt( Bio::Metadata::Validator::Plugin::DateTime->validate( '04-12-14' ), 1, '"DateTime" invalidates "04-12-14" correctly' );
isnt( Bio::Metadata::Validator::Plugin::DateTime->validate( 'wibble' ), 1, '"DateTime" invalidates "wibble" correctly' );

SKIP: {
  skip 'skipping slow tests (set $ENV{RUN_SLOW_TESTS} to true to run)', 2
    if ( not defined $ENV{RUN_SLOW_TESTS} or not $ENV{RUN_SLOW_TESTS} );

  use Bio::Metadata::Validator;
  my $v = Bio::Metadata::Validator->new( config_file => 't/data/ontology.conf', project => 'hicf' );

  throws_ok { $v->validate('t/data/ontology.csv') }
    qr/ invalid rows? in input file/, 'exception when parsing bad ontology CSV';

  like  ( $v->validated_csv->[1], qr/value in field 'envo_term' is not a valid EnvO ontology term/, 'error with bad ontology field' );
  unlike( $v->validated_csv->[2], qr/value in field 'envo_term' is not a valid EnvO ontology term/, 'no error with valid ontology term' );

  unlike( $v->validated_csv->[3], qr/value in field 'gaz_term' is not a valid Gazetteer ontology term/, 'error with bad ontology field' );
  like  ( $v->validated_csv->[4], qr/value in field 'gaz_term' is not a valid Gazetteer ontology term/, 'error with bad ontology field' );
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

