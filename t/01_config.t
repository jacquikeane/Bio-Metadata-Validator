#!/usr/bin/env perl

use strict;
use warnings;

use Test::More;
use Test::Exception;

use_ok('Bio::Metadata::Config');

# check the configuration file/string

throws_ok { Bio::Metadata::Config->new() }
  qr/Attribute \(config_file\) is required /, 'exception on missing configuration file';

my $nef = "non-existent-file-$$";
throws_ok { Bio::Metadata::Config->new( config_file => $nef, config_name => 'dummy' ) }
  qr/could not find the specified configuration file/, 'exception on missing config file';

throws_ok { Bio::Metadata::Config->new( config_file => 't/data/01_broken.conf', config_name => 'broken' ) }
  qr/could not load configuration file/, 'exception on invalid config file';

# finally, load a valid configuration file

# start with a single config
my $c;
lives_ok { $c = Bio::Metadata::Config->new( config_file => 't/data/01_single.conf', config_name => 'one' ) }
  'no exception with config file with a single config';
is( $c->config->{field}->[0]->{type}, 'Bool', 'specified config sets correct type (Bool) for field' );

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

done_testing();

