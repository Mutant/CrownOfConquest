package RPG::M::DBIC;
use base qw/Catalyst::Model::DBIC::Schema/;

__PACKAGE__->config(
      schema_class => 'RPG::Schema',
      connect_info => [
                        "dbi:mysql:game",
                        "root",
                        "",
                        {AutoCommit => 0},
                      ]
);

RPG::Schema->config(RPG->config);