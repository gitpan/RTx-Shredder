package RTx::Shredder;
use strict;
use warnings;

=head1 NAME

RTx::Shredder - Cleanup RT database

=head1 SYNOPSIS

=head2 CLI

  rtx-shredder --force --plugin 'Tickets=queue,general;status,deleted'

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
from RT database. Now Shredder support wipe out of almost all RT objects
 (Tickets, Transactions, Attachments, Users...)

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
F<RT_SiteConfig.pm> add C<Set( $DependenciesLimit, new_limit );>

=head2 $RT::ShredderStoragePath

By default shredder saves dumps in F</path-to-RT-var-dir/data/RTx-Shredder>,
with this option you can change path, but B<note> that value should be absolute
path to the dir you want.

=head1 API DESCRIPTION

L<RTx::Shredder> class implements interfaces to objects cache, actions
on the objects in the cache and backups storage.

=head2 Dependencies

=cut

our $VERSION = '0.03_02';
use File::Spec ();


BEGIN {
# I can't use 'use lib' here since it breakes tests
# because test suite uses old RTx::Shredder setup from
# RT lib path

### after:     push @INC, qw(@RT_LIB_PATH@);
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

=head2 GENERIC

=head3 Init( %options )

Sets shredder defaults, loads RT config and init RT interface.

B<NOTE> that this is function and must be called with C<RTx::Shredder::Init();>.

B<TODO:> describe possible shredder options.

=cut

our %opt = ();

sub Init
{
    %opt = @_;
    RT::LoadConfig();
    RT::Init();
}

=head3 new( %options )

Shredder object constructor takes options hash and returns new object.

=cut

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
    $self->{'opt'} = { %opt, @_ };
    $self->{'cache'} = {};
    $self->{'resolver'} = {};
}

=head3 CastObjectsToRecords( Objects => undef )

Cast objects to the C<RT::Record> objects or its ancesstors.
Objects can be passed as SCALAR (format C<< <class>-<id> >>),
ARRAY, C<RT::Record> ancesstors or C<RT::SearchBuilder> ancesstor.

Most methods that takes C<Objects> argument use this method to
cast argument value to list of records.

Returns array of the records.

For example:

    my @objs = $shredder->CastObjectsToRecords(
        Objects => [             # ARRAY reference
            'RT::Attachment-10', # SCALAR or SCALAR reference
            $tickets,            # RT::Tickets object (isa RT::SearchBuilder)
            $user,               # RT::User object (isa RT::Record)
        ],
    );

=cut

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

=head2 OBJECTS CACHE

=head3 PutObjects( Objects => undef )

Puts objects into cache.

Returns array of the cache entries.

See C<CastObjectsToRecords> method for supported types of the C<Objects>
argument.

=cut

sub PutObjects
{
    my $self = shift;
    my %args = ( Objects => undef, @_ );

    my @res;
    for( $self->CastObjectsToRecords( Objects => delete $args{'Objects'} ) ) {
        push @res, $self->PutObject( %args, Object => $_ )
    }

    return @res;
}

=head3 PutObject( Object => undef )

Puts record object into cache and returns its cache entry.

B<NOTE> that this method support B<only C<RT::Record> object or its ancesstor
objects>, if you want put mutliple objects or objects represented by different
classes then use C<PutObjects> method instead.

=cut

sub PutObject
{
    my $self = shift;
    my %args = ( Object => undef, @_ );

    my $obj = $args{'Object'};
    unless( UNIVERSAL::isa( $obj, 'RT::Record' ) ) {
        RTx::Shredder::Exception->throw( "Unsupported type '". (ref $obj || $obj || '(undef)')."'" );
    }

    my $str = $obj->_AsString;
    return ($self->{'cache'}->{ $str } ||= { State => ON_STACK, Object => $obj } );
}

=head3 GetObject, GetState, GetRecord( String => ''| Object => '' )

Returns record object from cache, cache entry state or cache entry accordingly.

All three methods takes C<String> (format C<< <class>-<id> >>) or C<Object> argument.
C<String> argument has more priority than C<Object> so if it's not empty then methods
leave C<Object> argument unchecked.

You can read about possible states and thier meaning in L<RTx::Shredder::Constants> docs.

=cut

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

=head2 DEPENDENCIES RESOLVERS

=cut

sub PutResolver
{
    my $self = shift;
    my %args = (
        BaseClass => '',
        TargetClass => '',
        Code => undef,
        @_,
    );
    unless( UNIVERSAL::isa( $args{'Code'} => 'CODE' ) ) {
        die "Resolver '$args{Code}' is not code reference";
    }

    my $resolvers = (
        (
            $self->{'resolver'}->{ $args{'BaseClass'} } ||= {}
        )->{  $args{'TargetClass'} || '' } ||= []
    );
    unshift @$resolvers, $args{'Code'};
    return;
}

