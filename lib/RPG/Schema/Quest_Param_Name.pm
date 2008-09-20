package RPG::Schema::Quest_Param_Name;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Quest_Param_Name');

__PACKAGE__->add_columns(qw/quest_param_name_id quest_param_name quest_type_id/);
__PACKAGE__->set_primary_key('quest_param_name_id');

1;