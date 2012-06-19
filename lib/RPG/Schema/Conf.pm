package RPG::Schema::Conf;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Conf');

__PACKAGE__->add_columns(qw/conf_name conf_value/);

__PACKAGE__->set_primary_key(qw/conf_name/);


1;