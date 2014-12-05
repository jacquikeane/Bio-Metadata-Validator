
package Bio::Metadata::Validator;

# ABSTRACT: module for validating sample metadata according to a configurable checklist

use Moose;
use namespace::autoclean;
use Config::General;
use TryCatch;
use Text::CSV;

with 'MooseX::Getopt',
     'MooseX::Role::Pluggable';

use Bio::Metadata::Validator::Exception;

=head1 NAME

Bio::Metadata::Validator

=head1 SYNOPSIS

=head1 METHODS

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes
has 'config_file'   => ( is => 'ro', isa => 'Str', required => 1 );
has 'project'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'validated_csv' => ( is => 'ro', isa => 'ArrayRef[Str]', writer => '_set_validated_csv' );

# private attributes
has '_config' => ( is => 'rw', isa => 'HashRef' );
has '_file'   => ( is => 'rw', isa => 'Str' );

# field validation plugins
has 'plugins' => (
  is  => 'ro',
  default => sub { [ qw( Str Int Enum DateTime Location Bool ) ] }
);

#---------------------------------------

sub BUILD {
  my $self = shift;

  # make sure the config file exists
  unless ( -e $self->config_file ) {
    Bio::Metadata::Validator::Exception::ConfigFileNotFound->throw(
      error => 'Could not find the specified configuration file (' . $self->config_file . ')'
    );
  }

  # load it
  my $cg;
  try {
    $cg = Config::General->new($self->config_file);
  }
  catch {
    Bio::Metadata::Validator::Exception::ConfigFileNotValid->throw(
      error => 'Could not load configuration file (' . $self->config_file . ')'
    );
  }

  my %config = $cg->getall;
  $self->_config( $config{$self->project} );
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

sub validate {
  my ( $self, $file ) = @_;

  # check that we can read the input file
  unless ( -e $file ) {
    Bio::Metadata::Validator::Exception::InputFileNotFound->throw(
      error => "Could not find the specified input file ($file)"
    );
  }

  $self->_file( $file );

  # currently we have only one validator, for CSV files
  $self->_validate_csv;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# reads and validates the CSV file. Returns 1 if valid, 0 otherwise

sub _validate_csv {
  my $self = shift;

  my $csv = Text::CSV->new;
  open my $fh, '<:encoding(utf8)', $self->_file
    or Bio::Metadata::Validator::Exception::UnknownError->throw( error => "Problems reading input CSV file: $!" );

  my @validated_csv = ();
  my $parse_errors  = 0;
  my $row_num       = 0;

  # the example manifest CSV contains a header row. We want to avoid trying to
  # parse this, so it should be added to the config and we'll pull it in and
  # store the first chunk of it for future reference
  my $header = substr( $self->_config->{header_row}, 0, 20 );

  ROW: while ( my $row_string = <$fh> ) {
    $row_num++;

    # try to skip the header row, if present, and blank rows
    next ROW if $row_string =~ m/^$header/;
    next ROW if $row_string =~ m/^\,+$/;

    # the current for should now be a data row, so try parsing it
    my $status = $csv->parse($row_string);
    unless ( $status ) {
      push @validated_csv, '[could not parse row $row_num] $row_string';
      $parse_errors++;
      next ROW;
    }

    # the row parsed successfully, so walk the fields in the row and use the
    # validation plugins to check the type

    # parse the whole row but keep track off errors in the individual fields
    my $row_errors = '';

    my @row = $csv->fields;
    FIELD: for ( my $i = 0; $i < scalar @row; $i++ ) {
      my $value = $row[$i];
      my $field_definition = $self->_config->{field}->[$i];

      # skip empty fields (we'll enforce required/optional later)
      next FIELD unless $value;

      # look up the expected type for this field in the configuration
      # and get the appropriate plugin
      my $type = $self->_config->{field}->[$i]->{type};
      my $plugin = $self->plugin_hash->{$type};

      if ( not defined $plugin ) {
        Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType->throw(
          error => "There is no validation plugin for this column type ($type) (row $row_num, column $i)"
        );
      }

      # use the plugin to validate the field
      my $valid = $plugin->validate($value, $field_definition);
      if ( not $valid ) {
        $row_errors .= "[column $i: not a valid $type] ";
        $parse_errors++;
      }
    }

    # prepend error messages to the row strings and store them
    push @validated_csv, ( $row_errors ? "$row_errors " : '' ) . $row_string;
  }

  $self->_set_validated_csv( \@validated_csv );

  if ( $parse_errors ) {
    Bio::Metadata::Validator::Exception::InputFileParseError->throw(
      error      => "Found $parse_errors parsing error" . ( $parse_errors > 1 ? 's' : '' ) . ' in input file',
      num_errors => $parse_errors
    );
  }
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;
