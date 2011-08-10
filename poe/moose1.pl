#!/usr/bin/env perl
use 5.10.0;

{

    package Counter;
    use MooseX::POE;

    has count => (
        isa     => 'Int',
        is      => 'rw',
        default => 1,
    );

    has id => ( is => 'ro' );

    sub START {
        my ( $self, $kernel, $session ) = @_[ OBJECT, KERNEL, SESSION ];
        say 'Starting '.$self->id;
        $self->yield('dec');
    }

    event inc => sub {
        my ($self) = $_[OBJECT];
        say 'Count '.$self->id . ':' . $self->count;
        $self->count( $self->count + 1 );
        return if 3 < $self->count;
        $self->yield('inc');
    };

    # POE::Stage compatibility ... you can name events on_* and they'll get triggered
    sub on_dec {
        my ($self) = $_[OBJECT];
        say 'Count '.$self->id . ':' . $self->count;
        $self->count( $self->count - 1 );
        $self->yield('inc');
    }

    sub STOP {
        say 'Stopping '.$_[0]->id;
    }

    no MooseX::POE;
}

my @objs = map { Counter->new( id => $_ ) } ( 1 .. 10 );
POE::Kernel->run();
