package RPG::Schema::Player;
use base 'DBIx::Class';
use strict;
use warnings;

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

);
__PACKAGE__->set_primary_key('player_id');

__PACKAGE__->has_many( 'parties', 'RPG::Schema::Party', 'player_id', { cascade_delete => 0 } );

1;
