package RPG::Combat::GarrisonBattle;

use Moose::Role;

use Data::Dumper;
use RPG::Template;

requires qw/garrison/;

sub garrison_flee {
	my $self = shift;
	
	foreach my $item ($self->garrison->items) {
		$item->garrison_id(undef);
		$item->land_id($self->location->id);
		$item->update;		
	}
	$self->garrison->gold(0);
	$self->garrison->update;		
}

sub wipe_out_garrison {
	my $self = shift;
	
	my $garrison = $self->garrison;
	my $today = $self->schema->resultset('Day')->find_today;
	
	my $wiped_out_message = RPG::Template->process(
		$self->config,
		'garrison/wiped_out.html',
		{
			garrison => $garrison,
			combat_log => $self->combat_log,
			opp_num => $self->opponent_number_of_group($garrison),
		}
	);
	
	$self->schema->resultset('Party_Messages')->create(
		{
			message => $wiped_out_message,
			alert_party => 1,
			party_id => $garrison->party_id,
			day_id => $today->id,
		}
	);
	
	my @characters = $garrison->characters;
   	foreach my $character (@characters) {
		$self->schema->resultset('Grave')->create(
			{
				character_name => $character->character_name,
				land_id        => $self->location->id,
				day_created    => $today->day_number,
				epitaph        => "Killed while valiantly fighting in a garrison for " . $character->pronoun('posessive-subjective') . " party",
			}
		);
   		
   		$character->garrison_id(undef);
   		$character->party_id(undef);
   		$character->update;
   	}
    	
   	$garrison->land_id(undef);
   	$garrison->update;
}

around '_build_combat_factors' => sub {
    my $orig = shift;
    my $self = shift;    
    
    my $combat_factors = $self->$orig(@_);

    my ( $refresh_type, $id ) = @_;
    
    return $combat_factors if defined $refresh_type && $refresh_type ne 'character'; 
   

    # Check if the garrison is in the same sector as a building. If so, add something to all their defence factors
    my $building = $self->schema->resultset('Building')->find(
        {
            land_id => $self->location->id,
        },
        {
            prefetch => 'building_type',
        },
    );
    
    # TODO: need to check the garrison is the owner? Or are they always the owner if they're in the sector?
    
    if ($building) {
        foreach my $character ($self->garrison->characters) {
            next if defined $id && $id != $character->id;
            
            $combat_factors->{character}{ $character->id }{af} += $building->building_type->attack_factor;
            $combat_factors->{character}{ $character->id }{df} += $building->building_type->defense_factor;
     
        }   
    }
    
    return $combat_factors;
};

1;