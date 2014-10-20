package RTx::Shredder::Plugin::Tickets;

use strict;
use warnings FATAL => 'all';
use base qw(RTx::Shredder::Plugin::Base);

=head1 NAME

RTx::Shredder::Plugin::Tickets - search plugin for wiping tickets.

=cut

sub Type { return 'search' }

=head1 ARGUMENTS

=head2 queue - queue name

Search tickets only in particular queue.

=head2 status - ticket status

Search tickets with specified status only.
'deleted' status is also supported.

=head2 updated_before - date

Search tickets that were updated before some date.
Example: '2003-12-31 23:59:59'

=cut

sub SupportArgs { return $_[0]->SUPER::SupportArgs, qw(queue status updated_before) }

sub TestArgs
{
    my $self = shift;
    my %args = @_;
    my $queue;
    if( $args{'queue'} ) {
        $queue = RT::Queue->new( $RT::SystemUser );
        $queue->Load( $args{'queue'} );
        return( 0, "Couldn't load queue '$args{'queue'}'" ) unless $queue->id;
    }
    if( $args{'status'} ) {
        $queue ||= RT::Queue->new( $RT::SystemUser );
        my @statuses = qw(new open stalled deleted rejected);
        if( $queue->can( 'StatusArray' ) ) {
            @statuses = $queue->StatusArray;
        }
        unless( grep $_ eq $args{'status'}, @statuses ) {
            return( 0, "Invalid status '$args{status}'" );
        }
    }
    if( $args{'updated_before'} ) {
        unless( $args{'updated_before'} =~ /\d\d\d\d-\d\d-\d\d(?:\s\d\d:\d\d:\d\d)?/ ) {
            return( 0, "Invalid date '$args{updated_before}'" );
        }
    }
    return $self->SUPER::TestArgs( %args );
}

sub Run
{
    my $self = shift;
    my $objs = RT::Tickets->new( $RT::SystemUser );
    $objs->{'allow_deleted_search'} = 1;
    if( $self->{'opt'}{'status'} ) {
        $objs->LimitStatus( VALUE => $self->{'opt'}{'status'} );
    }
    if( $self->{'opt'}{'queue'} ) {
        $objs->LimitQueue( VALUE => $self->{'opt'}{'queue'} );
    }
    if( $self->{'opt'}{'updated_before'} ) {
        $objs->LimitLastUpdated( OPERATOR => '<',
                        VALUE => $self->{'opt'}{'updated_before'},
                      );
    }
    if( $self->{'opt'}{'limit'} ) {
        $objs->RowsPerPage( $self->{'opt'}{'limit'} );
    }
    $objs->OrderByCols( { FIELD => 'id', ORDER => 'ASC' } );
    return (1, $objs);
}

1;
