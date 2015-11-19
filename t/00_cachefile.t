#!env perl

use strict;
use warnings;

use Test::More tests => 16;

use File::Path qw( remove_tree );
use Test::File;
use Test::Exception;
use File::stat;

use_ok( 'Test::CacheFile' );

# clear out the cache directory before we start
my $errors;
remove_tree( $Test::CacheFile::CACHE_DIR, {error => \$errors} )
  if -e $Test::CacheFile::CACHE_DIR;
if ( $errors ) {
  foreach my $error ( @$errors ) {
    my ( $file, $message ) = %$error;
    die "ERROR: couldn't delete cache directory ($Test::CacheFile::CACHE_DIR): $message"
  }
}

my $file_name = 'test.txt';
my $file_path = "$Test::CacheFile::CACHE_DIR/$file_name";
my $url       = 'http://google.com';
my $bad_url   = 'http://google.com/nonexistent';

throws_ok { cache( $bad_url, $file_name ) } qr/got HTTP status/, 'exception with bad url';
dir_exists_ok( $Test::CacheFile::CACHE_DIR, 'directory created' );

file_not_exists_ok( $file_path, "test file doesn't exist" );
my $returned_file_path;
lives_ok { $returned_file_path = cache( $url, $file_name) } "'cache' succeeds";
is( $returned_file_path, $file_path, "'cache' returns expected file path" );
file_exists_ok( $file_path, 'test file exists' );

my $file_attributes = stat( $file_path );
my $timestamp = $file_attributes->ctime;

# checking timestamps is dodgy if the script can run quickly enough to change a
# file within a single second. If that happens, the ctime of the old and new
# file are the same and tests fail. Wait a second to guarantee that the new
# file has a later ctime.
sleep 1;

lives_ok { cache( $url, $file_name) } "'cache' succeeds a second time";

$file_attributes = stat( $file_path );
is( $timestamp, $file_attributes->ctime, 'timestamp unchanged after second cache call' );

unlink $file_path;
file_not_exists_ok( $file_path, 'test file unlinked' );
lives_ok { cache( $url, $file_name) } "'cache' succeeds a third time";
file_exists_ok( $file_path, 'test file recovered' );

$file_attributes = stat( $file_path );
$timestamp = $file_attributes->ctime;
sleep 1;

lives_ok { $returned_file_path = retrieve( $url, $file_name ) } "'retrieve' succeeds when file exists";
is( $returned_file_path, $file_path, "'retrieve' returns expected file path" );

$file_attributes = stat( $file_path );
isnt( $file_attributes->ctime, $timestamp, 'timestamp is different when using "retrieve"' );

unlink $file_path;
lives_ok { retrieve( $url, $file_name ) } "'retrieve' succeeds when file doesn't exist";

done_testing();

