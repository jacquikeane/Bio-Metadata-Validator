package Bio::Metadata::Validator::Plugin::Bool;

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin';

sub validate {
  my ( $self, $value ) = @_;

  return ( $value =~ m/^(1|true|yes)$/i ) ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

1;


