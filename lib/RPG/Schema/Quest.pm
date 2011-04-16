package RPG::Schema::Quest;
use base 'DBIx::Class';
use strict;
use warnings;

use Data::Dumper;
use Carp;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Quest');

__PACKAGE__->resultset_class('RPG::ResultSet::Quest');

__PACKAGE__->add_columns(qw/quest_id party_id town_id kingdom_id quest_type_id complete gold_value xp_value min_level status days_to_complete day_offered/);
__PACKAGE__->set_primary_key('quest_id');

__PACKAGE__->belongs_to( 'type', 'RPG::Schema::Quest_Type', { 'foreign.quest_type_id' => 'self.quest_type_id' } );

__PACKAGE__->belongs_to( 'town', 'RPG::Schema::Town', { 'foreign.town_id' => 'self.town_id' } );

__PACKAGE__->belongs_to( 'kingdom', 'RPG::Schema::Kingdom', 'kingdom_id' );

__PACKAGE__->belongs_to( 'party', 'RPG::Schema::Party', { 'foreign.party_id' => 'self.party_id' } );

__PACKAGE__->has_many( 'quest_params', 'RPG::Schema::Quest_Param', { 'foreign.quest_id' => 'self.quest_id' } );

my %QUEST_TYPE_TO_CLASS_MAP = (
    kill_creatures_near_town => 'RPG::Schema::Quest::Kill_Creatures_Near_Town',
    find_jewel               => 'RPG::Schema::Quest::Find_Jewel',
    msg_to_town              => 'RPG::Schema::Quest::Msg_To_Town',
    destroy_orb              => 'RPG::Schema::Quest::Destroy_Orb',
    raid_town                => 'RPG::Schema::Quest::Raid_Town',
    find_dungeon_item        => 'RPG::Schema::Quest::Find_Dungeon_Item',
    construct_building       => 'RPG::Schema::Quest::Construct_Building',
    claim_land               => 'RPG::Schema::Quest::Claim_Land',
);

# Inflate the result as a class based on quest type
sub inflate_result {
    my $self = shift;

    my $ret = $self->next::method(@_);

    $ret->_bless_into_type_class;

    return $ret;
}

sub insert {
    my ( $self, @args ) = @_;
	
    my $ret = $self->next::method(@args);

    $ret->_bless_into_type_class;

    $ret->set_quest_params;

    return $ret;
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
	my $message = shift;
	
    $self->status('Terminated');
	$self->cleanup;

	if ($message) {
		my $day = $self->result_source->schema->resultset('Day')->find_today;
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
}


# Called when the quest is completed (i.e. in complete() below) 
sub finish_quest {}

sub set_complete {
    my $self = shift;

    my $party = $self->party;
    
    $self->finish_quest;
    
    $self->status('Complete');
    $self->update;
    
    $party->increase_gold($self->gold_value);
    $party->update;
    
    my $awarded_xp = $self->xp_value / $party->number_alive;    
    my @details = $party->xp_gain($awarded_xp);
    
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
    
    return @details;
}

# Called before deleting a quest
sub cleanup {}

1;
