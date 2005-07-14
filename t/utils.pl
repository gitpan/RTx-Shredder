#!/usr/bin/perl

use strict;
use warnings;

require File::Spec;
require File::Path;
require File::Copy;
require Cwd;

BEGIN {
### after: 	push @INC, qw(@RT_LIB_PATH@);
	push @INC, qw(/opt/rt3/local/lib /opt/rt3/lib);
}
use RTx::Shredder;


=head1 FUNCTIONS

=head2 rewrite_rtconfig

Call this sub after C<RT::LoadConfig>. Function changes
RT config option to switch to local SQLite database.

=cut

sub rewrite_rtconfig
{
	# database
	$RT::DatabaseType   = 'SQLite';
	$RT::DatabaseHost   = 'localhost';
	$RT::DatabaseRTHost = 'localhost';
	$RT::DatabasePort   = '';
	$RT::DatabaseUser   = 'rt_user';
	$RT::DatabasePassword = 'rt_pass';
	$RT::DatabaseRequireSSL = undef;

	# database file name
	$RT::DatabaseName = db_name();

	# generic logging
	$RT::LogToSyslog = undef;
	$RT::LogToScreen = undef;

	# logging to standalone file
	$RT::LogToFile = 'debug';
	my $dname = create_tmpdir();
	my $fname = File::Spec->catfile($dname, test_name() .".log");
	$RT::LogToFileNamed = $fname;
}

=head2 init_db

Creates new RT DB with initial data in the test tmp dir.
Remove old files in test tmp dir if exist.
Also runs RT::Init() and init logging,
so this is all you need to call to start testing environment.

=cut

sub init_db
{
	RT::LoadConfig();
	rewrite_rtconfig();
	cleanup_tmp();

	RT::InitLogging();
	RT::ConnectToDatabase();
	__init_schema( $RT::Handle->dbh );

    __insert_initial_data();
	RT::Init();
    my $fname = File::Spec->catfile( $RT::EtcPath, 'initialdata' );
    __insert_data( $fname );
    $fname = File::Spec->catfile( $RT::LocalEtcPath, 'initialdata' );
    __insert_data( $fname ) if -f $fname && -r _;
	RT::Init();
}

sub __init_schema
{
        my $dbh = shift;
    my (@schema);

	my $fname = File::Spec->catfile( $RT::EtcPath, "schema.SQLite" );
	if( -f $fname && -r _ ) {
		open my $fh, "<$fname" or die "Couldn't open '$fname': $!";
		push @schema, <$fh>;
		close $fh;
	} else {
		die "Couldn't find '$fname'";
	}
	$fname = File::Spec->catfile( $RT::LocalEtcPath, "schema.SQLite" );
	if( -f $fname && -r _ ) {
		open my $fh, "<$fname" or die "Couldn't open '$fname': $!";
		push @schema, <$fh>;
		close $fh;
	}

	my $statement = "";
	foreach my $line (splice @schema) {
            $line =~ s/\#.*//g;
            $line =~ s/--.*//g;
            $statement .= $line;
            if( $line =~ /;(\s*)$/ ) {
                $statement =~ s/;(\s*)$//g;
                push @schema, $statement;
                $statement = "";
            }
        }

        $dbh->begin_work or die $dbh->errstr;
        foreach my $statement (@schema) {
            my $sth = $dbh->prepare($statement) or die $dbh->errstr;
            unless ( $sth->execute ) {
                die "Couldn't execute statement '$statement':" . $sth->errstr;
            }
        }
        $dbh->commit or die $dbh->errstr;
}

sub __insert_initial_data
{
    my $CurrentUser = new RT::CurrentUser();

    my $RT_System = new RT::User($CurrentUser);

    my ( $status, $msg ) = $RT_System->_BootstrapCreate(
        Name     => 'RT_System',
        Creator => '1',
	RealName => 'The RT System itself',
	Comments => "Do not delete or modify this user. It is integral to RT's internal database structures",
        LastUpdatedBy => '1' );
    unless ($status) {
        die "Couldn't create RT::SystemUser: $msg";
    }
    my $equiv_group = RT::Group->new($RT_System);
    $equiv_group->LoadACLEquivalenceGroup($RT_System);
    
        my $superuser_ace = RT::ACE->new($CurrentUser);
        ($status, $msg) = $superuser_ace->_BootstrapCreate(
                             PrincipalId => $equiv_group->Id,
                             PrincipalType => 'Group',
                             RightName     => 'SuperUser',
                             ObjectType    => 'RT::System',
                             ObjectId      => '1' );
    unless ($status) {
        die "Couldn't grant RT::SystemUser with SuperUser right: $msg";
    }
}

