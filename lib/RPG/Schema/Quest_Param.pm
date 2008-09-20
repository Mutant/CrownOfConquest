package RPG::Schema::Quest_Param;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Quest_Param');

__PACKAGE__->add_columns(qw/quest_param_id start_value current_value quest_param_name_id quest_id/);
__PACKAGE__->set_primary_key('quest_param_id');

1;