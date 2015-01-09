
package Bio::Metadata::Validator;

# ABSTRACT: module for validating sample metadata according to a configurable checklist

use Moose;
use namespace::autoclean;
use Config::General;
use TryCatch;
use Text::CSV;
use File::Slurp;
use Digest::MD5 qw( md5_hex );
use Term::ANSIColor;

with 'MooseX::Role::Pluggable';

use Bio::Metadata::Validator::Exception;

=head1 NAME

Bio::Metadata::Validator

=head1 SYNOPSIS

 # create an object, handing in the path to the config file
 my $v = Bio::Metadata::Validator->new( config_file => 'hicf.conf' );

 # validate the specified input file
 $v->validate('hicf.csv');

 # display the validation report
 $v->validation_report

 # write out all validated rows
 $v->write_validated_file('all_rows.csv');

 # write just the invalid rows
 $v->write_invalid(1);
 $v->write_validated_file('invalid_rows.csv');

=head1 CONTACT

path-help@sanger.ac.uk

=cut

#-------------------------------------------------------------------------------

# public attributes
has 'write_invalid'  => ( is => 'rw', isa => 'Bool', default => 0 );
has 'verbose_errors' => ( is => 'rw', isa => 'Bool', default => 0 );
has 'config_name'    => ( is => 'rw', isa => 'Str',  trigger => \&_set_active_config );
has 'config_file'    => ( is => 'ro', isa => 'Str' );
has 'config_string'  => ( is => 'ro', isa => 'Str' );
has 'valid'          => ( is => 'ro', isa => 'Bool',          writer => '_set_valid',          default => 0, );
has 'validated_file' => ( is => 'ro', isa => 'Str',           writer => '_set_validated_file', default => '' );
has 'invalid_rows'   => ( is => 'ro', isa => 'ArrayRef[Str]', writer => '_set_invalid_rows' );
has 'all_rows'       => ( is => 'ro', isa => 'ArrayRef[Str]', writer => '_set_validated_csv' );

=attr write_invalid

flag showing whether C<write_validated_file> should write all or just invalid
rows to the output file

=attr verbose_errors

flag showing whether error messages in the output file should include field
descriptions from the checklist configuration

=attr config_name

the name of the configuration to use; mainly intended for testing.

=attr config_file

a configuration file that specifies the checklist. B<Read-only>; specify at
instantiation

=attr config_string

a configuration string that specifies the checklist. B<Read-only>; specify at
instantiation

=attr valid

flag showing whether the current input file is valid. B<Read-only>

=attr validated_file

name of the last file that was validated. B<Read-only>

=attr invalid_rows

list of invalid rows from current input file. B<Read-only>

=attr all_rows

list of all rows from current input file. B<Read-only>

=cut

# private attributes
has '_full_config'             => ( is => 'rw', isa => 'HashRef' );
has '_config'                  => ( is => 'rw', isa => 'HashRef' );
has '_field_defs'              => ( is => 'rw', isa => 'HashRef' );
has '_field_values'            => ( is => 'rw', isa => 'HashRef' );
has '_valid_fields'            => ( is => 'rw', isa => 'HashRef' );
has '_checked_if_config'       => ( is => 'rw', isa => 'Bool', default => 0 );
has '_checked_eo_config'       => ( is => 'rw', isa => 'Bool', default => 0 );

# field-validation plugins
has 'plugins' => (
  is  => 'ro',
  default => sub { [ qw( Str Int Enum DateTime Ontology Bool ) ] },
);

#---------------------------------------

