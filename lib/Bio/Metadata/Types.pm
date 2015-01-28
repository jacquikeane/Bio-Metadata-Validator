
package Bio::Metadata::Types;

# ABSTRACT: a type library for the metadata and related modules

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

subtype 'MD5',
  as 'Str',
  where { m/^[0-9a-f]{32}$/i },
  message { 'Not a valid MD5 checksum' };

subtype 'UUID',
  as 'Str',
  where { m/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/i },
  message { 'Not a valid UUID' };

subtype 'AntimicrobialName',
  as 'Str',
  where { m/^[A-Za-z0-9\-\(\)\s]+$/ },
  message { 'Not a valid antimicrobial compound name' };

subtype 'SIRTerm',
  as 'Str',
  where { m/^[SIR]$/ },
  message { 'Not a valid susceptibility term' };

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;
1
