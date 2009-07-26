package RPG;

use strict;
use warnings;

use Carp;
use Data::Dumper;

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
BEGIN {
    __PACKAGE__->config->{captcha} = {
        session_name => 'captcha_string',
        new          => {
            width  => 300,
            height => 40,
            lines  => 7,

            #rnd_data => ['a'..'z'],
        },
        create   => [qw/normal rect/],
        particle => [100],
        out      => { force => 'jpeg' }
    };

    # Needs to be set here or the config won't be loaded in time, and DBIC will complain it doesn't have a schema
    #  You would think it would just be found automatically... oh well...
    #  For a dev environment, set RPG_HOME environment var
    __PACKAGE__->config->{home} = $ENV{RPG_HOME} || '/home/sam/RPG';

    __PACKAGE__->config->{session} = {
        session => {
            dbic_class => 'DBIC::Session',
            expires    => 60 * 20,
        },
    };

    __PACKAGE__->config(
        root       => __PACKAGE__->path_to('root'),
        'View::TT' => { INCLUDE_PATH => [ __PACKAGE__->path_to('root'), ] },
    );    
    
}

__PACKAGE__->setup(
    qw/
        -Debug
        -Stats
        ConfigLoader
        Session 
        Session::Store::DBIC
        Session::State::Cookie
        DBIC::Schema::Profiler
        Captcha
        Log::Dispatch
        /
);

1;
