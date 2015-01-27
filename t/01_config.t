#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;
use Digest::MD5 qw( md5_hex );

use_ok('Bio::Metadata::Config');

# check the configuration file/string

throws_ok { Bio::Metadata::Config->new() }
  qr/must supply either /, 'exception on missing configuration file';

my $nef = "non-existent-file-$$";
throws_ok { Bio::Metadata::Config->new( config_file => $nef, config_name => 'dummy' ) }
  qr/could not find the specified configuration file/, 'exception on missing config file';

throws_ok { Bio::Metadata::Config->new( config_file => 't/data/01_broken.conf', config_name => 'broken' ) }
  qr/could not load configuration/, 'exception on invalid config file';

# finally, load a valid configuration file

# start with a single config
my $c;
lives_ok { $c = Bio::Metadata::Config->new( config_file => 't/data/01_single.conf', config_name => 'one' ) }
  'no exception with config file with a single config';
is( $c->config->{field}->[0]->{type}, 'Bool', 'specified config sets correct type (Bool) for field' );

my $md5 = md5_hex($c->config_string);
is( $md5, 'beb30861311db39a5e8824ce4caeab0e', 'saved correct config string on object' );

# specify a config but not a name
lives_ok { $c = Bio::Metadata::Config->new( config_file => 't/data/01_single.conf' ) }
  'no exception on instantiating with a config file but no name';

is( $c->config->{field}->[0]->{name}, 'one', 'config loaded' );

# and one with multiple configs
lives_ok { $c = Bio::Metadata::Config->new( config_file => 't/data/01_multiple.conf', config_name => 'one' ) }
  'no exception with config file with multiple configs';
is( $c->config->{field}->[0]->{type}, 'Str', 'specified config sets correct type (Str) for field' );

lives_ok { $c->config_name('two') } 'no exception when changing active config';
is( $c->config->{field}->[0]->{type}, 'Int', 'new active config sets correct type (Int) for field' );

my $expected_fields = [ { name => 'two', type => 'Int' }, { name => 'dummy', type => 'Str' } ];
my $expected_names  = [ 'two', 'dummy' ];

is_deeply( $c->fields,      $expected_fields, 'got expected data structure from "fields"' );
is_deeply( $c->field_names, $expected_names,  'got expected data structure from "field_names"' );

my $config_string = <<EOF_config;
<checklist one>
  header_row "one,two"
  <field>
    name         one
    description  Testing description
    type         Bool
  </field>
  <field>
    name         two
    type         Str
  </field>
</checklist>
EOF_config

# reset the original config object using a file and compare it to a new config object
# created using a string
$c = Bio::Metadata::Config->new( config_file => 't/data/01_single.conf' );

my $new_c;
lives_ok { $new_c = Bio::Metadata::Config->new( config_string => $config_string ) }
  'no exception when loading config string';

is_deeply( $c->_full_config, $new_c->_full_config, 'got expected config when loading from a string' );

done_testing();

