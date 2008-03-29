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
use Catalyst;

__PACKAGE__->config->{session} = { 
    Store => 'MySQL',
    DataSource => 'dbi:mysql:game',
    UserName   => 'root',
    Password   => '',    
    Lock => 'Null', 
    Generate => 'MD5', 
    Serialize => 'Storable', 
    expires => '+1d', 
    cookie_name => 'session', 
    domain => '',
};

$ENV{DBIC_TRACE} = 1;

our $VERSION = '0.01';

#
# Start the application
#

__PACKAGE__->setup( qw/-Debug -Stats ConfigLoader Static::Simple Session::Flex/ );

__PACKAGE__->config->{static}->{debug} = 1;
    
__PACKAGE__->config->{static}->{dirs} = [
	'static',
];





1;
