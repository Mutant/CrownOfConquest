package RPG::Schema::Quest;
use base 'DBIx::Class';
use strict;
use warnings;

use Data::Dumper;
use Carp;
use RPG::Template;

__PACKAGE__->load_components(qw/Numeric Core/);
__PACKAGE__->table('Quest');

__PACKAGE__->resultset_class('RPG::ResultSet::Quest');

__PACKAGE__->add_columns(qw/quest_id party_id town_id kingdom_id quest_type_id complete gold_value xp_value min_level status days_to_complete day_offered/);
__PACKAGE__->set_primary_key('quest_id');

__PACKAGE__->belongs_to( 'type', 'RPG::Schema::Quest_Type', { 'foreign.quest_type_id' => 'self.quest_type_id' } );

__PACKAGE__->belongs_to( 'town', 'RPG::Schema::Town', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->belongs_to( 'kingdom', 'RPG::Schema::Kingdom', 'kingdom_id' );

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', { 'foreign.party_id' => 'self.party_id' } );

__PACKAGE__->belongs_to( 'day_offered_rec', 'RPG::Schema::Day', { 'foreign.day_id' => 'self.day_offered' } );

__PACKAGE__->has_many( 'quest_params', 'RPG::Schema::Quest_Param', { 'foreign.quest_id' => 'self.quest_id' } );

__PACKAGE__->numeric_columns(
	gold_value => {
		min_value => 0,
	},
);

my %QUEST_TYPE_TO_CLASS_MAP = (
    kill_creatures_near_town => 'RPG::Schema::Quest::Kill_Creatures_Near_Town',
    find_jewel               => 'RPG::Schema::Quest::Find_Jewel',
    msg_to_town              => 'RPG::Schema::Quest::Msg_To_Town',
    destroy_orb              => 'RPG::Schema::Quest::Destroy_Orb',
    raid_town                => 'RPG::Schema::Quest::Raid_Town',
    find_dungeon_item        => 'RPG::Schema::Quest::Find_Dungeon_Item',
    construct_building       => 'RPG::Schema::Quest::Construct_Building',
    claim_land               => 'RPG::Schema::Quest::Claim_Land',
    take_over_town           => 'RPG::Schema::Quest::Take_Over_Town',
    create_garrison          => 'RPG::Schema::Quest::Create_Garrison',
);

# Inflate the result as a class based on quest type
sub inflate_result {
    my $self = shift;

    my $ret = $self->next::method(@_);

    $ret->_bless_into_type_class;

    return $ret;
}

sub new {
    my ( $pkg, @args ) = @_;
    
    my $params = delete $args[0]->{params};

    my $self = $pkg->next::method(@args);
    
    $self->{_params} = $params;

    return $self;

}

sub insert {
    my ( $self, @args ) = @_;
    
    my $ret = $self->next::method(@args);

    $ret->_bless_into_type_class;

    if (! $self->{_params}) {
        $self->set_quest_params;
    }
    else {
        $self->insert_params($self->{_params});
    }
    return $ret;
}

sub create_party_offer_message {
    my $self = shift;
    
    if ($self->kingdom_id && $self->party_id) {    
        my $message = RPG::Template->process(
            RPG::Schema->config,
            'quest/kingdom/offered.html',
            {
                king => $self->kingdom->king,
                quest => $self,
            }                
        );
        
        $self->party->add_to_messages(
            {
                day_id => $self->day_offered,
                message => $message,
                alert_party => 1,
            }
        );      
    }    
}

sub delete {
    my ( $self, @args ) = @_;

	$self->cleanup;
	
    my $ret = $self->next::method(@args);

    return $ret;
}

sub _bless_into_type_class {
    my $self = shift;
    
    confess "Quest has no type!" unless $self->type;

    my $class = $QUEST_TYPE_TO_CLASS_MAP{ $self->type->quest_type };
    
    croak "Class not found for quest type: " . $self->type->quest_type unless $class;

    $self->ensure_class_loaded($class);
    bless $self, $class;

    $self->{_config} = RPG::Schema->config->{quest_type_vars}{ $self->type->quest_type };

    return $self;
}

sub insert_params {
    my $self = shift;
    my $params = shift;
    
    my @quest_params = $self->result_source->schema->resultset('Quest_Param_Name')->search(
        {
            quest_type_id => $self->quest_type_id,
        }
    );       
    
    foreach my $param (@quest_params) {
        my $value = $params->{$param->quest_param_name};
        
        unless (defined $value) {
            if (defined $param->default_val) {
                $value = $param->default_val;   
            }
            else {
                croak "No value for " . $param->quest_param_name . " when creating quest\n";
            }
        } 
        
        # Bit of validation
        if ($param->variable_type) {
            if ($param->variable_type ne 'int') {
                my $obj = $self->result_source->schema->resultset($param->variable_type)->find($value);
                croak "Invalid id for entity type " . $param->variable_type . " for quest param " . $param->quest_param_name . "\n"
                    unless $obj;
            }
            else {
                if ($param->min_val && $value < $param->min_val || $param->max_val && $value > $param->max_val) {
                    croak "Value " . $param->quest_param_name . " out of range of min/max\n";   
                }  
            }
        }
        
        $self->define_quest_param($param->quest_param_name, $value); 
    }
}

# Set a quest param for a new quest
#  Assumes start and current value are the same
sub define_quest_param {
    my $self       = shift;
    my $param_name = shift || croak "Param name not supplied";
    my $value      = shift;
    croak "Value not supplied" unless defined $value;

    my %quest_param_names = $self->quest_params_by_name;

    croak "Couldn't find param name " . $param_name . " for quest type " . $self->type->quest_type . "\n"
        unless $quest_param_names{$param_name};

    $self->add_to_quest_params(
        {
            quest_param_name_id => $quest_param_names{$param_name}->id,
            start_value         => $value,
            current_value       => $value,
        }
    );
}

sub param {
    my $self = shift;
    my $param_name = shift || croak "Param name not supplied";

    my $quest_param = $self->param_record($param_name);

    return ( $quest_param->start_value, $quest_param->current_value );
}

sub param_start_value {
    my $self = shift;
    my $param_name = shift || croak "Param name not supplied";

    return +( $self->param($param_name) )[0];
}

sub param_current_value {
    my $self = shift;
    my $param_name = shift || croak "Param name not supplied";

    return +( $self->param($param_name) )[1];
}

sub param_display_value {
    my $self = shift;
    my $param_name = shift || croak "Param name not supplied";
    
    my $rec = $self->param_record($param_name);
    
    my $value = $rec->current_value;
    
    my $param_name_rec = $rec->quest_param_name;
    
    if ($param_name_rec->variable_type && $param_name_rec->variable_type ne 'int') {
        my $obj = $self->result_source->schema->resultset($param_name_rec->variable_type)->find($rec->current_value);
        $value = $obj->label;
    }
    
    return $value;
}

sub param_record {
    my $self = shift;

    my $param_name = shift || croak "Param name not supplied";

    unless ( $self->{_param_records_by_name} ) {
        my %quest_params_by_name = $self->quest_params_by_name;
        my %quest_param_ids_to_names = map { $quest_params_by_name{$_}->id => $_ } keys %quest_params_by_name;

        my @quest_params = $self->quest_params;

        foreach my $quest_param (@quest_params) {
            my $name = $quest_param_ids_to_names{ $quest_param->quest_param_name_id };
            $self->{_param_records_by_name}{$name} = $quest_param;
        }
    }

    confess "Param name '$param_name' does not exist for this quest type" unless defined $self->{_param_records_by_name}{$param_name};

    return $self->{_param_records_by_name}{$param_name};
}

sub quest_params_by_name {
    my $self = shift;
    $self->{_quest_param_names} ||= { map { $_->quest_param_name => $_ } $self->type->quest_param_names };

    return %{ $self->{_quest_param_names} };
}

# This is called when an action from another party happens. Specfic quest types can define an action if they need to
sub check_action_from_another_party {}

# This returns which actions a quest is interested in, for the 'check_action_from_another_party' method. Should be overriden to return
#  a list of the actions a quest type is interested in (if any)
sub interested_in_actions {}

# Class method to get hash of quest types to a list of interested actions
sub interested_actions_by_quest_type {
    my $self = shift;
    
    my %actions_by_quest_type;
    while (my ($type, $class) = each %QUEST_TYPE_TO_CLASS_MAP) {
        $self->ensure_class_loaded($class);
        
        my @actions = $class->interested_in_actions;
        
        $actions_by_quest_type{$type} = \@actions;
    }
    
    return %actions_by_quest_type;
}

# Called when a quest is terminated (non-amicably)
sub terminate {
	my $self = shift;
	my %params = @_;
	
	my $message = $params{party_message};
	
    $self->status('Terminated');
	$self->cleanup;

	my $day = $self->result_source->schema->resultset('Day')->find_today;

	if ($message) {
	    $self->result_source->schema->resultset('Party_Messages')->create(
			{
				party_id    => $self->party_id,
	            message     => $message,
				alert_party => 1,
	            day_id      => $day->id,
	        }
		);
	}

    if ($self->town_id) {
    	my $party_town = $self->result_source->schema->resultset('Party_Town')->find_or_create(
        	{
    			town_id  => $self->town_id,
    			party_id => $self->party_id,
    		},
    	);
    	
    	$party_town->decrease_prestige(3);
    	$party_town->update;
    }
    
    if ($self->kingdom_id) {
        # Kingdom gets gold back
        my $kingdom = $self->kingdom;
        $kingdom->increase_gold($self->gold_value);
        $kingdom->update;
        
        my $kingdom_message = $params{kingdom_message};
        
        if ($kingdom_message && ! $kingdom->king->is_npc) {        
            $kingdom->add_to_messages(
                {
                    day_id => $day->id,
                    message => $kingdom_message,
                }
            );
        }

        my $party_kingdom = $self->result_source->schema->resultset('Party_Kingdom')->find_or_create(
            {
                kingdom_id  => $self->kingdom_id,
                party_id => $self->party_id,
            },
        );
        
        $party_kingdom->decrease_loyalty(1);
        $party_kingdom->update;          
        
    }
}


# Called when the quest is completed (i.e. in set_complete() below) 
sub finish_quest {}

# Returns the character group xp should be award to.
#  By default, it's the party, but a quest type can override thar
sub xp_awarded_to {
    my $self = shift;
    
    return $self->party;
    
}

sub set_complete {
    my $self = shift;

    my $party = $self->party;
    
    $self->finish_quest;
    
    $self->status('Complete');
    $self->update;
    
    $party->increase_gold($self->gold_value);
    $party->update;
    
    my $group = $self->xp_awarded_to;
    
    my $awarded_xp = int $self->xp_value / $group->number_alive;    
    my @details = $group->xp_gain($awarded_xp);
    
    if ($self->town_id) {
        my $party_town = $party->find_related(
            'party_towns',
            {
                town_id  => $self->town_id,
            },
        );
        
        unless ($party_town) {
            $party_town = $party->add_to_party_towns(
                {
                    town_id => $self->town_id,
                }
            );   
        }
        
        $party_town->increase_prestige(3);
        $party_town->update;        
        
        $self->town->increase_mayor_rating(3);
        $self->town->update;
        
        my $news_message = RPG::Template->process(
            RPG::Schema->config,
            'quest/completed_quest_news_message.html',
            { 
                party => $party,
                quest => $self, 
            }
        );
        
        $self->town->add_to_history(
            {
                day_id  => $self->result_source->schema->resultset('Day')->find_today->id,
                message => $news_message,
            }
        );    
        
    }
    elsif ($self->kingdom_id) {
        my $message = RPG::Template->process(
            RPG::Schema->config,
            'quest/kingdom/kingdom_completed.html',
            { 
                party => $party,
                quest => $self, 
            }
        );   
        
        $self->kingdom->add_to_messages(
            {
                day_id  => $self->result_source->schema->resultset('Day')->find_today->id,
                message => $message,
            }
        );
        
        my $party_kingdom = $self->result_source->schema->resultset('Party_Kingdom')->find_or_create(
            {
                kingdom_id  => $self->kingdom_id,
                party_id => $party->id,
            },
        );
        
        $party_kingdom->increase_loyalty(5);
        $party_kingdom->update;       
    }
    
    return @details;
}

# Called before deleting a quest
sub cleanup {}

# Entry point for calling quest actions
#  (Call rather than calling check_action on subclass)
sub check_quest_action {
    my $self = shift;
    my $action = shift;
    my @params = @_; 
    
    return unless $self->check_action( $self->party, $action, @params );
    
    my $message = RPG::Template->process(
        RPG::Schema->config,
        'quest/action_message.html',
        {
            quest  => $self,
            action => $action,
        },
    );   
    
    # Check if this action affects any other quests    
    my @quests = $self->result_source->schema->resultset('Quest')->find_quests_by_interested_action($action);
    
    foreach my $quest (@quests) {
        $quest->check_action_from_another_party( $self->party, $action, @params );
    }
    
    return $message;
}


1;
