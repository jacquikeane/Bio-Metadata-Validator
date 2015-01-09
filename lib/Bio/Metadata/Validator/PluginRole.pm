
package Bio::Metadata::Validator::PluginRole;

# ABSTRACT: Moose Role for validation plugins

use Moose::Role;
use namespace::autoclean;

requires 'validate';

around 'validate' => sub {
  my $orig = shift;
  my $self = shift;
  my $value = shift;

  # avoid warnings when the value to validate is undef
  return 0 unless defined $value;

  # strip wrapping quotes
  $value =~ s/^"?(.*?)"?$/$1/;

  $self->$orig($value, @_);
};

1;

