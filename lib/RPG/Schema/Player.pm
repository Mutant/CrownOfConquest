package RPG::Schema::Player;
use base 'DBIx::Class';
use strict;
use warnings;

use RPG::DateTime;

__PACKAGE__->load_components(qw/InflateColumn::DateTime Core/);
__PACKAGE__->table('Player');

__PACKAGE__->add_columns(
    'player_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 1,
        'default_value'     => undef,
        'is_foreign_key'    => 0,
        'name'              => 'player_id',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'player_name' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'player_name',
        'is_nullable'       => 0,
        'size'              => '255'
    },
    'email' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'email',
        'is_nullable'       => 0,
        'size'              => '255'
    },
    'password' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'password',
        'is_nullable'       => 0,
        'size'              => '255'
    },
    'verified' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 0,
        'is_foreign_key'    => 0,
        'name'              => 'verified',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'verification_code' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'verification_code',
        'is_nullable'       => 0,
        'size'              => '255'
    },
    'admin_user' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 0,
        'is_foreign_key'    => 0,
        'name'              => 'admin_user',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'last_login' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => 0,
        'is_foreign_key'    => 0,
        'name'              => 'last_login',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'deleted' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 0,
        'is_foreign_key'    => 0,
        'name'              => 'deleted',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'warned_for_deletion' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 0,
        'is_foreign_key'    => 0,
        'name'              => 'warned_for_deletion',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'send_daily_report' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'send_daily_report',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'send_email_announcements' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'send_email_announcements',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'display_announcements' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'display_announcements',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'display_tip_of_the_day' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'display_tip_of_the_day',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'send_email' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'send_email',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'promo_code_id' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'promo_code_id',
        'is_nullable'       => 1,
        'size'              => '11'
    },
    'email_hash' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => '',
        'is_foreign_key'    => 0,
        'name'              => 'email_hash',
        'is_nullable'       => 0,
        'size'              => '255'
    },
    'referred_by' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'referred_by',
        'is_nullable'       => 1,
        'size'              => '11'
    },
    'refer_reward_given' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'refer_reward_given',
        'is_nullable'       => 1,
        'size'              => '11'
    },
    'screen_height' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'screen_height',
        'is_nullable'       => 1,
        'size'              => '255'
    },
    'screen_width' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'screen_width',
        'is_nullable'       => 1,
        'size'              => '255'
    },
    'created' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => 0,
        'is_foreign_key'    => 0,
        'name'              => 'created',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'display_town_leave_warning' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'display_town_leave_warning',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'bug_manager' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'bug_manager',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'contact_manager' => {
        'data_type'         => 'int',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'contact_manager',
        'is_nullable'       => 0,
        'size'              => '11'
    },
    'referer' => {
        'data_type'         => 'varchar',
        'is_auto_increment' => 0,
        'default_value'     => 1,
        'is_foreign_key'    => 0,
        'name'              => 'referer',
        'is_nullable'       => 0,
        'size'              => '2000'
    },
    'deleted_date' => {
        'data_type'         => 'datetime',
        'is_auto_increment' => 0,
        'default_value'     => 0,
        'is_foreign_key'    => 0,
        'name'              => 'deleted_date',
        'is_nullable'       => 0,
        'size'              => '11'
    },

);
__PACKAGE__->set_primary_key('player_id');

__PACKAGE__->has_many( 'parties', 'RPG::Schema::Party', 'player_id', { cascade_delete => 0 } );

__PACKAGE__->has_many( 'logins', 'RPG::Schema::Player_Login', 'player_id', );

__PACKAGE__->belongs_to( 'referred_by_player', 'RPG::Schema::Player', { 'foreign.player_id' => 'self.referred_by' } );

__PACKAGE__->might_have( 'active_party', 'RPG::Schema::Party', 'player_id', { where => { defunct => undef } } );

sub time_since_last_login {
    my $self = shift;

    return RPG::DateTime->time_since_datetime( $self->last_login );
}

sub has_ips_in_common_with {
    my $self         = shift;
    my $other_player = shift;

    return if $self->id == $other_player->id;

    return if RPG::Schema->config->{check_for_coop} == 0;

    my @logins = $self->search_related(
        'logins',
        {
            login_date => { '>=', DateTime->now()->subtract( days => RPG::Schema->config->{ip_coop_window} ) },
        }
    );

    my @ips = map { $_->ip } @logins;

    my $common_logins = $other_player->search_related(
        'logins',
        {
            ip => \@ips,
            login_date => { '>=', DateTime->now()->subtract( days => RPG::Schema->config->{ip_coop_window} ) },
        }
    )->count;

    return $common_logins >= 1 ? 1 : 0;
}

sub total_turns_used {
    my $self = shift;

    my $rs = $self->find_related(
        'parties',
        {},
        {
            'select' => { sum => 'turns_used' },
            'as' => 'total_turns_used',
        }
    );

    return $rs->get_column('total_turns_used');
}

sub login_count {
    my $self = shift;

    return $self->logins->count;
}

1;
