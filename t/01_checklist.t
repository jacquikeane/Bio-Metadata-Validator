#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 13;
use Test::Exception;
use Digest::MD5 qw( md5_hex );

use_ok('Bio::Metadata::Checklist');

# check the configuration file/string

throws_ok { Bio::Metadata::Checklist->new() }
  qr/must supply either /, 'exception on missing configuration file';

throws_ok { Bio::Metadata::Checklist->new( config_file => 't/data/01_multiple.conf' ) }
  qr/multiple conf/, 'exception on multiple configurations';

my $nef = "non-existent-file-$$";
throws_ok { Bio::Metadata::Checklist->new( config_file => $nef ) }
  qr/could not find the specified configuration file/, 'exception on missing config file';

throws_ok { Bio::Metadata::Checklist->new( config_file => 't/data/01_broken.conf' ) }
  qr/could not load configuration/, 'exception on invalid config file';

# finally, load a valid configuration file
my $c;
lives_ok { $c = Bio::Metadata::Checklist->new( config_file => 't/data/01_working.conf' ) }
  'no exception with config file with a single config';
is( $c->config->{field}->[0]->{type}, 'Bool', 'specified config sets correct type (Bool) for field' );

my $md5 = md5_hex($c->config_string);
is( $md5, 'beb30861311db39a5e8824ce4caeab0e', 'saved correct config string on object' );

is( $c->config->{field}->[0]->{name}, 'one', 'config loaded' );

# check loading from a configuration string
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

my $new_c;
lives_ok { $new_c = Bio::Metadata::Checklist->new( config_string => $config_string ) }
  'no exception when loading config string';

is_deeply( $c->config, $new_c->config, 'got expected config when loading from a string' );
is_deeply( $c->field_names, [ qw( one two ) ], '"field_names" returns expected names' );
is_deeply(
  $c->fields,
  [
    {
      description => "Testing description",
      name        => "one",
      type        => "Bool"
    },
    {
      name => "two",
      type => "Str"
    }
  ],
  '"fields" returns expected data structure'
);

done_testing;

