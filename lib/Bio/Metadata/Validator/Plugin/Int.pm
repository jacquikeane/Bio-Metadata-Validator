
package Bio::Metadata::Validator::Plugin::Int;

# ABSTRACT: validation plugin for validating integers

use Moose;
use namespace::autoclean;

use MooseX::Types::Moose qw( Int );

with 'MooseX::Role::Pluggable::Plugin',
     'Bio::Metadata::Role::ValidatorPlugin';

sub validate {
  my ( $self, $value, $field_definition ) = @_;

  return 0 unless is_Int($value);
  
  if ( $field_definition and ref $field_definition eq 'HASH' ) {
    my $max = $field_definition->{max};
    my $min = $field_definition->{min};

    return 0 if ( defined $max and $value > $max );
    return 0 if ( defined $min and $value < $min );
  }

  return 1;
}

__PACKAGE__->meta->make_immutable;

1;

