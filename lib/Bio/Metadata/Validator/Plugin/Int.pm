
package Bio::Metadata::Validator::Plugin::Int;

# ABSTRACT: validation plugin for validating integers

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin';

sub validate {
  my ( $self, $value ) = @_;

  return ( $value =~ m/^[0-9\-]+$/ ) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

1;

