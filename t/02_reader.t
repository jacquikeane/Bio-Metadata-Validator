#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 20;
use Test::Exception;

use Bio::Metadata::Checklist;
use Bio::Metadata::Types qw( +UUID );

use_ok('Bio::Metadata::Reader');

my $r;
throws_ok { $r = Bio::Metadata::Reader->new }
  qr/Attribute \(checklist\) is required/, 'exception when instantiating without a config';

throws_ok { $r = Bio::Metadata::Reader->new( checklist => {} ) }
  qr/Attribute \(checklist\) does not pass the type constraint/,
  'exception when passing in an invalid config object';

my $checklist = Bio::Metadata::Checklist->new( config_file => 't/data/02_manifest.conf' );

lives_ok { $r = Bio::Metadata::Reader->new( checklist => $checklist ) }
  'no exception with a valid B::M::Config object';

throws_ok { $r->read_csv }
  qr/no input file given/, 'exception when no input file';

throws_ok { $r->read_csv('non-existent file') }
  qr/no such input file/, 'exception with non-existent input file';

throws_ok { $r->read_csv('t/data/02_excel.xlsx') }
  qr/not a CSV file/, 'exception with non-ASCII input file (Excel document)';

my $manifest;
ok( $manifest = $r->read_csv('t/data/02_working_manifest.csv'), '"read" works with a valid manifest' );

isa_ok( $manifest, 'Bio::Metadata::Manifest' );

is( $manifest->row_count, 3, 'got expected number of rows in manifest' );
is( $manifest->rows->[0]->[0], 1, 'got expected value on first row of manifest' );
is( $manifest->rows->[1]->[1], 'two', 'got expected value on second row of manifest' );
is( $manifest->rows->[2]->[1], undef, 'got undef on third row of manifest' );

is( $manifest->md5, '4dbc20b94e33929bc9d8832da698f130', 'MD5 checksum correctly set' );
ok( is_UUID($manifest->uuid), 'UUID correctly set' );

ok( $manifest = $r->read_csv('t/data/02_working_manifest_with_cr.csv'), '"read" works for a manifest with carriage returns' );

is( $manifest->md5, 'e24004218b8d2f7c1947198c2b933b57', 'MD5 checksum correctly set' );
is( $manifest->row_count, 3, 'got expected number of rows in manifest' );
is( $manifest->rows->[-1]->[-1], 'three', 'got expected value on last row of manifest' );

ok( $manifest = $r->read_csv('t/data/02_working_manifest_with_trailing_commas.csv'), '"read" works for a manifest with trailing commas' );

done_testing;

