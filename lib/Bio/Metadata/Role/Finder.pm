
package Bio::Metadata::Role::Finder;

# ABSTRACT: role for use with classes that interact with pathogens tracking data

use Moose::Role;
use MooseX::Types::Moose qw( Str HashRef );
use MooseX::StrictConstructor;
use Bio::Metadata::Types qw( Environment );

use Carp qw( croak );
use Config::Any;

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------
#- public attributes -----------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 ATTRIBUTES

=attr environment

The runtime environment. Must be either C<prod> or C<test>. The default is
C<prod>, unless specified explicitly at instantiation or by setting the
environment variable C<TEST_PATHFIND>. If C<TEST_PATHFIND> is true,
C<environment> defaults to 'C<test>'.

Must be set at instantiation or via C<TEST_PATHFIND> environment variable.

=cut

has 'environment' => (
  is       => 'ro',
  isa      => Environment,
  default  => sub {
    return $ENV{TEST_PATHFIND}
           ? 'test'
           : 'prod';
  },
);

#---------------------------------------

=attr config_file

Path to the configuration file.

If C<environment> is 'C<test>', the default is a directory within the test
suite, otherwise the default is a Sanger-specific disk location. Default is
'C<prod>'.

May be overridden by setting at instantiation.

=cut

has 'config_file' => (
  is      => 'ro',
  isa     => Str,
  lazy    => 1,
  writer  => '_set_config_file',
  builder => '_build_config_file',
);

sub _build_config_file {
  my $self = shift;

  my $config_file = $self->environment eq 'test'
                  ? 't/data/10_finder/test.conf'
                  : '/software/pathogen/projects/PathFind/config/prod.yml';

  croak "ERROR: config file ($config_file) does not exist"
    unless -f $config_file;

  return $config_file;
}

#-------------------------------------------------------------------------------
#- private attributes ----------------------------------------------------------
#-------------------------------------------------------------------------------

# the configuration hash
has '_config' => (
  is      => 'rw',
  isa     => HashRef,
  lazy    => 1,
  writer  => '_set_config',
  builder => '_build_config',
);

sub _build_config {
  my $self = shift;

  # load the specified configuration file. Using Config::Any should let us
  # handle several configuration file formats, such as Config::General or YAML
  my $cfg = Config::Any->load_files(
    {
      files           => [ $self->config_file ],
      use_ext         => 1,
      flatten_to_hash => 1,
    }
  );

  croak q(ERROR: failed to read configuration from file ") . $self->config_file . q(")
    unless scalar keys %{ $cfg->{$self->config_file} };

  return $cfg->{$self->config_file};
}

#-------------------------------------------------------------------------------

1;
