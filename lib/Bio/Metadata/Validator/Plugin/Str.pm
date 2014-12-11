
package Bio::Metadata::Validator::Plugin::Str;

# ABSTRACT: validation plugin for validating simple strings

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin';

sub validate {
  my ( $self, $value ) = @_;

  return 0 if     $value =~ m/^\s*$/;
  return 0 unless $value =~ m/^[\w\s:]+$/;

  return 1;
}

__PACKAGE__->meta->make_immutable;

1;

