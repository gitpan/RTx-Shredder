package RTx::Shredder::Exception;

use warnings;
use strict;

use Exception::Class;
use base qw(Exception::Class::Base);

BEGIN {
    __PACKAGE__->NoRefs(0);
}

#sub NoRefs { return 0 }
sub show_trace { return 1 }

package RTx::Shredder::Exception::Info;

use base qw(RTx::Shredder::Exception);

my %DESCRIPTION = (
    DependenciesLimit => <<END,
Dependecies list have reached its limit.
See \$RT::DependenciesLimit in RTx::Shredder docs.
END

    SystemObject => <<END,
System object was requested for deletion, shredder couldn't
do that because system would be unusable than.
END

);

sub full_message {
    my $self = shift;
    my $error = $self->message;
    return $DESCRIPTION{$error} || $error;
}

sub show_trace { return 0 }

1;