sub BUILD {
  my $self = shift;

  unless ( $self->config_file or $self->config_string ) {
    Bio::Metadata::Validator::Exception::NoConfigSpecified->throw(
      error => "ERROR: you must supply either a configuration string or a config file path\n"
    );
  }

  # make sure the config file exists
  if ( defined $self->config_file and not -e $self->config_file ) {
    Bio::Metadata::Validator::Exception::ConfigFileNotFound->throw(
      error => 'ERROR: could not find the specified configuration file (' . $self->config_file . ")\n"
    );
  }

  # load the config
  my $cg;
  try {
    if ( defined $self->config_string ) {
      $cg = Config::General->new( -String => $self->config_string );
    }
    else {
      $cg = Config::General->new( -ConfigFile => $self->config_file );
    }
  }
  catch ( $e ) {
    my $err = defined $self->config_string
            ? "could not load configuration from string"
            : 'could not load configuration file (' . $self->config_file . ")";
    Bio::Metadata::Validator::Exception::ConfigNotValid->throw( error => "ERROR: $err: $e\n" );
  }

  my %config = $cg->getall;

  # store the full config from the file or string
  $self->_full_config( \%config );

  # and set the actual config hash that will be used
  $self->_set_active_config( $self->config_name || '' );
}

#---------------------------------------

sub _set_active_config {
  my ( $self, $config_name ) = @_;

  # the first time this method gets called is at instantiation, but if the
  # configuration hasn't been set, we'll get an error. Only attempt this if
  # there's a config to choose from
  return unless $self->_full_config;

  if ( $config_name ) {
    # we're looking for a configuration section with a specific name

    unless ( exists $self->_full_config->{checklist}->{$config_name} ) {
      Bio::Metadata::Validator::Exception::ConfigNotValid->throw(
        error => "ERROR: there is no config named '" . $config_name . "'\n"
      );
    }

    $self->_config( $self->_full_config->{checklist}->{$config_name} );

    unless ( defined $self->_config ) {
      Bio::Metadata::Validator::Exception::ConfigNotValid->throw(
        error => "ERROR: failed to load config named '" . $config_name . "'\n"
      );
    }
  }
  else {
    # get the first config from the hash; this assumes there's only one in
    # there. If there are multiple configs in the file and the name isn't
    # specified, which one we choose is undefined
    my ( $name, $config ) = each( %{ $self->_full_config->{checklist} } );

    $self->_config($config);
  }
}

#-------------------------------------------------------------------------------
#- public methods --------------------------------------------------------------
#-------------------------------------------------------------------------------

=head1 METHODS

=head2 validate

Takes a single argument, the path to the file to be validated. Returns 1 if
the input file is valid, 0 otherwise.

When a file is validated, the object stores two arrays. One contains every row
from the input file, with error messages appended to each row if it is found
to be invalid. The second method stores only invalid rows. Use C<all_rows> and
C<invalid_rows> respectively to retrieve them.

=cut

sub validate {
  my ( $self, $file ) = @_;

  # check that we can read the input file
  unless ( defined $file ) {
    Bio::Metadata::Validator::Exception::InputFileNotFound->throw(
      error => "ERROR: must specify a file to validate\n"
    );
  }
  unless ( -e $file ) {
    Bio::Metadata::Validator::Exception::InputFileNotFound->throw(
      error => "ERROR: couldn't find the specified input file ($file)\n"
    );
  }

  # currently we have only one validator, for CSV files
  my $valid = $self->_validate_csv($file);

  $self->_set_valid($valid);
  $self->_set_validated_file($file);

  return $valid;
}

#-------------------------------------------------------------------------------

=head2 validation_report

Prints a human-readable validation report to STDOUT. No return value.

If a filename is given as the only argument, that file will be taken as a new
input file and will be validated before a report is printed to STDOUT.

If no filename is given but an input file has already been validated since
the object was instantiated, the validation report for that input file will be
printed.

Throws a C<Bio::Metadata::Validation::Exception::NotValidated> exception if
no filename is supplied but no file has yet been validated.

=cut

sub validation_report {
  my ( $self, $file ) = @_;

  # if a filename is given, pass it to "validate", otherwise see if we've already
  # validated a file
  my $valid;
  if ( $file ) {
    $self->validate($file);
  }
  else {
    if ( not $self->validated_file ) {
      Bio::Metadata::Validator::Exception::NotValidated->throw(
        error => "ERROR: nothing validated yet\n"
      );
    }
  }

  if ( $self->valid ) {
    print "'" . $self->validated_file . "' is ", colored( "valid\n", 'green' );
  }
  else {
    my $num_invalid_rows = scalar @{$self->invalid_rows};
    print "'" . $self->validated_file . "' is ", colored( "invalid", "bold red" )
          . ". Found $num_invalid_rows invalid row"
          . ( $num_invalid_rows > 1 ? 's' : '' ) . ".\n";
  }
}

