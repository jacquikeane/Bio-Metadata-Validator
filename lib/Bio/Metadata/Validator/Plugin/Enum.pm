
package Bio::Metadata::Validator::Plugin::Enum;

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin';

sub validate {
  my ( $self, $value, $field_definition ) = @_;

  my $values = $field_definition->{values};
  my %values = map { $_ => 1 } @$values;
  
  return defined $values{$value} ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

1;

