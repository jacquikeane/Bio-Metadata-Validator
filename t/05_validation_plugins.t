#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 78;
use Test::Exception;

use Bio::Metadata::Validator;

my $plugins = [ qw(
  Int
  Str
  Enum
  DateTime
  Ontology
  Bool
  Taxonomy
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

my $c = Bio::Metadata::Config->new( config_file => 't/data/05_plugins.conf',
                                    config_name => 'int' );
my $r = Bio::Metadata::Reader->new(config => $c);
my $v = Bio::Metadata::Validator->new;
my $m = $r->read_csv('t/data/05_int.csv');

is( $v->validate($m), 0, 'found invalid Int fields in test CSV' );

like( $m->row_errors->[0], qr/value in field 'int' is not valid/, 'error with field that fails basic test for integer' );
like( $m->row_errors->[1], qr/value in field 'top_limit' is not valid/, 'error with int > limit' );
like( $m->row_errors->[2], qr/value in field 'bottom_limit' is not valid/, 'error with int < limit' );
like( $m->row_errors->[3], qr/value in field 'bound' is not valid/, 'error with int < lower bound' );
like( $m->row_errors->[4], qr/value in field 'bound' is not valid/, 'error with int > upper bound' );

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
$m = $r->read_csv('t/data/05_str.csv');

is( $v->validate($m), 0, 'found invalid Str fields in test CSV' );

is( $m->invalid_row_count, 1, 'got expected number of invalid rows' );
like( $m->row_errors->[7], qr/\[errors found on row 8\] \[value in field 'amr_regex'/,
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

# these next tests use mock ontology/taxonomy  files, with valid content but only a few terms
$c = Bio::Metadata::Config->new( config_file => 't/data/05_ontology.conf' );
$r->config($c);
$m = $r->read_csv('t/data/05_ontology.csv');

_run_ontology_tests($m);

$c = Bio::Metadata::Config->new( config_file => 't/data/05_taxonomy.conf' );
$r->config($c);
$m = $r->read_csv('t/data/05_taxonomy.csv');

_run_taxonomy_tests($m);

# can't check that the tax ID matches the scientific name here, because we're
# validating field by field, so we never have both in our hand at the same
# time

# and this block runs the same tests but against full ontology/taxonomy files
SKIP: {
  skip 'slow tests (set $ENV{RUN_SLOW_TESTS} to true to run)', 8
    if ( not defined $ENV{RUN_SLOW_TESTS} or not $ENV{RUN_SLOW_TESTS} );

  diag 'running slow tests; using full ontology/taxonomy files';

  require Test::CacheFile;

  diag 'downloading ontologies';
  Test::CacheFile::cache( 'http://purl.obolibrary.org/obo/subsets/envo-basic.obo', 'envo-basic.obo' );
  Test::CacheFile::cache( 'http://purl.obolibrary.org/obo/gaz.obo', 'gaz.obo' );
  Test::CacheFile::cache( 'http://www.brenda-enzymes.info/ontology/tissue/tree/update/update_files/BrendaTissueOBO', 'bto.obo' );

  $c = Bio::Metadata::Config->new( config_file => 't/data/05_full_ontologies.conf' );
  $r->config($c);
  $m = $r->read_csv('t/data/05_ontology.csv');

  _run_ontology_tests($m);

  diag 'downloading taxonomy';
  Test::CacheFile::cache( 'ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz', 'taxdump.tar.gz' );

  require Archive::Tar;
  my $tar = Archive::Tar->new('.cached_test_files/taxdump.tar.gz');
  $tar->extract_file( 'names.dmp', '.cached_test_files/names.dmp' );

  $c = Bio::Metadata::Config->new( config_file => 't/data/05_full_taxonomy.conf' );
  $r->config($c);
  $m = $r->read_csv('t/data/05_taxonomy.csv');

  _run_taxonomy_tests($m);
}

done_testing;

exit;

#-------------------------------------------------------------------------------

sub _run_ontology_tests {
  my $m = shift;

  is( $v->validate($m), 0, 'file is marked as invalid when parsing CSV bad ontology field' );

  like( $m->row_errors->[0], qr/errors found on row 1] \[value in field 'envo_term' is not valid/, 'error with bad ontology field' );
  like( $m->row_errors->[2], qr/errors found on row 3] \[value in field 'envo_term' is not valid/, 'error with invalid EnvO term' );
  like( $m->row_errors->[4], qr/errors found on row 5] \[value in field 'gaz_term' is not valid/, 'error with invalid GAZ field' );
  like( $m->row_errors->[6], qr/errors found on row 7] \[value in field 'bto_term' is not valid/, 'error with invalid BRENDA field' );

  is( $m->row_errors->[1], undef, 'no error with valid EnvO term' );
  is( $m->row_errors->[3], undef, 'no error with valid gaz term' );
  is( $m->row_errors->[5], undef, 'no error with valid BRENDA term' );
}

sub _run_taxonomy_tests {
  my $m = shift;

  is( $v->validate($m), 0, 'file is marked as invalid when parsing CSV bad taxonomy fields' );

  is( $m->row_errors->[0], undef, 'no error with valid tax ID and scientific name' );
  is( $m->row_errors->[1], undef, 'no error with valid tax ID only' );
  is( $m->row_errors->[2], undef, 'no error with valid scientific name only' );

  like( $m->row_errors->[3], qr/errors found on row 4] \[value in field 'scientific_name' is not valid/, 'error with bad scientific name' );
  like( $m->row_errors->[4], qr/errors found on row 5] \[value in field 'tax_id' is not valid/, 'error with bad tax ID' );

  TODO: {
    todo_skip "can't check that tax ID matches scientific name", 1;
    like( $m->row_errors->[5], qr/errors found on row 6]/, "error where tax ID doesn't match scientific name" );
  }
}

