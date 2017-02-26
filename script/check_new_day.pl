#!/usr/bin/perl

use strict;
use warnings;

use RPG::Schema;
use RPG::LoadConf;
use RPG::Email;

use DateTime::Format::Strptime;

my $config = RPG::LoadConf->load();

my $schema = RPG::Schema->connect( $config, $config->{'Model::DBIC'}{connect_info} );

my $conf_val = $schema->resultset('Conf')->find(
   {
       'conf_name' => 'Last Successful Ticker Run',
   },
);

exit unless $conf_val;

my $strp = DateTime::Format::Strptime->new(
    pattern   => '%FT%T',
);

my $dt = $strp->parse_datetime($conf_val->conf_value);

my $elapsed = $dt->delta_ms( DateTime->now() );

if ($elapsed->in_units('minutes') > 60) {
    RPG::Email->send(
        $config,
        {
            email   => $config->{send_email_from},
            subject => 'New Day Script Has Not Run Recently',
            body    => "The new day script has not run successfuly since $dt",
        },
    );
}