sub __insert_data
{
    my $datafile = shift;
    require $datafile
      || die "Couldn't load datafile '$datafile' for import: $@";
    our (@Groups, @Users, @Queues,
         @ACL, @CustomFields, @ScripActions,
	 @ScripConditions, @Templates, @Scrips,
	 @Attributes);

    if (@Groups) {
        for my $item (@Groups) {
            my $new_entry = RT::Group->new($RT::SystemUser);
            my ( $return, $msg ) = $new_entry->_Create(%$item);
            die "$msg" unless $return;
        }
    }
    if (@Users) {
        for my $item (@Users) {
            my $new_entry = new RT::User($RT::SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            die "$msg" unless $return;
        }
    }
    if (@Queues) {
        for my $item (@Queues) {
            my $new_entry = new RT::Queue($RT::SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            die "$msg" unless $return;
        }
    }
    if (@ACL) {
        for my $item (@ACL) {
	    my ($princ, $object);

	    # Global rights or Queue rights?
	    if ($item->{'Queue'}) {
                $object = RT::Queue->new($RT::SystemUser);
                $object->Load( $item->{'Queue'} );
	    } else {
		$object = $RT::System;
	    }

	    # Group rights or user rights?
	    if ($item->{'GroupDomain'}) {
                $princ = RT::Group->new($RT::SystemUser);
	        if ($item->{'GroupDomain'} eq 'UserDefined') {
                  $princ->LoadUserDefinedGroup( $item->{'GroupId'} );
	        } elsif ($item->{'GroupDomain'} eq 'SystemInternal') {
                  $princ->LoadSystemInternalGroup( $item->{'GroupType'} );
	        } elsif ($item->{'GroupDomain'} eq 'RT::System-Role') {
                  $princ->LoadSystemRoleGroup( $item->{'GroupType'} );
	        } elsif ($item->{'GroupDomain'} eq 'RT::Queue-Role' &&
			 $item->{'Queue'}) {
                  $princ->LoadQueueRoleGroup( Type => $item->{'GroupType'},
					      Queue => $object->id);
	        } else {
                  $princ->Load( $item->{'GroupId'} );
	        }
	    } else {
		$princ = RT::User->new($RT::SystemUser);
		$princ->Load( $item->{'UserId'} );
	    }

	    # Grant it
	    my ( $return, $msg ) = $princ->PrincipalObj->GrantRight(
                                                     Right => $item->{'Right'},
                                                     Object => $object );
            die "$msg" unless $return;
        }
    }
    if (@CustomFields) {
        for my $item (@CustomFields) {
            my $new_entry = new RT::CustomField($RT::SystemUser);
            my $values    = $item->{'Values'};
            delete $item->{'Values'};
            my $q     = $item->{'Queue'};
            my $q_obj = RT::Queue->new($RT::SystemUser);
            $q_obj->Load($q);
            if ( $q_obj->Id ) {
                $item->{'Queue'} = $q_obj->Id;
            }
            elsif ( $q == 0 ) {
                $item->{'Queue'} = 0;
            }
            else {
                die "Couldn't find queue '$q'" unless $q_obj->Id;
            }
            my ( $return, $msg ) = $new_entry->Create(%$item);
            die "$msg" unless $return;

            foreach my $value ( @{$values} ) {
                my ( $eval, $emsg ) = $new_entry->AddValue(%$value);
                die "$emsg" unless $eval;
            }
        }
    }
    if (@ScripActions) {
        for my $item (@ScripActions) {
            my $new_entry = RT::ScripAction->new($RT::SystemUser);
            my ($return, $msg) = $new_entry->Create(%$item);
            die "$msg" unless $return;
        }
    }
    if (@ScripConditions) {
        for my $item (@ScripConditions) {
            my $new_entry = RT::ScripCondition->new($RT::SystemUser);
            my ($return, $msg) = $new_entry->Create(%$item);
            die "$msg" unless $return;
        }
    }
    if (@Templates) {
        for my $item (@Templates) {
            my $new_entry = new RT::Template($RT::SystemUser);
            my ($return, $msg) = $new_entry->Create(%$item);
            die "$msg" unless $return;
        }
    }
    if (@Scrips) {
        for my $item (@Scrips) {
            my $new_entry = new RT::Scrip($RT::SystemUser);
            my ( $return, $msg ) = $new_entry->Create(%$item);
            die "$msg" unless $return;
        }
    }
    if (@Attributes) {
	my $sys = RT::System->new($RT::SystemUser);
        for my $item (@Attributes) {
	    my $obj = delete $item->{Object}; # XXX: make this something loadable
	    $obj ||= $sys;
	    my ( $return, $msg ) = $obj->AddAttribute (%$item);
            die "$msg" unless $return;
        }
    }
}

=head2 is_all_seccessful

Returns true if all tests you've already run are successful.

=cut

sub is_all_successful
{
	use Test::Builder;
	my $Test = Test::Builder->new;
	return grep( !$_, $Test->summary )? 0: 1;
}

=head2 db_name

Returns database absolute file path.
It is C<cwd() .'/t/data/tmp/'. test_name() .'.db'>.

=cut

sub db_name { return File::Spec->catfile(create_tmpdir(), test_name() .".db") }

=head2

Returns name of the test file running now
with stripped extension and dirs.
For exmple returns '00load' for 't/00load.t' test file.

=cut

sub test_name
{
	my $name = $0;
	$name =~ s/^.*[\\\/]//;
	$name =~ s/\..*$//;
	return $name;
}

=head2 cleanup_tmp

Delete all tmp files that match C<t/data/tmp/test_name.*> mask.
See also C<test_name> function.

=cut

sub cleanup_tmp
{
	my $name = test_name();
	my $dname = File::Spec->catdir(Cwd::cwd(), qw(t data tmp));
	my $mask = File::Spec->catfile($dname, $name ) .'.*';
	return unlink glob($mask);
}

=head2 tmpdir

Return absolute path to tmp dir used in tests.
It is C<cwd(). "t/data/tmp">.

=cut

sub tmpdir { return File::Spec->catdir(Cwd::cwd(), qw(t data tmp)) }

=head2 create_tmpdir

Creates tmpdir if doesn't exist.
Returns tmpdir absolute path.

=cut

sub create_tmpdir
{
	my $name = tmpdir();
	File::Path::mkpath( $name );
	return $name;
}

sub savepoint_name
{
	my $name = shift || 'sp';
	return File::Spec->catfile( create_tmpdir(), test_name() .".$name.db" );
}

sub create_savepoint
{
	my $orig = db_name();
	my $dest = savepoint_name( shift );
	$RT::Handle->dbh->disconnect;
	File::Copy::copy( $orig, $dest ) or die "Couldn't copy '$orig' => '$dest': $!";
	undef $RT::Handle;
	RT::ConnectToDatabase;
	return;
}

sub dump_current_and_savepoint
{
	my $orig = savepoint_name( shift );
	die "Couldn't find savepoint file" unless -f $orig && -r _;
	my $odbh = connect_sqlite( $orig );
	return ( dump_sqlite( $RT::Handle->dbh ), dump_sqlite( $odbh ) );
}
sub dump_savepoint_and_current { return reverse dump_current_and_savepoint(@_) }

sub dump_sqlite
{
	my $dbh = shift;
	my %args = ( CleanDates => 1, @_ );

	my $old_fhkn = $dbh->{'FetchHashKeyName'};
	$dbh->{'FetchHashKeyName'} = 'NAME_lc';

	my $sth = $dbh->table_info( '', '', '%', 'TABLE' ) || die $DBI::err;
	my @tables = keys %{$sth->fetchall_hashref( 'table_name' )};

	my $res = {};
	foreach my $t( @tables ) {
		next if lc($t) eq 'sessions';
		$res->{$t} = $dbh->selectall_hashref("SELECT * FROM $t", 'id');
		clean_dates( $res->{$t} ) if $args{'CleanDates'};
		die $DBI::err if $DBI::err;
	}

	$dbh->{'FetchHashKeyName'} = $old_fhkn;
	return $res;
}

sub clean_dates
{
	my $h = shift;
	my $date_re = qr/^\d\d\d\d\-\d\d\-\d\d\s*\d\d\:\d\d(\:\d\d)?$/i;
	foreach my $id ( keys %{ $h } ) {
		next unless $h->{ $id };
		foreach ( keys %{ $h->{ $id } } ) {
			delete $h->{$id}{$_} if $h->{$id}{$_} &&
						$h->{$id}{$_} =~ /$date_re/;
		}
	}
}

sub connect_sqlite
{
	return DBI->connect("dbi:SQLite:dbname=". shift, "", "");
}

sub note_on_fail
{
	my $name = test_name();
	my $tmpdir = tmpdir();
	return <<END;
Some tests in '$0' file failed.
You can find debug info in '$tmpdir' dir.
There is should be:
	$name.log - RT debug log file
	$name.db - latest RT DB sed while testing
	$name.*.db - savepoint databases
See also perldoc t/utils.pl to know how to use this info.
END
}

1;