#-------------------------------------------------------------------------------

=head2 write_validated_file

Writes the validated rows to file. Takes a single argument, a scalar containing
the path of the output file. No return value.

If C<invalid_rows> is set to true, only invalid rows will be written to the
output file. Default is to write all rows, both valid and invalid.

If C<verbose_errors> is set to true, error messages on invalid rows will
include the full description of the field. The description is taken from the
configuration file.

=cut

sub write_validated_file {
  my ( $self, $output ) = @_;

  unless ( $self->validated_file ) {
    Bio::Metadata::Validator::Exception::NotValidated->throw(
      error => "ERROR: nothing validated yet\n"
    );
  }

  unless ( $output ) {
    Bio::Metadata::Validator::Exception::NoInputSpecified->throw(
      error => "no output filename given\n"
    );
  }

  open ( FILE, '>', $output )
    or die "ERROR: couldn't write validated CSV to '$output': $!";

  if ( $self->write_invalid ) {
    print FILE join '', @{ $self->invalid_rows };
  }
  else {
    print FILE join '', @{ $self->all_rows };
  }
  close FILE;
}

#-------------------------------------------------------------------------------
#- private methods -------------------------------------------------------------
#-------------------------------------------------------------------------------

# reads and validates the CSV file. Returns 1 if valid, 0 otherwise
#
# arguments: scalar; path to file to validate
# returns:   scalar; 1 if valid, 0 otherwise

sub _validate_csv {
  my ( $self, $file ) = @_;

  # the example manifest CSV contains a header row. We want to avoid trying to
  # parse this, so it should be added to the config and we'll pull it in and
  # store the first chunk of it for future reference
  my $header = substr( $self->_config->{header_row} || '', 0, 20 );

  my $csv = Text::CSV->new;
  open my $fh, '<:encoding(utf8)', $file
    or Bio::Metadata::Validator::Exception::UnknownError->throw(
         error => "ERROR: problems reading input CSV file: $!\n"
       );

  my @validated_csv    = (); # stores input rows with parse errors appended
  my @invalid_rows     = (); # stores just the input rows with parse errors
  my $row_num          = 0;  # row counter (used for error messages)

  ROW: while ( my $row_string = <$fh> ) {
    $row_num++;

    # try to skip the header row, if present, and blank rows
    if ( $row_num == 1
        and ( $row_string =~ m/^$header/ or $row_string =~ m/^\,+$/ ) ) {
      push @validated_csv, $row_string;
      next ROW;
    }

    # skip the empty rows that excel likes to include in CSVs
    next ROW if $row_string =~ m/^,+[\r\n]*$/;

    # the current row should now be a data row, so try parsing it
    my $status = $csv->parse($row_string);
    unless ( $status ) {
      Bio::Metadata::Validator::Exception::InputFileValidationError->throw(
        error => "ERROR: could not parse row $row_num\n"
      );
    }

    # validate the fields in the row
    my $row_errors = '';
    try {
      $self->_validate_row($csv, \$row_errors);
    }
    catch ( Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType $e ) {
      # add the row number (which we don't have in the _validate_row method) to
      # the error message and re-throw
      Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType->throw(
        error => "ERROR: row $row_num; " . $e->error
      );
    }

    if ( $row_errors ) {
      $row_string =~ s/[\r\n]//g;
      $row_string .= ",$row_errors\n";
      push @invalid_rows, $row_string;
    }

    push @validated_csv, $row_string;
  }

  $self->_set_invalid_rows( \@invalid_rows );
  $self->_set_validated_csv( \@validated_csv );

  return scalar @invalid_rows ? 0 : 1;
}

#-------------------------------------------------------------------------------

