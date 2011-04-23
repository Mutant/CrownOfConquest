package RPG::Schema::Quest_Type;
use base 'DBIx::Class';
use strict;
use warnings;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Quest_Type');

__PACKAGE__->add_columns(qw/quest_type_id quest_type hidden description long_desc/);
__PACKAGE__->set_primary_key('quest_type_id');

__PACKAGE__->has_many(
    'quest_param_names',
    'RPG::Schema::Quest_Param_Name',
    { 'foreign.quest_type_id' => 'self.quest_type_id' }
);

sub min_level {
    my $package = shift;
    
    my $type = ref $package ? $package->quest_type : shift;
    
    my %minimum_levels = (
        claim_land => RPG::Schema->config->{minimum_land_claim_level},
        construct_building => RPG::Schema->config->{minimum_building_level},
        take_over_town => RPG::Schema->config->{minimum_raid_level},
        create_garrison => RPG::Schema->config->{minimum_garrison_level},
    );
    
    return $minimum_levels{$type} || 1;
}

1;