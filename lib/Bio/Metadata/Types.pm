
package Bio::Metadata::Types;

# ABSTRACT: a type library for the metadata and related modules

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

subtype 'Bio::Metadata::Types::MD5',
  as 'Str',
  where { m/^[0-9a-f]{32}$/i },
  message { 'Not a valid MD5 checksum' };

subtype 'Bio::Metadata::Types::UUID',
  as 'Str',
  where { m/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/i },
  message { 'Not a valid UUID' };

subtype 'Bio::Metadata::Types::AntimicrobialName',
  as 'Str',
  where { m/^[A-Za-z0-9\-\/\(\)\s]+$/ },
  message { 'Not a valid antimicrobial compound name' };

subtype 'Bio::Metadata::Types::AMRString',
  as 'Str',
  where { m/(([A-Za-z0-9\-\/\(\)\s]+);([SIR]);(\d+)(;(\w+))?),?\s*/ },
  message { 'Not a valid antimicrobial resistance test result' };
# NOTE this regex isn't quite right. It will still allow broken AMR strings
# after a comma, e.g. am1;S;10,am2. That second, incomplete term should mean
# that the whole string is rejected.

subtype 'Bio::Metadata::Types::SIRTerm',
  as 'Str',
  where { m/^[SIR]$/ },
  message { 'Not a valid susceptibility term' };

enum 'Bio::Metadata::Types::OntologyName', [ qw( gazetteer envo brenda ) ];

subtype 'Bio::Metadata::Types::PositiveInt',
  as 'Int',
  where { $_ > 0 },
  message { 'Not a positive integer' };

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;
1