# walks the fields in the row and validates the fields
#
# arguments: ref;    Text::CSV object
# returns:   scalar; validation errors for the row
#            scalar; number of parsing errors

sub _validate_row {
  my ( $self, $csv, $row_errors_ref ) = @_;

  # validate all of the fields but keep track of errors in the scalar that
  # was handed in

  # keep track of the valid fields (valid in terms of their type only) and the
  # contents of the fields, valid or otherwise
  my $valid_fields = {};

  my $field_values = {};

  # keep track of the field definitions, hashed by field name
  my $field_definitions = {};

  my $num_fields = scalar @{ $self->_config->{field} };

  my @row = $csv->fields;
  FIELD: for ( my $i = 0; $i < $num_fields; $i++ ) {
    # retrieve the definition for this particular field, and add in its column
    # number for later
    my $field_definition = $self->_config->{field}->[$i];
    $field_definition->{col_num} = $i;

    my $field_name  = $field_definition->{name};
    my $field_type  = $field_definition->{type};
    my $field_value = $row[$i];

    $field_values->{$field_name} = $field_value;

    $field_definitions->{$field_name} = $field_definition;

    # check for required/optional and skip empty fields
    if ( not defined $field_value or $field_value =~ m/^\s*$/ ) {
      if ( defined $field_definition->{required} and
           $field_definition->{required} ) {
        $$row_errors_ref .= " [field '$field_name' is a required field]";
      }
      next FIELD;
    }

    # look up the expected type for this field in the configuration
    # and get the appropriate plugin
    my $plugin = $self->plugin_hash->{$field_type};

    if ( not defined $plugin ) {
      Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType->throw(
        error => "There is no validation plugin for this column type ($field_type) (column $i)\n"
      );
    }

    # use the plugin to validate the field
    my $valid = $plugin->validate($field_value, $field_definition);

    if ( $valid ) {
      $valid_fields->{$field_name} = 1;
    }
    else {
      if ( $self->verbose_errors ) {
        my $desc = $field_definition->{description} || $field_type;
        $$row_errors_ref .= " [value in field '$field_name' is not valid; field description: '$desc']";
      }
      else {
        $$row_errors_ref .= " [value in field '$field_name' is not valid]";
      }
    }
  }

  $self->_field_defs( $field_definitions );
  $self->_field_values( $field_values );
  $self->_valid_fields( $valid_fields );

  $self->_validate_if_dependencies( \@row, $row_errors_ref );
  $self->_validate_one_of_dependencies( \@row, $row_errors_ref );
  $self->_validate_some_of_dependencies( \@row, $row_errors_ref );
}

#-------------------------------------------------------------------------------

# checks that the row meets any specified "if" dependencies
#
# arguments: ref;    array containing fields for a given row
#            ref;    scalar with the raw row string
# returns:   no return value