sub GetResolvers
{
    my $self = shift;
    my %args = (
        BaseClass => '',
        TargetClass => '',
        @_,
    );

    my @res;
    if( $args{'TargetClass'} && exists $self->{'resolver'}->{ $args{'BaseClass'} }->{ $args{'TargetClass'} } ) {
        push @res, @{ $self->{'resolver'}->{ $args{'BaseClass'} }->{ $args{'TargetClass'} || '' } };
    }
    if( exists $self->{'resolver'}->{ $args{'BaseClass'} }->{ '' } ) {
        push @res, @{ $self->{'resolver'}->{ $args{'BaseClass'} }->{''} };
    }

    return @res;
}

sub ApplyResolvers
{
    my $self = shift;
    my %args = ( Dependency => undef, @_ );
    my $dep = $args{'Dependency'};

    my @resolvers = $self->GetResolvers(
        BaseClass   => $dep->BaseClass,
        TargetClass => $dep->TargetClass,
    );

    unless( @resolvers ) {
        die "Couldn't find resolver for dependency '". $dep->AsString ."'";
    }
    foreach( @resolvers ) {
        eval { $_->(
                Shredder  => $self,
                BaseObject   => $dep->BaseObject,
                TargetObject => $dep->TargetObject,
        ) };
        die "Resolver failed: $@" if $@;
    }

    return;
}

sub WipeoutAll
{
    my $self = $_[0];

    foreach ( values %{ $self->{'cache'} } ) {
        next if $_->{'State'} & (WIPED | IN_WIPING);
        $self->Wipeout( Object => $_->{'Object'} );
    }
}

sub Wipeout
{
    die "Couldn't begin transaction" unless $RT::Handle->BeginTransaction;

    eval { (shift)->_Wipeout( @_ ) };
    if( $@ ) {
        $RT::Handle->Rollback('force');
        die $@ if RTx::Shredder::Exception::Info->caught;
        die "Couldn't wipeout object: $@";
    }

    die "Couldn't commit transaction" unless $RT::Handle->Commit;
}

