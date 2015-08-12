#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use FileHandle;

BEGIN {
  $ENV{PATHFIND_CONFIG_DIR} = 't/data/10_pathfind_config';
  $ENV{TEST_PATHFIND}       = 1;
}

use_ok('Bio::Metadata::DataFinder');

throws_ok { Bio::Metadata::DataFinder->new }
  qr/Attribute \(input\) is required/,
  'exception instantiating with no parameters';

throws_ok { Bio::Metadata::DataFinder->new( input => '10665_2#81' ) }
  qr/Attribute \(input_type\) is required/,
  'exception instantiating with too few parameters';

throws_ok { Bio::Metadata::DataFinder->new( input_type => 'unknown_type', input => '10665_2#81' ) }
  qr/Attribute \(input_type\) does not pass/,
  'exception instantiating with invalid type';

throws_ok { Bio::Metadata::DataFinder->new( input_type => 'file', input => 't/data/10_id_list.txt' ) }
  qr/must specify "file_id_type"/,
  'exception instantiating with input_type "file", but no "file_id_type"';

throws_ok { Bio::Metadata::DataFinder->new( input_type => 'file', file_id_type => 'sample', input => 'non-existent-file' ) }
  qr/can't find input file/,
  'exception instantiating with non-existent input file';

throws_ok { Bio::Metadata::DataFinder->new( input_type => 'sample', input => '10665_2#81', file_id_type => 'file' ) }
  qr/"file_id_type" cannot be "file"/,
  'exception instantiating with file_id_type eq "file"';

lives_ok { Bio::Metadata::DataFinder->new( input_type => 'sample', input => '10665_2#81' ) }
  'no exception instantiating with sample ID';

lives_ok { Bio::Metadata::DataFinder->new( input_type => 'file', file_id_type => 'sample', input => 't/data/10_lanes.txt' ) }
  'no exception instantiating with input file';

# find a single lanes using a lane ID
my $df = Bio::Metadata::DataFinder->new(
  input_type  => 'lane',
  input       => '10665_2#81',
);

my $lanes;
lives_ok { $lanes = $df->_get_lanes_from_db }
  'no exception when retrieving lanes';
is scalar @$lanes, 1, 'got one lane';
is $lanes->[0]->acc, 'ERR369155', 'got expected accession';

my $found;
lives_ok { $found = $df->find }
  'no exception from "find"';
is_deeply $found->{key_order}, [ '10665_2#81' ], 'single lane ID; found expected accession';
is ref $found->{'10665_2#81'}, 'VRTrack::Lane', 'found one lane';

# find multiple lanes
$df = Bio::Metadata::DataFinder->new(
  input_type   => 'file',
  input        => 't/data/10_lanes.txt',
  file_id_type => 'lane',
);

$found = $df->find;

my $expected = [
  '10660_2#13',
  '10665_2#81',
  '10665_2#90',
  '11111_1#1',
];
is_deeply $found->{key_order}, $expected, 'multiple lane IDs; found expected IDs';
is scalar keys %$found, 5, 'found expected VRTrack::Lane objects';

# find multiple samples
$df = Bio::Metadata::DataFinder->new(
  input_type   => 'file',
  input        => 't/data/10_samples.txt',
  file_id_type => 'sample',
);

$found = $df->find;

$expected = [ qw(
  ERS044413
  ERS044414
  ERS044415
  ERS044416
  ERS044417
  ERS044418
  ERS000000
) ];
is_deeply $found->{key_order}, $expected, 'multiple sample accessions; found expected accessions';
is scalar keys %$found, 8, 'found expected VRTrack::Lane objects';

done_testing;

