
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
has 'config_file'   => ( is => 'ro', isa => 'Str' );
has 'config_string' => ( is => 'ro', isa => 'Str' );
has 'project'       => ( is => 'ro', isa => 'Str', required => 1 );
has 'invalid_rows'  => ( is => 'ro', isa => 'ArrayRef[Str]', writer => '_set_invalid_rows' );
has 'validated_csv' => ( is => 'ro', isa => 'ArrayRef[Str]', writer => '_set_validated_csv' );

# private attributes
has '_config'            => ( is => 'rw', isa => 'HashRef' );
has '_file'              => ( is => 'rw', isa => 'Str' );
has '_field_defs'        => ( is => 'rw', isa => 'HashRef' );
has '_field_values'      => ( is => 'rw', isa => 'HashRef' );
has '_valid_fields'      => ( is => 'rw', isa => 'HashRef' );
has '_checked_if_config' => ( is => 'rw', isa => 'Bool', default => 0 );
has '_checked_eo_config' => ( is => 'rw', isa => 'Bool', default => 0 );

# field-validation plugins
has 'plugins' => (
  is  => 'ro',
  default => sub { [ qw( Str Int Enum DateTime Ontology Bool ) ] }
);

#---------------------------------------

sub BUILD {
  my $self = shift;

  unless ( defined $self->config_file or defined $self->config_string ) {
    Bio::Metadata::Validator::Exception::NoConfigSpecified->throw(
      error => 'You must supply either a configuration string or a config file path'
    );
  }

  # make sure the config file exists
  if ( defined $self->config_file and not -e $self->config_file ) {
    Bio::Metadata::Validator::Exception::ConfigFileNotFound->throw(
      error => 'Could not find the specified configuration file (' . $self->config_file . ')'
    );
  }

  # load it
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
            ? "Could not load configuration from string: $e"
            : 'Could not load configuration file (' . $self->config_file . "): $e";
    Bio::Metadata::Validator::Exception::ConfigNotValid->throw( error => $err);
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
  unless ( defined $file ) {
    Bio::Metadata::Validator::Exception::InputFileNotFound->throw(
      error => 'Must specify a file to validate'
    );
  }
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

  # the example manifest CSV contains a header row. We want to avoid trying to
  # parse this, so it should be added to the config and we'll pull it in and
  # store the first chunk of it for future reference
  my $header = substr( $self->_config->{header_row}, 0, 20 );

  my $csv = Text::CSV->new;
  open my $fh, '<:encoding(utf8)', $self->_file
    or Bio::Metadata::Validator::Exception::UnknownError->throw( error => "Problems reading input CSV file: $!" );

  my @validated_csv    = (); # stores input rows with parse errors appended
  my @invalid_rows     = (); # stores just the input rows with parse errors
  my $row_num          = 0;  # row counter (used for error messages)

  ROW: while ( my $row_string = <$fh> ) {
    $row_num++;

    # try to skip the header row, if present, and blank rows
    if (    $row_string =~ m/^$header/
         or $row_string =~ m/^\,+$/ ) {
      push @validated_csv, $row_string;
      next ROW;
    }

    # skip the empty rows that excel likes to include in CSVs
    next ROW if $row_string =~ m/^,+[\r\n]*$/;

    # the current row should now be a data row, so try parsing it
    my $status = $csv->parse($row_string);
    unless ( $status ) {
      Bio::Metadata::Validator::Exception::InputFileValidationError->throw(
        error => "Could not parse row $row_num"
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
        error => "row $row_num; " . $e->error
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

# walk the fields in the row and validate the fields
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
    if ( not defined $field_value or
         $field_value =~ m/^\s*$/ ) {
      if ( defined $field_definition->{required} and
           $field_definition->{required} ) {
        $$row_errors_ref .= " ['$field_name' is a required field]";
      }
      next FIELD;
    }

    # look up the expected type for this field in the configuration
    # and get the appropriate plugin
    my $plugin = $self->plugin_hash->{$field_type};

    if ( not defined $plugin ) {
      Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType->throw(
        error => "There is no validation plugin for this column type ($field_type) (column $i)"
      );
    }

    # use the plugin to validate the field
    my $valid = $plugin->validate($field_value, $field_definition);

    if ( $valid ) {
      $valid_fields->{$field_name} = 1;
    }
    else {
      my $desc = $field_definition->{description} || $field_type;
      $$row_errors_ref .= " [value in field '$field_name' is not a valid $desc]";
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

sub _validate_if_dependencies {
  my ( $self, $row, $row_errors_ref ) = @_;

  return unless defined $self->_config->{dependencies}->{if};

  IF: foreach my $if_col_name ( keys %{ $self->_config->{dependencies}->{if} } ) {
    my $dependency = $self->_config->{dependencies}->{if}->{$if_col_name};

    my $field_definition = $self->_field_defs->{$if_col_name};
    unless ( defined $field_definition ) {
      Bio::Metadata::Validator::Exception::BadConfig->throw(
        error => "Can't find field definition for '$if_col_name' (required by 'if' dependency"
      );
    }

    # make sure that the column which is supposed to be true or false, the
    # "if" column on which the dependency hangs, is itself valid
    if ( not $self->_valid_fields->{$if_col_name} ) {
      my $invalid_dependency_col_num = $field_definition->{col_num} + 1;
      # ( "+ 1" for display purposes)
      $$row_errors_ref .= "[column $invalid_dependency_col_num must be valid in order to statisfy a dependency]";
      next IF;
    }

    # before checking the fields themselves, a quick check on the configuration
    # that we've been given...
    if ( not $self->_checked_if_config ) {
      unless ( $field_definition->{type} eq 'Bool' ) {
        Bio::Metadata::Validator::Exception::BadConfig->throw(
          error => "Fields with an 'if' dependency must have type Bool ('$if_col_name' field)"
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
          my $invalid_dependency_col_num = $self->_field_defs->{$then_col_name}->{col_num} + 1;
          $$row_errors_ref .= " [column $invalid_dependency_col_num must be valid if the '$if_col_name' field is set to true]";
        }
      }

      # shouldn't have any "else" dependencies completed. Here we're checking
      # for a value, not a *valid* value
      foreach my $else_col_name ( @$elses ) {
        if ( $self->_field_values->{$else_col_name} ) {
          my $i = $self->_field_defs->{$else_col_name}->{col_num} + 1;
          $$row_errors_ref .= " [column $i should not be completed if the '$if_col_name' field is set to true]";
        }
      }

    }
    else {

      # false; check that the "else" columns are valid
      foreach my $else_col_name ( @$elses ) {
        if ( not $self->_valid_fields->{$else_col_name} ) {
          my $i = $self->_field_defs->{$else_col_name}->{col_num} + 1;
          $$row_errors_ref .= " [column $i must be valid if the '$if_col_name' field is set to false]";
        }
      }

      # shouldn't have any "then" dependencies completed
      foreach my $then_col_name ( @$thens ) {
        if ( $self->_field_values->{$then_col_name} ) {
          my $i = $self->_field_defs->{$then_col_name}->{col_num} + 1;
          $$row_errors_ref .= " [column $i should not be completed if the '$if_col_name' field is set to false]";
        }
      }

    }
  } # end of "foreach if dependency"
}

#-------------------------------------------------------------------------------

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
