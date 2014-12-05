package Bio::Metadata::Validator::Exception;
# ABSTRACT: Builds exceptions for input data

=head1 SYNOPSIS

Builds exceptions for input data

=cut

use Exception::Class (
  Bio::Metadata::Validator::Exception::UnknownError                   => { description => 'General, uncaught, unforeseen error' },
  Bio::Metadata::Validator::Exception::ConfigFileNotFound             => { description => 'No such config file' },
  Bio::Metadata::Validator::Exception::ConfigFileNotValid             => { description => 'Invalid config file' },
  Bio::Metadata::Validator::Exception::InputFileNotFound              => { description => 'No such input file' },
  Bio::Metadata::Validator::Exception::NoValidatorPluginForColumnType => { description => 'No plugin found to validate the specified column type' },
  Bio::Metadata::Validator::Exception::InputFileParseError            => { description => 'Encountered parsing errors when reading CSV file',
                                                                           fields      => [ qw( num_errors ) ] },
);

1;

