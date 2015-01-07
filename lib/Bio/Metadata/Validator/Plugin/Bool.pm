
package Bio::Metadata::Validator::Plugin::Bool;

# ABSTRACT: validation plugin for validating booleans

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin',
     'Bio::Metadata::Validator::PluginRole';

sub validate {
  my ( $self, $value ) = @_;

  return ( $value =~ m/^(1|true|yes|0|false|no)$/i ) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

1;