sub _Wipeout
{
    my $self = shift;
    my %args = ( CacheRecord => undef, Object => undef, @_ );

    my $record = $args{'CacheRecord'};
    $record = $self->PutObject( Object => $args{'Object'} ) unless $record;
    return if $record->{'State'} & (WIPED | IN_WIPING);

    $record->{'State'} |= IN_WIPING;

    my $object = $record->{'Object'};
    unless( $object->BeforeWipeout ) {
        RTx::Shredder::Exception->throw( "BeforeWipeout check returned error" );
    }
    my $deps = $object->Dependencies( Shredder => $self );

    $deps->List(
        WithFlags => DEPENDS_ON | VARIABLE,
        Callback  => sub { $self->ApplyResolvers( Dependency => $_[0] ) },
    );
    $deps->List(
        WithFlags    => DEPENDS_ON,
        WithoutFlags => WIPE_AFTER | VARIABLE,
        Callback     => sub { $self->_Wipeout( Object => $_[0]->TargetObject ) },
    );

    my $insert_query = $object->_AsInsertQuery;
    $object->__Wipeout;
    $self->DumpSQL( Query => $insert_query );
    $record->{'State'} |= WIPED; delete $record->{'Object'};

    $deps->List(
        WithFlags => DEPENDS_ON | WIPE_AFTER,
        WithoutFlags => VARIABLE,
        Callback => sub { $self->_Wipeout( Object => $_[0]->TargetObject ) },
    );

    return;
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

=head2 DATA STORAGE AND BACKUPS

Shredder allow you to store data you delete in files as scripts with SQL
commands.

=head3 SetFile( FileName => '<ISO DATETIME>-XXXX.sql', FromStorage => 1 )

Calls C<GetFileName> method to check and translate file name, then checks
if file is empty, opens it. After this you can dump records with C<DumpSQL>
method.

Returns name and handle.

B<NOTE:> If file allready exists then file content would be overriden.
Also in this situation method prints warning to the STDERR unless C<force>
shredder's option is used.

Examples:
    # file from storage with default name format
    my ($fname, $fh) = $shredder->SetFile;
    # file from storage with custom name format
    my ($fname, $fh) = $shredder->SetFile( FileName => 'shredder-XXXX.backup' );
    # file with path relative to the current dir
    my ($fname, $fh) = $shredder->SetFile( FromStorage => 0, FileName => 'backups/shredder.sql' );
    # file with absolute path
    my ($fname, $fh) = $shredder->SetFile( FromStorage => 0, FileName => '/var/backups/shredder-XXXX.sql' );

=cut

sub SetFile
{
    my $self = shift;
    my $file = $self->GetFileName( @_ );
    if( -s $file ) {
        print STDERR "WARNING: file '$file' is not empty, content would be overwriten\n" unless $opt{'force'};
    }
    open my $fh, ">$file" or die "Couldn't open '$file' for write: $!";
    ($self->{'opt'}->{'sqldump_fn'}, $self->{'opt'}->{'sqldump_fh'}) = ($file, $fh);
    return ($file, $fh);
}

=head3 GetFileName( FileName => '<ISO DATETIME>-XXXX.sql', FromStorage => 1 )

Takes desired C<FileName> and flag C<FromStorage> then translate file name to absolute
path by next rules:
* Default C<FileName> value is C<< <ISO DATETIME>-XXXX.sql >>;
* if C<FileName> has C<XXXX> (exactly four uppercase C<X> letters) then it would be changed with
digits from 0000 to 9999 range, with first one notexistant value;
* if C<FromStorage> argument is true then result path would always be relative to C<StoragePath>;
* if C<FromStorage> argument is false then result would be relative to the current dir unless it's
allready absolute path.

Returns file absolute path.

See example for method C<SetFile>

=cut

sub GetFileName
{
    my $self = shift;
    my %args = ( FileName => '', FromStorage => 1, @_ );

    # default value
    my $file = $args{'FileName'};
    unless( $file ) {
        require POSIX;
        $file = POSIX::strftime("%Y%m%dT%H%M%S-XXXX.sql", gmtime );
    }

    # convert to absolute path
    if( $args{'FromStorage'} ) {
        $file = File::Spec->catfile( $self->StoragePath, $file );
    } elsif( !File::Spec->file_name_is_absolute( $file ) ) {
        $file = File::Spec->rel2abs( $file );
    }

    # check mask
    if( $file =~ /XXXX[^\/\\]*$/ ) {
        my( $tmp, $i ) = ( $file, 0 );
        do {
            $i++;
            $tmp = $file;
            $tmp =~ s/XXXX([^\/\\]*)$/sprintf("%04d", $i).$1/e;
        } while( -e $tmp && $i < 9999 );
        $file = $tmp;
    }

    if( -f $file ) {
        unless( -w _ ) {
            die "File '$file' exists, but is read-only";
        }
    } elsif( !-e _ ) {
        unless( File::Spec->file_name_is_absolute( $file ) ) {
            $file = File::Spec->rel2abs( $file );
        }

        # check base dir
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

    return $file;
}

=head3 StoragePath

Returns absolute path to storage dir. By default it's
F</path-to-RT-var-dir/data/RTx-Shredder/>
(in default RT install would be F</opt/rt3/var/data/RTx-Shredder>),
but you can change this value with config option C<$RT::ShredderStoragePath>.
See C<CONFIGURATION> sections in this doc.

See C<SetFile> and C<GetFileName> methods description.

=cut

sub StoragePath
{
    return $RT::ShredderStoragePath if $RT::ShredderStoragePath;
    return File::Spec->catdir( $RT::VarPath, qw(data RTx-Shredder) );
}

sub DumpSQL
{
    my $self = shift;
    return unless exists $self->{'opt'}->{'sqldump_fh'};

    my %args = ( Query => undef, @_ );
    $args{'Query'} .= "\n" unless $args{'Query'} =~ /\n$/;

    my $fh = $self->{'opt'}->{'sqldump_fh'};
    return print $fh $args{'Query'} or die "Couldn't write to filehandle";
}

1;
__END__

=head1 NOTES

=head2 Database transactions support

Since RTx-Shredder-0.03_01 extension uses database transactions and should
be much safer to run on production servers.

=head2 Foreign keys

Mainstream RT doesn't use FKs, but at least I posted DDL script that creates them
in mysql DB, note that if you use FKs then this two valid keys don't allow delete
Tickets because of bug in MySQL:

  ALTER TABLE Tickets ADD FOREIGN KEY (EffectiveId) REFERENCES Tickets(id);
  ALTER TABLE CachedGroupMembers ADD FOREIGN KEY (Via) REFERENCES CachedGroupMembers(id);

L<http://bugs.mysql.com/bug.php?id=4042>

=head1 BUGS AND HOW TO CONTRIBUTE

I need your feedback in all cases: if you use it or not,
is it works for you or not.

=head2 Testing

Don't skip C<make test> step while install and send me reports if it's fails.
Add your own tests, it's easy enough if you've writen at list one perl script
that works with RT. Read more about testing in F<t/utils.pl>.

=head2 Reporting

Send reports to L</AUTHOR> or to the RT mailing lists.

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

