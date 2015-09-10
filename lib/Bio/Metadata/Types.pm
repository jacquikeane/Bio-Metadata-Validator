
package Bio::Metadata::Types;

# ABSTRACT: a type library for the metadata and related modules

use Type::Library -base, -declare => qw(
  MD5
  UUID
  AntimicrobialName
  AMRString
  AMREquality
  SIRTerm
  OntologyName
  OntologyTerm
  PositiveInt
  Tree
  IDType
  Environment
);
use Type::Utils -all;
use Types::Standard -types;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

declare MD5,
  as Str,
  where { m/^[0-9a-f]{32}$/i },
  message { 'Not a valid MD5 checksum' };

declare UUID,
  as Str,
  where { m/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/i },
  message { 'Not a valid UUID' };

declare AntimicrobialName,
  as Str,
  where { m/^[A-Za-z0-9\-\/\(\)\s]+$/ },
  message { 'Not a valid antimicrobial compound name' };

declare AMRString,
  as Str,
  where { m/(([A-Za-z0-9\-\/\(\)\s]+);([SIR]);(lt|le|eq|gt|ge)?(((\d+)?\.)?\d+)(;(\w+))?),?\s*/ },
  message { 'Not a valid antimicrobial resistance test result' };
# NOTE this regex isn't quite right. It will still allow broken AMR strings
# after a comma, e.g. am1;S;10,am2. That second, incomplete term should mean
# that the whole string is rejected.

declare SIRTerm,
  as Str,
  where { m/^[SIR]$/ },
  message { 'Not a valid susceptibility term' };

enum OntologyName, [ qw( gazetteer envo brenda ) ];

declare OntologyTerm,
  as Str,
  where { m/^[A-Z]+:\d+$/ },
  message { 'Not a valid ontology term' };

declare PositiveInt,
  as Int,
  where { $_ > 0 },
  message { 'Not a positive integer' };

enum AMREquality, [ qw( le lt eq gt ge ) ];

class_type Tree, { class => 'Tree::Simple' };

enum IDType, [ qw(
  lane
  sample
  database
  study
  file
  library
  species
) ];

enum Environment, [ qw( test prod ) ];

#-------------------------------------------------------------------------------

1;

