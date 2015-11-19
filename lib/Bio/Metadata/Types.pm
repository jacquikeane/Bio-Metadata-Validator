
package Bio::Metadata::Types;

# ABSTRACT: a type library for the metadata and related modules

use strict;
use warnings;

use MooseX::Types -declare => [ qw(
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
) ];
use MooseX::Types::Moose qw( Str Int );
use namespace::autoclean;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

subtype MD5,
  as Str,
  where { m/^[0-9a-f]{32}$/i },
  message { 'Not a valid MD5 checksum' };

subtype UUID,
  as Str,
  where { m/^[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}$/i },
  message { 'Not a valid UUID' };

subtype AntimicrobialName,
  as Str,
  where { m/^[A-Za-z0-9\-\/\(\)\s]+$/ },
  message { 'Not a valid antimicrobial compound name' };

subtype AMRString,
  as Str,
  where { m/(([A-Za-z0-9\-\/\(\)\s]+);([SIRU]);(lt|le|eq|gt|ge)?(((\d+)?\.)?\d+)(;(\w+))?),?\s*/ },
  message { 'Not a valid antimicrobial resistance test result' };
# NOTE this regex isn't quite right. It will still allow broken AMR strings
# after a comma, e.g. am1;S;10,am2. That second, incomplete term should mean
# that the whole string is rejected.

subtype SIRTerm,
  as Str,
  where { m/^[SIR]$/ },
  message { 'Not a valid susceptibility term' };

enum OntologyName, [ qw( gazetteer envo brenda ) ];

subtype OntologyTerm,
  as Str,
  where { m/^[A-Z]+:\d+$/ },
  message { 'Not a valid ontology term' };

subtype PositiveInt,
  as Int,
  where { $_ > 0 },
  message { 'Not a positive integer' };

enum AMREquality, [ qw( le lt eq gt ge ) ];

class_type Tree, { class => 'Tree::Simple' };

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;
1
