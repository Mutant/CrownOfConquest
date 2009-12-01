use strict;
use warnings;

package Test::RPG::DB;

use base qw(Test::RPG);

use RPG::Schema;

use Test::MockObject::Extends;

sub db_startup : Test(startup) {
    my $self = shift;

    return if $ENV{TEST_NO_DB};

    my $schema = RPG::Schema->connect( $self->{config}, "dbi:mysql:game-test", "root", "root", { AutoCommit => 0 }, );

    # Wrap in T::M::E so we can mock the config
    $schema = Test::MockObject::Extends->new($schema);
    $schema->fake_module( 'RPG::Schema', 'config' => sub { $self->{config} } );

    $self->{schema} = $schema;
}

sub aa_setup_context : Test(setup) {
    my $self = shift;

    $self->SUPER::aa_setup_context(@_);

    $self->{c}->mock(
        model => sub {
            my $resultset = $_[1];
            
            if ($resultset eq 'DBIC') {
                my $mock_model = Test::MockObject->new();
                $mock_model->set_always('schema', $self->{schema});
                return $mock_model;
            }
            
            $resultset =~ s/^DBIC:://;
            
            return $self->{mock_resultset}{$resultset} if $self->{mock_resultset}{$resultset};
            
            return $self->{schema}->resultset( $resultset );
        }
    );
}

sub roll_back : Test(teardown) {
    my $self = shift;
    
    if ($ENV{TEST_COMMIT}) {
        $self->{schema}->storage->dbh->commit;
    }
    else {    
        $self->{schema}->storage->dbh->rollback;
    }    
    
}

1;
