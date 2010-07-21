package RPG::Schema::Quest_Type;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Quest_Type');

__PACKAGE__->add_columns(qw/quest_type_id quest_type hidden/);
__PACKAGE__->set_primary_key('quest_type_id');

__PACKAGE__->has_many(
    'quest_param_names',
    'RPG::Schema::Quest_Param_Name',
    { 'foreign.quest_type_id' => 'self.quest_type_id' }
);

1;