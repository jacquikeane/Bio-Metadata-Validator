
package Bio::Metadata::Validator::Plugin::Str;

# ABSTRACT: validation plugin for validating simple strings

use Moose;
use namespace::autoclean;

use MooseX::Types::Moose qw( Str );

with 'MooseX::Role::Pluggable::Plugin',
     'Bio::Metadata::Validator::PluginRole';

sub validate {
  my ( $self, $value, $field_definition ) = @_;

  return 0 if $value =~ m/^\s*$/;
  return 0 unless is_Str($value);

  # check for a custom validation regex in the config
  if ( $field_definition and ref $field_definition eq 'HASH' ) {
    if ( my $validation = $field_definition->{validation} ) {
      my $re = qr/$validation/;
      return 0 unless $value =~ m/$re/g;
    }
  }

  return 1;
}

__PACKAGE__->meta->make_immutable;

1;

