package RTx::Shredder;
use strict;
use warnings;

=head1 NAME

RTx::Shredder - Cleanup RT database

=head1 SYNOPSIS

=head2 CLI

  rtx-shredder --force --plugin Tickets=queue,general;status,deleted

=head2 API

Same action as in CLI example, but from perl script:

  use RTx::Shredder;
  RTx::Shredder::Init( force => 1 );
  my $deleted = RT::Tickets->new( $RT::SystemUser );
  $deleted->{'allow_deleted_search'} = 1;
  $deleted->LimitQueue( VALUE => 'general' );
  $deleted->LimitStatus( VALUE => 'deleted' );
  while( my $t = $deleted->Next ) {
      $t->Wipeout;
  }

=head1 DESCRIPTION

RTx::Shredder is extention to RT API which allow you to delete data
from RT database.

=head2 Command line tools(CLI)

L<rtx-shredder> script that is shipped with the distribution allow
you to delete objects from command line or with system tasks
scheduler(cron or other).

=head2 Web based interface(WebUI)

Shredder's WebUI integrates into RT's WebUI and you can find it
under Configuration->Tools->Shredder tab. This interface is similar
to CLI and give you the same functionality, but it's available
from browser.

=head2 API

L<RTx::Shredder> modules is extension to RT API which add(push) methods
into base RT classes. API is not well documented yet, but you can find
usage examples in L<rtx-shredder> script code and in F<t/*> files.

=head1 CONFIGURATION

=head2 $RT::DependenciesLimit

Shredder stops with error if object has more then C<$RT::DependenciesLimit>
dependencies. By default this value is 1000. For example: ticket has 1000
transactions or transaction has 1000 attachments. This is protection
from bugs in shredder code, but sometimes when you have big mail loops
you may hit it. You can change default value, in
C<RT_SiteConfig.pm> add C<Set( $DependenciesLimit, new_limit );>

=head1 METHODS

=head2 Dependencies

Dependencies method implementend in each RT class which Shredder can delete.
Now Shredder support wipe out of Ticket, Transaction, Attachment,
ObjectCustomFieldValue, Principal, ACE, Group, GroupMember,
CachedGroupMember.

=head1 NOTES

=head2 Database transactions support

Database transactions unsupported yet, so it's only save when all other
interactions with RT DB are stopped. For example if you are going to
wipe ticket that was deleted an year ago then it's probably ok to run
shredder on it, but if you're going to delete some actively used object
then it's better to stop http server.

=head2 Foreign keys

This two keys don't allow delete Tickets because of bug in MySQL

  ALTER TABLE Tickets ADD FOREIGN KEY (EffectiveId) REFERENCES Tickets(id);
  ALTER TABLE CachedGroupMembers ADD FOREIGN KEY (Via) REFERENCES CachedGroupMembers(id);

L<http://bugs.mysql.com/bug.php?id=4042>

=head1 TESTING

Read more about testing in F<t/utils.pl>.

=head1 BUGS AND HOW TO CONTRIBUTE

I need your feedback in all cases: if you use it or not,
is it works for you or not.

=head2 Documentation

Many bugs in the docs: insanity, spelling, gramar and so on.
Patches are wellcome.

=head2 Todo

Please, see Todo file, it has some technical notes
about what I plan to do, when I'll do it, also it
describes some problems code has.

=head2 Repository

You can find repository of this project at
L<https://opensvn.csie.org/rtx_shredder>

=head1 AUTHOR

	Ruslan U. Zakirov <Ruslan.Zakirov@gmail.com>

=head1 COPYRIGHT

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
Perl distribution.

=head1 SEE ALSO

L<rtx-shredder>, L<rtx-validator>

=cut

our $VERSION = '0.03';
use POSIX ();
use File::Spec ();


BEGIN {
# I can't use 'use lib' here since it breakes tests
# because test suite uses old RTx::Shredder setup from
# RT lib path

### after:	push @INC, qw(@RT_LIB_PATH@);
	push @INC, qw(/opt/rt3/local/lib /opt/rt3/lib);
	use RTx::Shredder::Constants;

	require RT;

	require RTx::Shredder::Record;

	require RTx::Shredder::ACE;
	require RTx::Shredder::Attachment;
	require RTx::Shredder::CachedGroupMember;
	require RTx::Shredder::CustomField;
	require RTx::Shredder::CustomFieldValue;
	require RTx::Shredder::GroupMember;
	require RTx::Shredder::Group;
	require RTx::Shredder::Link;
	require RTx::Shredder::Principal;
	require RTx::Shredder::Queue;
	require RTx::Shredder::Scrip;
	require RTx::Shredder::ScripAction;
	require RTx::Shredder::ScripCondition;
	require RTx::Shredder::Template;
	require RTx::Shredder::ObjectCustomFieldValue;
	require RTx::Shredder::Ticket;
	require RTx::Shredder::Transaction;
	require RTx::Shredder::User;
}

our @SUPPORTED_OBJECTS = qw(
	ACE
	Attachment
	CachedGroupMember
	CustomField
	CustomFieldValue
	GroupMember
	Group
	Link
	Principal
	Queue
	Scrip
	ScripAction
	ScripCondition
	Template
	ObjectCustomFieldValue
	Ticket
	Transaction
	User
);

our %opt = ();

sub Init
{
	%opt = @_;
	RT::LoadConfig();
	RT::Init();
}

sub new
{
	my $proto = shift;
	my $self = bless( {}, ref $proto || $proto );
	$self->_Init( @_ );
	return $self;
}

sub _Init
{
	my $self = shift;
	my %args = (
			%opt,
			@_
		   );
	$self->{'opt'} = \%args;
	$self->{'cache'} = {};
	$self->{'resolver'} = {};
}

sub CastObjectsToRecords
{
	my $self = shift;
	my %args = ( Objects => undef, @_ );

	my @res;
	my $targets = delete $args{'Objects'};
	unless( $targets ) {
		RTx::Shredder::Exception->throw( "Undefined Objects argument" );
	}

	if( UNIVERSAL::isa( $targets, 'RT::SearchBuilder' ) ) {
		while( my $tmp = $targets->Next ) { push @res, $tmp };
	} elsif ( UNIVERSAL::isa( $targets, 'RT::Record' ) ) {
		push @res, $targets;
	} elsif ( UNIVERSAL::isa( $targets, 'ARRAY' ) ) {
		foreach( @$targets ) {
			push @res, $self->CastObjectsToRecords( Objects => $_ );
		}
	} elsif ( UNIVERSAL::isa( $targets, 'SCALAR' ) || !ref $targets ) {
		$targets = $$targets if ref $targets;
		my ($class, $id) = split /-/, $targets;
		$class = 'RT::'. $class unless $class =~ /^RTx?::/i;
		eval "require $class";
		die "Couldn't load '$class' module" if $@;
		my $obj = $class->new( $RT::SystemUser );
		die "Couldn't construct new '$class' object" unless $obj;
		$obj->Load( $id );
		die "Couldn't load '$class' object by id '$id'" unless $obj->id;
		die "Loaded object has different id" unless( $id eq $obj->id );
		push @res, $obj;
	} else {
		RTx::Shredder::Exception->throw( "Unsupported type ". ref $targets );
	}
	return @res;
}

sub PutObjects
{
	my $self = shift;
	my %args = ( Objects => undef, @_ );

	for( $self->CastObjectsToRecords( Objects => delete $args{'Objects'} ) ) {
		$self->PutObject( %args, Object => $_ )
	}

	return;
}

sub PutObject
{
	my $self = shift;
	my %args = (
			Object => undef,
			@_
		   );

	my $obj = $args{'Object'};
	unless( UNIVERSAL::isa( $obj, 'RT::Record' ) ) {
		RTx::Shredder::Exception->throw( "Unsupported type ". (ref $obj || $obj) );
	}

	my $str = $obj->_AsString;

	return $self->{'cache'}->{ $str } if( $self->{'cache'}->{ $str } );

	my $rec = {
                State => ON_STACK,
                Object => $obj,
        };
	$self->{'cache'}->{ $str } = $rec;
	return $rec;
}

sub _ParseRefStrArgs
{
	my $self = shift;
	my %args = (
		String => '',
		Object => undef,
		@_
	);
	if( $args{'String'} && $args{'Object'} ) {
		require Carp;
		Carp::croak( "both String and Object args passed" );
	}
	return $args{'String'} if $args{'String'};
	return $args{'Object'}->_AsString if UNIVERSAL::can($args{'Object'}, '_AsString' );
	return '';
}

sub GetObject { return (shift)->GetRecord( @_ )->{'Object'} }
sub GetState { return (shift)->GetRecord( @_ )->{'State'} }
sub GetRecord
{
	my $self = shift;
	my $str = $self->_ParseRefStrArgs( @_ );
	return $self->{'cache'}->{ $str };
}

sub PutResolver
{
	my $self = shift;
	my %args = (
		BaseClass => '',
		TargetClass => '',
		Code => undef,
		@_,
	);

	$self->{'resolver'}->{ $args{'BaseClass'} }->{ $args{'TargetClass'} || '' } =
			$args{'Code'};
	
	return;
}

sub GetResolver
{
	my $self = shift;
	my %args = (
		BaseClass => '',
		TargetClass => '',
		@_,
	);

	my $resolver = $self->{'resolver'}->{ $args{'BaseClass'} }->{ $args{'TargetClass'} || '' };
	$resolver ||= $self->{'resolver'}->{ $args{'BaseClass'} }->{''};
	
	return $resolver;
}

sub DumpSQL
{
	my $self = shift;
	my %args = (
		Query => undef,
		@_
	);
	return unless exists $self->{opt}->{sqldump};
	my $fh = $self->{opt}->{sqldump};
	print $fh $args{'Query'};
	print $fh "\n" unless $args{'Query'} =~ /\n$/;
	return;
}

sub Wipeout
{
	my $self = shift;
	my %args = ( @_ );

	foreach my $record( values %{ $self->{'cache'} } ) {
		next if( $record->{'State'} & WIPED );
		$record->{'Object'}->Wipeout( Shredder => $self );
	}
}

sub ValidateRelations
{
	my $self = shift;
	my %args = ( @_ );

	foreach my $record( values %{ $self->{'cache'} } ) {
		next if( $record->{'State'} & VALID );
		$record->{'Object'}->ValidateRelations( Shredder => $self );
	}
}

sub GetFileHandle
{
	my $self = shift;
	my $file = shift;
	if( $file =~ /XXXX[^\/\\]*$/ ) {
		#file mask
		my( $tmp, $i ) = ( $file, 0 );
		do {
			$i++;
			$tmp = $file;
			$tmp =~ s/XXXX([^\/\\]*)$/sprintf("%04d", $i).$1/e;
		} while( -e $tmp && $i < 9999 );
		$file = $tmp;
	}
	if( -f $file ) {
		unless( -w $file ) {
			die "File '$file' exists, but is read-only";
		}
	} elsif( !-e $file ) {
		unless( File::Spec->file_name_is_absolute( $file ) ) {
			$file = File::Spec->rel2abs( $file ) ;
		}
		#file base dir
		my $dir = File::Spec->join( (File::Spec->splitpath( $file ))[0,1] );
		unless( -e $dir && -d _) {
			die "Base directory '$dir' for file '$file' doesn't exist";
		}
		unless( -w $dir ) {
			die "Base directory '$dir' is not writable";
		}
	} else {
		die "'$file' is not regular file";
	}
	if( -s $file ) {
		print STDERR "WARNING: file '$file' is not empty, content would be overwriten\n";
		exit(0) unless $opt{force} || prompt_yN( "Do you want to proceed?" );
	}
	open my $fh, ">$file" or die "Couldn't open '$file' for write: $!";
	return $fh;
}

sub GetFileFromStorage
{
	my $self = shift;
	my $name = shift;
	my $path = File::Spec->catfile( $self->StoragePath,
				        $name || POSIX::strftime("%Y%m%dT%H%M%S-XXXX.sql", gmtime )
				      );
	return $self->GetFileHandle( $path );
}

sub StoragePath
{
	return File::Spec->catdir($RT::VarPath, qw(data RTx-Shredder) );
}

1;
__END__
