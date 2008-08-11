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

$ENV{DBIC_TRACE} = 1;

our $VERSION = '0.01';

#
# Start the application
#

__PACKAGE__->setup( qw/
	-Debug 
	-Stats 
	ConfigLoader 
	Static::Simple 
	Session
    Session::Store::FastMmap
    Session::State::Cookie 
    DBIC::Schema::Profiler
    Captcha
    / 
);

__PACKAGE__->config->{static}->{debug} = 1;
    
__PACKAGE__->config->{static}->{dirs} = [
	'static',
];

__PACKAGE__->config->{captcha} = {
    session_name => 'captcha_string',
    new => {
      width => 300,
      height => 40,
      lines => 7,
      #gd_font => 'giant',
      font => '/usr/lib/jvm/java-6-sun-1.6.0.03/jre/lib/fonts/LucidaSansRegular.ttf',
      #rnd_data => ['a'..'z'],      
    },
    create => [qw/normal rect/],
    particle => [100],
    out => {force => 'jpeg'}
};



1;
