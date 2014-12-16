
package Test::CacheFile;

# ABSTRACT: module for downloading and caching large files needed during testing

use strict;
use warnings;

use LWP::Simple;
use File::Path qw( make_path remove_tree );

use base 'Exporter';

our $CACHE_DIR = '.cached_test_files';

our @EXPORT = qw( $CACHE_DIR cache retrieve );

# retrieve and store if the file doesn't already exist
sub cache {
  my ( $url, $filename ) = @_;

  # make the cache directory unless it's already there
  if ( not -d $CACHE_DIR ) {
    make_path( $CACHE_DIR, { error => \my $err } );
    if ( @$err ) {
      foreach my $diag ( @$err ) {
        die "ERROR: couldn't create directory ($CACHE_DIR): " . $diag->{message};
      }
    }
  }

  my $full_path = "$CACHE_DIR/$filename";

  # if the file exists, return the path immediately
  return $full_path if -e $full_path;

  # if not, retrieve it and store it
  my $status = getstore( $url, $full_path );

  die "ERROR: couldn't download file ($url); got HTTP status $status"
    unless $status == 200;

  die "ERROR: downloaded file is empty"
    unless -s $full_path;

  # and then return it
  return $full_path;
}

# delete and re-download the file if it exists
sub retrieve {
  my ( $url, $filename ) = @_;

  my $full_path = "$CACHE_DIR/$filename";
  if ( -e $full_path ) {
    my $removed = unlink $full_path;
    die "ERROR: couldn't remove existing file before retrieving again"
      unless $removed == 1;
  }

 return cache( $url, $filename );
}

1;
