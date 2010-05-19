# $Id$
# Copyright 2010 Philip Gwyn.  All rights reserved
##############################################################################
package POEx::IKC::Queue;

use strict;
use warnings;

our $VERSION = '0.0001';
$VERSION = eval $VERSION;  # see L<perlmodstyle>

use POE::Session::PlainCall;
# use POEx::IKC::Connection;  # XXX to be implemented
use POEx::URI;
use Storable;


##########################################################
sub spawn
{
    my( $package, $name, $config ) = @_;
    return POE::Session::PlainCall->create( 
                'package' => $package,
                ctor_args  => [ $name, $config ],
                events    => [ qw( _start _stop 
                                   __shutdown
                                   _default QUACK
                                   __connect __disconnect
                             ) ],
            )->ID;
}

##########################################################
sub new
{
    my( $package, $name, $config ) = @_;
    $name = URI->new( $name );
    my $alias = URI->new( 'poe:' );
    $alias->kernel( $name->kernel );
    $alias->session( $name->session );
    $alias->event( undef );
    my $self = bless { name   => $name, 
                       alias  => "$alias",
                       kernel => join( ':', $name->host, $name->port ),
                       Q      => {},    # this is the queue
                       REQNO  => 0,     # these are the keys to the queue
                       connected => 0   # IKC connection state
                     };

    $self->__init( $config );
    return $self;
}

##########################################################
## Pull the config data from $config
## Such as :
##  - store to disk?
##  - errors to parent?  sender?
##  - acknowledge to parent?  sender?
##  - needed to retransmit to parent?  sender?
##  - disconnect/connect should be handled by POEx::IKC::Connection or 
##          IKC monitoring
sub __init
{
    my( $self,  $config ) = @_;
}


##########################################################
sub _start
{
    my( $self ) = @_;
    poe->kernel->sig( shutdown => '__shutdown' );
    # Sessions will talk to us through this
    poe->kernel->alias_set( $self->{alias} );
    # Find out when the remote kernel connects/disconnects
    poe->kernel->post( IKC => 'monitor', 
                        $self->{kernel},   
                       { register => '_connect',
                         unregister => '_disconnect'
                     } );
    # Allow remote kernel to ACK our requests
    poe->kernel->post( IKC => 'publish', '', [ qw( QUACK ) ] );
    # XXX make sure that POEx::IKC::Connection will recognize multiple spawns
    # for the same remote kernel.
    $self->{CONN} = 
        POEx::IKC::Connection->spawn( $self->{kernel} );    # XXX still to be written
}

##########################################################
sub __shutdown
{
    my( $self ) = @_;
    if( $self->{CONN} ) {
        $self->{CONN}->shutdown;
        delete $self->{CONN};
    }
    poe->kernel->alias_remove( delete $self->{alias} ) if $self->{alias};
}

##########################################################
sub _stop
{
    my( $self ) = @_;
    if( $self->{CONN} ) {
        $self->{CONN}->shutdown;
        delete $self->{CONN};
    }
}

##########################################################
## IKC remote kernel registered
sub __connect
{
    my( $self ) = @_;
    $self->{connected} = 1;
    foreach my $reqno ( sort keys %{ $self->{Q} } ) {
        my $req = $self->{Q}{ $reqno };
        $self->__post( $req );
        # XXX maybe tell $req->{sender} about the retransmit
    }
}

##########################################################
## IKC remote kernel unregistered
sub __disconnect
{
    my( $self ) = @_;
    $self->{connected} = 0;
    # XXX maybe tell all $req->{sender} about the delay
}

##########################################################
## Local session posting to a remote session
sub _default
{
    my( $self, $state, $args ) = @_;
    my $req = { 
                dest=>{ kernel  => $self->{name}->kernel,
                        session => $self->{name}->session,
                        state   => $state
                      },
                params => freeze( $args ),
                reqno  => $self->{REQNO}++,
                sender => poe->sender
              };
    $self->__enqueue( $req );
    $self->__post( $req ) if $self->{connected};
}

##########################################################
## Send a request via IKC
sub __post
{
    my( $self, $req ) = @_;
    $poe_kernel->post( IKC => 'acked_post',     # XXX add this to IKC::Responder
                       $req->{dest}, thaw( $req->{params} ), 
                       { session=>$self->{alias}, state=>'QUACK' }
                     );
}

##########################################################
## Add a request to the queue
sub __enqueue
{
    my( $self, $req ) = @_;
    # XXX maybe we don't really want to enqueue this request
    # XXX maybe this request should be saved to disk
    $self->{Q}{ $req->{reqno} } = $req;
}

##########################################################
## Remote Responder acknowledged a request
## NB : QUACK == QUeue ACKnowledge
sub QUACK
{
    my( $self, $reqno ) = @_;
    my $req = delete $self->{Q}{ $reqno };
    unless( $req ) {
        # XXX duplicate or suprious ACK.  Tell somebody?
        return
    }

    # XXX maybe tell $req->{sender} about the ACK?
}

1;

__END__

=head1 NAME

POEx::IKC::Queue - IKC Queue implementation

=head1 SYNOPSIS

    use POEx::IKC::Queue;

    POEx::IKC::Queue->spawn( 'poe://timelord/honk', $lenient_config );
    $poe_kernel->post( 'poe://timelord/honk', honk => $honk );

    POEx::IKC::Queue->spawn( 'poe://bank/account', $stringent_config );
    $poe_kernel->post( 'poe://bank/account', add => $one_round_tuit );

=head1 DESCRIPTION

This is a stub of POEx::IKC::Queue.  So that I can get the ideas out of my head
and onto paper (or electrons) as it were.



=head1 SEE ALSO

L<POE>, L<POEx::URI>, L<POE::Component::IKC>, L<POEx::IKC::Connection>.

=head1 AUTHOR

Philip Gwyn, E<lt>gwyn-at-cpan.org<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Philip Gwyn

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
