#!/usr/bin/env plackup
 
use strict;
use warnings;
 
use RPG;
use Plack::Builder;
 
builder {
	mount '/' => RPG->psgi_app; 
};