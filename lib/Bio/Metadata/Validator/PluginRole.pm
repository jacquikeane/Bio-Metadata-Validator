
package Bio::Metadata::Validator::PluginRole;

# ABSTRACT: Moose Role for validation plugins

use Moose::Role;
use namespace::autoclean;

requires 'validate';

=head1 METHODS

=head2 around 'validate'

Tidies the input to the plugins themselves and takes care of flagging fields
containing "unknown".

=cut

around 'validate' => sub {
  my $orig = shift;
  my $self = shift;
  my ( $value, $field_definition ) = @_;

  # avoid warnings when the value to validate is undef
  return 0 unless defined $value;

  # strip wrapping quotes
  $value =~ s/^"?(.*?)"?$/$1/;

  # check for the various possible "unknown" values. If the value in this field
  # is one of those allowed terms meaning "unknown", flag the field as unknown
  return -1
    if ( $field_definition->{accepts_unknown} and
         $field_definition->{__unknown_terms}->{$value} );

  # if this field can't have "unknown" as an allowed value, go on and validate
  # it using the plugin
  return $self->$orig(@_);
};

1;

