
package Bio::Metadata::Validator::Plugin::Str;

# ABSTRACT: validation plugin for validating simple strings

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin',
     'Bio::Metadata::Validator::PluginRole';

sub validate {
  my ( $self, $value, $field_definition ) = @_;

  return 0 if     $value =~ m/^\s*$/;
  return 0 unless $value =~ m/^[\w\s:]+$/;

  # check for a custom validation regex in the config
  if ( $field_definition and ref $field_definition eq 'HASH' ) {
    if ( my $re = $field_definition->{validation} ) {
      return 0 unless $value =~ qr/$re/;
    }
  }

  return 1;
}

__PACKAGE__->meta->make_immutable;

1;

