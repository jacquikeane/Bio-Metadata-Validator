
package Bio::Metadata::Validator::Plugin::DateTime;

# ABSTRACT: validation plugin for validating date/time strings

use Moose;
use namespace::autoclean;

use DateTime::Format::ISO8601;
use Try::Tiny;

with 'MooseX::Role::Pluggable::Plugin';

sub validate {
  my ( $self, $value ) = @_;

  # ISO8601:2000 permitted two digit dates such as "04-12-14". Later versions
  # removed support for that format, for obvious reasons, but the perl module
  # that we're using to validate dates uses the earlier spec. We're going to
  # explicitly remove that as a valid format. This might need to be looked at
  # again if we find bad formats leaking through
  return 0 if $value =~ m/^\d{2}-\d{2}-\d{2}$/;

  my $dt;
  try {
   $dt = DateTime::Format::ISO8601->parse_datetime($value);
  } catch {
    # caught an exception from DateTime::Format; we'll treat is as meaning the
    # value is not a valid DateTime
  };

  return defined $dt ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

1;


