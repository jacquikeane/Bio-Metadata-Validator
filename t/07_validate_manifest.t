#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Script::Run;
use File::Temp;
use File::Slurp;

my $script = 'bin/validate_manifest';

run_ok( $script, [ qw( -h ) ], 'script runs ok with help flag' );
run_not_ok( $script, [ ], 'script exits with error status when run with no arguments' );

my ( $rv, $stdout, $stderr ) = run_script( $script, [] );

like( $stderr, qr/ERROR: you must specify a configuration file/, 'got expected error message with no flags' );

( $rv, $stdout, $stderr ) = run_script( $script, [ qw(-c t/data/01_single.conf) ] );

like( $stderr, qr/ERROR: you must specify an input file/, 'got expected error message with just -c flag' );

run_output_matches(
  $script,
  [ qw(-c t/data/01_single.conf t/data/01_broken_manifest.csv) ],
  [ qr/input data are .*?invalid/ ],
  [],
  'got expected "invalid" message with valid config and invalid manifest',
);

run_ok( $script, [ qw(-c t/data/01_single.conf t/data/01_working_manifest.csv) ],
  'runs ok with valid arguments' );

( $rv, $stdout, $stderr ) = run_script( $script, [ '-c', 't/data/01_single.conf', 't/data/01_working_manifest.csv' ] );

like( $stdout, qr/input data are .*?(?<!in)valid/, 'got expected "wrote output" message' );

my $fh = File::Temp->new;
$fh->close;
my $filename = $fh->filename;

( $rv, $stdout, $stderr ) = run_script( $script, [ '-c', 't/data/01_single.conf', '-o', $filename, 't/data/01_working_manifest.csv' ] );

  like( $stdout, qr/wrote validated file to '$filename'/, 'got expected "wrote output" message' );
unlike( $stdout, qr/wrote only invalid rows from validated file/, 'no message about invalid rows' );

( $rv, $stdout, $stderr ) = run_script( $script, [ '-c', 't/data/01_single.conf', '-o', $filename, '-i', 't/data/01_working_manifest.csv' ] );

like( $stdout, qr/wrote only invalid rows from validated file/, 'got expected message about writing invalid rows' );

done_testing();

