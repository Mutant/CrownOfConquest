package RPG::Model::DBIC;

use strict;
use warnings;

use base qw/Catalyst::Model::DBIC::Schema/;

__PACKAGE__->config->{schema_class} = 'RPG::Schema';

1;
