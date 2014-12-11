package Bio::Metadata::Validator::Plugin::Ontology;

use Moose;
use namespace::autoclean;

with 'MooseX::Role::Pluggable::Plugin';

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


