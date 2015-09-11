
package Bio::Metadata::Checklist;

# ABSTRACT: a class representing a checklist

use Moose;
use namespace::autoclean;

use Config::General;
use Carp qw( croak );
use Try::Tiny;
use File::Slurp qw( read_file );
use Types::Standard qw( Str HashRef );

#-------------------------------------------------------------------------------

# public attributes
has 'config_file'  => (
  is       => 'ro',
  isa      => Str,
  trigger  => \&_accept_config_file,
);

has 'config_string' => (
  is     => 'ro',
  isa    => Str,
  writer => '_set_config_string',
  trigger => \&_accept_config_string,
);

has 'config' => (
  traits  => ['Hash'],
  is      => 'ro',
  isa     => HashRef,
  writer  => '_set_config',
  handles => { get => 'get' },
);

=attr config_file

a configuration file that specifies the checklist. Must supply either
C<config_file> or C<config_string>. B<Read-only>; specify at instantiation

=attr config_string

a configuration string that specifies the checklist. Must supply either
C<config_file> or C<config_string>. B<Read-only>; specify at instantiation

=attr config

the current active configuration. B<Read-only>; set internally

=attr config_string

the contents of the full configuration file, stored as a single string.
B<Read-only>; set internally

=cut

#---------------------------------------

# triggers

sub _accept_config_file {
  my $self = shift;

  # make sure the config file exists
  croak 'ERROR: could not find the specified configuration file (' . $self->config_file . ")\n"
    unless -e $self->config_file;

  # load the config
  my $config_string = read_file( $self->config_file );

  $self->_set_config_string($config_string);
}

#---------------------------------------

sub _accept_config_string {
  my $self = shift;

  my $cg;
  try {
    $cg = Config::General->new( -String => $self->config_string );
  } catch {
    croak "ERROR: could not load configuration: $_";
  };

  my %full_config = $cg->getall;
  my $cl = $full_config{checklist};

  croak 'ERROR: there appear to be multiple configurations in the supplied config string or file'
    if scalar keys %$cl > 1;

  my @config_names = sort { $cl->{$a} <=> $cl->{$b} } keys %$cl;

  $self->_set_config( $cl->{$config_names[0] } );
}

#-------------------------------------------------------------------------------
#- construction ----------------------------------------------------------------
#-------------------------------------------------------------------------------

sub BUILD {
  my $self = shift;

  croak 'ERROR: you must supply either "config_file" or "config_string"'
    unless ( defined $self->config_file or $self->config_string );
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 fields

Returns a reference to an array containing the field definitions in the
current config.

=cut

sub fields {
  my $self = shift;

  return unless $self->config;
  return $self->config->{field};
}

#-------------------------------------------------------------------------------

=head2 field_names

Returns a reference to an array containing the field names in the current
config, in the order in which they appear in the configuration.

=cut

sub field_names {
  my $self = shift;

  return unless $self->config;
  my @names;
  foreach my $field ( @{ $self->config->{field} } ) {
    push @names, $field->{name};
  }
  return \@names;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# none

#-------------------------------------------------------------------------------

=head1 CONTACT

path-help@sanger.ac.uk

=cut

__PACKAGE__->meta->make_immutable;

1;

