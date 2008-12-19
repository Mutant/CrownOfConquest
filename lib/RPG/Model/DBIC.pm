package RPG::Model::DBIC;

use strict;
use warnings;

use base qw/Catalyst::Model::DBIC::Schema/;

__PACKAGE__->config(
 schema_class => 'RPG::Schema',
 connect_info => [
  "dbi:mysql:game",
  "root",
  "root",
  { AutoCommit => 0 }
 ]
);

1;
