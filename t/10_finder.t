
use strict;
use warnings;

#---------------------------------------

package Bio::Metadata::Finder::TestClass;

use Moose;
use namespace::autoclean;

with 'Bio::Metadata::Role::Finder';

#---------------------------------------

package main;

use Test::More;
use Test::Exception;

use_ok('Bio::Metadata::Finder::TestClass');

my $t;
lives_ok { $t = Bio::Metadata::Finder::TestClass->new( environment => 'test' ) }
  'got new B::M::F::TestClass object successfully';

is $t->environment, 'test', 'object is in test environment';

my $expected_config = {
  db_root       => 't/data',
  production_db => [
    qw(
      one
      two
    )
  ],
  subdir_mapping => {
    one => 'two',
  },
};

$t = Bio::Metadata::Finder::TestClass->new( config_file => 't/data/10_finder/test.conf' );
is $t->environment, 'prod', 'object is in prod environment';
is_deeply $t->_config, $expected_config, 'got expected config from Config::General-style config';

$t = Bio::Metadata::Finder::TestClass->new( config_file => 't/data/10_finder/test.yml' );
is_deeply $t->_config, $expected_config, 'got same config from YAML config';

$DB::single = 1;

done_testing;

