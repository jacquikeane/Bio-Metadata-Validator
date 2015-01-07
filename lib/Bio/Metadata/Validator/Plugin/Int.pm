
package Bio::Metadata::Validator::Plugin::Int;

# ABSTRACT: validation plugin for validating integers

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin',
     'Bio::Metadata::Validator::PluginRole';

sub validate {
  my ( $self, $value, $field_definition ) = @_;

  return 0 unless $value =~ m/^\-?\d+$/;
  
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

