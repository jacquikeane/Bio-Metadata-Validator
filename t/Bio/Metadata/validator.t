#!env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use_ok('Bio::Metadata::Validator');

# try loading non-existent files
my $nef = "non-existent-file-$$";

# check the configuration file

throws_ok { Bio::Metadata::Validator->new( config_file => $nef, project => 'hicf' ) }
  qr/Could not find the specified configuration file/, 'exception on missing config file';

# try a broken configuration
throws_ok { Bio::Metadata::Validator->new( config_file => 't/data/broken.conf', project => 'hicf' ) }
  qr/Could not load configuration file/, 'exception on invalid config file';

# finally, load a valid configuration file and check we get the expected
# parameters from it
my $v = Bio::Metadata::Validator->new( config_file => 't/data/hicf.conf', project => 'hicf' );
is( $v->_config->{field}->[5]->{type}, 'Str', 'specified config sets correct type (Str) for scientific_name' );

# check the input file

throws_ok { $v->validate($nef) }
  qr/Could not find the specified input file/, 'exception on missing input file';

throws_ok { $v->validate('t/data/broken_manifest.csv') }
  qr/Found 1 parsing error in input file/, 'exception on broken input file';

done_testing();

