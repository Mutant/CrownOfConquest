package RPG;

use strict;
use warnings;

use Carp;
use RPG::Schema;
use RPG::Map;

#
# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a YAML file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root 
#                 directory
#
use Catalyst qw/-Debug ConfigLoader Static::Simple Session::Flex/;

__PACKAGE__->config->{session} = { 
    Store => 'MySQL',
    DataSource => 'dbi:mysql:game',
    UserName   => 'root',
    Password   => '',    
    Lock => 'Null', 
    Generate => 'MD5', 
    Serialize => 'Storable', 
    expires => '+10H', 
    cookie_name => 'session', 
};

$ENV{DBIC_TRACE} = 1;

our $VERSION = '0.01';

#
# Start the application
#

__PACKAGE__->config->{static}->{debug} = 1;

#__PACKAGE__->config->{static}->{ignore_extensions} = []; 

__PACKAGE__->setup;

# __PACKAGE__->model('DBIC')->storage->debug(1);


1;
