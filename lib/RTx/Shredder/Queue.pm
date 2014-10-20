use RT::Queue ();
package RT::Queue;

use strict;
use warnings;
use warnings FATAL => 'redefine';

use RTx::Shredder::Constants;
use RTx::Shredder::Exceptions;
use RTx::Shredder::Dependencies;

sub __DependsOn
{
    my $self = shift;
    my %args = (
            Shredder => undef,
            Dependencies => undef,
            @_,
           );
    my $deps = $args{'Dependencies'};
    my $list = [];

# Tickets
    my $objs = RT::Tickets->new( $self->CurrentUser );
    $objs->{'allow_deleted_search'} = 1;
    $objs->Limit( FIELD => 'Queue', VALUE => $self->Id );
    push( @$list, $objs );

# Queue role groups( Cc, AdminCc )
    $objs = RT::Groups->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Domain', VALUE => 'RT::Queue-Role' );
    $objs->Limit( FIELD => 'Instance', VALUE => $self->Id );
    push( @$list, $objs );

# Scrips
    $objs = RT::Scrips->new( $self->CurrentUser );
    $objs->LimitToQueue( $self->id );
    push( @$list, $objs );

# Templates
    $objs = $self->Templates;
    push( @$list, $objs );

# Custom Fields
    $objs = RT::CustomFields->new( $self->CurrentUser );
    $objs->Limit( FIELD => 'Queue', VALUE => $self->id );
    push( @$list, $objs );

    $deps->_PushDependencies(
            BaseObject => $self,
            Flags => DEPENDS_ON,
            TargetObjects => $list,
            Shredder => $args{'Shredder'}
        );
    return $self->SUPER::__DependsOn( %args );
}

1;
