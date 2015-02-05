
package Bio::Metadata::Validator::Plugin::Ontology;

# ABSTRACT: validation plugin for validating ontology terms

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin',
     'Bio::Metadata::Validator::PluginRole';

# store the ontology terms in a set of hashes
has '_ontologies' => ( is => 'rw', isa => 'HashRef[Str]', default => sub { {} } );

#-------------------------------------------------------------------------------

sub validate {
  my ( $self, $value, $field_definition ) = @_;

  die 'ERROR: the Ontology validator requires a file path for the ontology'
    unless defined $field_definition->{path};

  my $ontology_file = $field_definition->{path};
  die "ERROR: couldn't find ontology file '$ontology_file': $!"
    unless -e $ontology_file;

  ( my $ontology_id = $ontology_file ) =~ s/\W//g;

  $self->_load_ontology($ontology_file, $ontology_id)
    if not defined $self->_ontologies->{$ontology_id};

  return $self->_ontologies->{$ontology_id}->{$value} ? 1 : 0;
}

#-------------------------------------------------------------------------------

sub _load_ontology {
  my ( $self, $ontology_file, $ontology_id ) = @_;

  my $ontology = {};

  open ( OBO, '<', $ontology_file )
    or die "ERROR: couldn't read ontology file ($ontology_file): $!";
  while ( <OBO> ) {
    next unless m/^id: (.*)/;
    $ontology->{$1} = 1;
  }
  close OBO;

  $self->_ontologies->{$ontology_id} = $ontology;
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;

__END__

# Just out of curiosity, I tested using system grep to search the files, but it
# turns out to be slower than the current method of caching the ontologies in
# memory as a hash.
#
# Using the "validate" method above the wallclock time for the tests (with the
# ontology files already cached on disk) was 4s. Using system grep the
# wallclock time for the tests is 18s.

sub validate {
  my ( $self, $value, $field_definition ) = @_;

  die 'ERROR: the Ontology validator requires a file path for the ontology'
    unless defined $field_definition->{path};

  my $ontology_file = $field_definition->{path};
  die "ERROR: couldn't find ontology file '$ontology_file': $!"
    unless -e $ontology_file;

  my $grep = "grep '^id: ${value}\$' $ontology_file";
  my $capture = qx/$grep/;

  return $capture ? 1 : 0;
}

