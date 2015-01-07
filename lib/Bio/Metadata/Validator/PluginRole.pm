
package Bio::Metadata::Validator::PluginRole;

# ABSTRACT: Moose Role for validation plugins

use Moose::Role;
use namespace::autoclean;

requires 'validate';

around 'validate' => sub {
  my $orig = shift;
  my $self = shift;

  # avoid warnings when the value to validate is undef
  return 0 unless defined $_[0];

  $self->$orig(@_);
};

1;