sub _validate_if_dependencies {
  my ( $self, $row, $row_errors_ref ) = @_;

  return unless defined $self->_config->{dependencies}->{if};

  IF: foreach my $if_col_name ( keys %{ $self->_config->{dependencies}->{if} } ) {
    my $dependency = $self->_config->{dependencies}->{if}->{$if_col_name};

    my $field_definition = $self->_field_defs->{$if_col_name};
    unless ( defined $field_definition ) {
      Bio::Metadata::Validator::Exception::BadConfig->throw(
        error => "ERROR: can't find field definition for '$if_col_name' (required by 'if' dependency)\n"
      );
    }

    # make sure that the column which is supposed to be true or false, the
    # "if" column on which the dependency hangs, is itself valid
    if ( not $self->_valid_fields->{$if_col_name} ) {
      $$row_errors_ref .= " [field '$if_col_name' must be valid in order to statisfy a dependency]";
      next IF;
    }

    # before checking the fields themselves, a quick check on the configuration
    # that we've been given...
    if ( not $self->_checked_if_config ) {
      unless ( $field_definition->{type} eq 'Bool' ) {
        Bio::Metadata::Validator::Exception::BadConfig->throw(
          error => "ERROR: fields with an 'if' dependency must have type Bool ('$if_col_name' field)\n"
        );
      }
      $self->_checked_if_config(1);
    }

    # if the value of the field named $if_dependency is true, we need to check
    # the values in the "then" fields. If it's false, we need to check the
    # "else" columns. We also need to make sure that if $if_dependency is true,
    # there are no valid fields in the "else" columns.

    # look up the column number for the field
    my $if_col_num = $field_definition->{col_num};

    # work around the Config::General behaviour of single element arrays vs
    # scalars
    my $thens = ref $dependency->{then}
              ? $dependency->{then}
              : [ $dependency->{then} ];
    my $elses = ref $dependency->{else}
              ? $dependency->{else}
              : [ $dependency->{else} ];

    if ( $row->[$if_col_num] ) {

      # true; check that the "then" columns are valid
      foreach my $then_col_name ( @$thens ) {
        if ( not $self->_valid_fields->{$then_col_name} ) {
          $$row_errors_ref .= " [field '$then_col_name' must be valid if field '$if_col_name' is set to true]";
        }
      }

      # shouldn't have any "else" dependencies completed. Here we're checking
      # for a value, not a *valid* value
      foreach my $else_col_name ( @$elses ) {
        if ( $self->_field_values->{$else_col_name} ) {
          $$row_errors_ref .= " [field '$else_col_name' should not be completed if field '$if_col_name' is set to true]";
        }
      }

    }
    else {

      # false; check that the "else" columns are valid
      foreach my $else_col_name ( @$elses ) {
        if ( not $self->_valid_fields->{$else_col_name} ) {
          $$row_errors_ref .= " [field '$else_col_name' must be valid if field '$if_col_name' is set to false]";
        }
      }

      # shouldn't have any "then" dependencies completed
      foreach my $then_col_name ( @$thens ) {
        if ( $self->_field_values->{$then_col_name} ) {
          $$row_errors_ref .= " [field '$then_col_name' should not be completed if field '$if_col_name' is set to false]";
        }
      }

    }
  } # end of "foreach if dependency"
}

#-------------------------------------------------------------------------------

# checks that the row meets any specified "one_of" dependencies
#
# arguments: ref;    array containing fields for a given row
#            ref;    scalar with the raw row string
# returns:   no return value

sub _validate_one_of_dependencies {
  my ( $self, $row, $row_errors_ref ) = @_;

  return unless defined $self->_config->{dependencies}->{one_of};

  GROUP: while ( my ( $group_name, $group ) = each %{ $self->_config->{dependencies}->{one_of} } ) {
    my $num_completed_fields = 0;

    my $group_list = ref $group ? $group : [ $group ];
    FIELD: foreach my $field_name ( @$group_list ) {
      $num_completed_fields++ if $self->_field_values->{$field_name};
    }

    if ( $num_completed_fields != 1 ) {
      my $group_fields = join ', ', map { qq('$_') } @$group_list;
      $$row_errors_ref .= " [exactly one field out of $group_fields should be completed (found $num_completed_fields)]";
    }
  }
}

#-------------------------------------------------------------------------------

# checks that the row meets any specified "some_of" dependencies
#
# arguments: ref;    array containing fields for a given row
#            ref;    scalar with the raw row string
# returns:   no return value

sub _validate_some_of_dependencies {
  my ( $self, $row, $row_errors_ref ) = @_;

  return unless defined $self->_config->{dependencies}->{some_of};

  GROUP: while ( my ( $group_name, $group ) = each %{ $self->_config->{dependencies}->{some_of} } ) {
    my $num_completed_fields = 0;

    my $group_list = ref $group ? $group : [ $group ];
    FIELD: foreach my $field_name ( @$group_list ) {
      $num_completed_fields++ if $self->_field_values->{$field_name};
    }
    if ( $num_completed_fields < 1 ) {
      my $group_fields = join ', ', map { qq('$_') } @$group_list;
      $$row_errors_ref .= " [at least one field out of $group_fields should be completed]";
    }
  }
}

#-------------------------------------------------------------------------------

__PACKAGE__->meta->make_immutable;

1;
