#!/usr/bin/perl

use strict;
use warnings;

use MIME::Lite;
use YAML;

my $home = $ENV{RPG_HOME};

my $config = YAML::LoadFile("$home/rpg.yml");

my $errors = `grep '\\[error\\]' $home/log/debug.log.1`;

my $msg = MIME::Lite->new(
	From    => 'mutant.nz@gmail.com',
	To      => 'mutant.nz@gmail.com',
	Subject => '[Kingdoms] Daily error summary',
	Data    => $errors,
);
$msg->send( 'smtp', $config->{smtp_server}, Debug => 0, );
