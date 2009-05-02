package RPG::Schema::Spell;
use base 'DBIx::Class';
use strict;
use warnings;

use Carp;

use RPG::Template;

__PACKAGE__->load_components(qw/ Core/);
__PACKAGE__->table('Spell');


__PACKAGE__->add_columns(qw/spell_id spell_name description points class_id combat non_combat target hidden/);

__PACKAGE__->set_primary_key('spell_id');

__PACKAGE__->belongs_to(
    'class',
    'RPG::Schema::Class',
    { 'foreign.class_id' => 'self.class_id' }
);

__PACKAGE__->has_many(
    'memorised_spells',
    'RPG::Schema::Memorised_Spells',
    { 'foreign.spell_id' => 'self.spell_id' }
);

# Inflate the result as a class based on spell name
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

    return $ret;
}

sub _bless_into_type_class {
    my $self = shift;

    my $class = __PACKAGE__ . '::' . $self->spell_name;
    $class =~ s/ /_/g;

    $self->ensure_class_loaded($class);
    bless $self, $class;
    
    return $self;
}

sub cast {
	my $self = shift;
	my ($character, $target_id) = @_;
	
    confess "No target or character. ($character, $target_id)" unless $character && $target_id;

   	my $memorised_spell = $self->find_related(
   	    'memorised_spells',
   		{
   			character_id => $character->id,
   		}
   	);
   	
   	confess "Character has not memorised spell" if ! $memorised_spell || $memorised_spell->casts_left_today <= 0;

    my $target = $self->_inflate_target($target_id);
   	
   	my $result = $self->_cast($character, $target);
   	
   	$result->{spell_name} = $self->spell_name;
   	$result->{caster} = $character;
   	$result->{target} = $target;

   	$memorised_spell->number_cast_today($memorised_spell->number_cast_today+1);
   	$memorised_spell->update;
   	
   	return $result;
}

sub _inflate_target {
    my $self = shift;
    my $target_id = shift;
        
    my $schema_class = ucfirst($self->target);
    
    my $target = $self->result_source->schema->resultset($schema_class)->find($target_id);
    
    confess "Target id: $target_id could not be found in schema class: $schema_class" unless $target;
    
    return $target;
   
}

sub create_effect {
	my ($self, $params) = @_;

	my ($relationship_name, $search_field, $joining_table);
	
	if ($params->{target_type} eq 'character') {
		$search_field = 'character_id';
		$relationship_name = 'character_effect';
		$joining_table = 'Character_Effect';
	}
	else {
		$search_field = 'creature_id';
		$relationship_name = 'creature_effect';
		$joining_table = 'Creature_Effect';
	}
	
	my $schema = $self->result_source->schema;
	
	my $effect = $schema->resultset('Effect')->find_or_new(
		{
			"$relationship_name.$search_field" => $params->{target_id},
			effect_name => $params->{effect_name},
		},
		{
			join => $relationship_name,
		}
	);
	
	unless ($effect->in_storage) {
		$effect->insert;
		 $schema->resultset($joining_table)->create(
			{
				$search_field => $params->{target_id},
				effect_id => $effect->id,
			}
		);	
	}
	
	$effect->time_left(($effect->time_left || 0) + $params->{duration});
	$effect->modifier($params->{modifier});
	$effect->modified_stat($params->{modified_state});
	$effect->combat($params->{combat});
	$effect->update;
}

1;