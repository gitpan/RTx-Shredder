package RTx::Shredder::Exception;


use Exception::Class;
use base Exception::Class::Base;

sub Fields
{
	return qw( message pid uid euid gid egid time trace package file line );
};

BEGIN
{
	my @fields = Fields;
	no strict 'refs';
	foreach my $f (@fields) {
		*{$f} = sub { my $s = shift; return $s->{$f}; };
	}
	__PACKAGE__->NoRefs(0);
	__PACKAGE__->Trace(1);
}

sub full_message
{
	my $self = shift;

	return "Message: '".$self->message . "'\n";
}

1;

