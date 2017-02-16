#!/usr/bin/env plackup
 
use strict;
use warnings;

use lib "$ENV{RPG_HOME}/lib"; 
 
use RPG;
use Plack::Builder;
 
builder {
	mount '/' => RPG->psgi_app; 
};