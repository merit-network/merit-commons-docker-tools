#!/usr/bin/env perl

print "MeritCommons Docker Boot Loader\n";
print "(c) 2016-2018 Detroit Collaboration Works, LLC\n\n";

use Mojo::File;
use POSIX qw(setuid setgid :sys_wait_h);
use BSD::Resource;
use Config qw( %Config );

# this is a controlled environment
$ENV{MERITCOMMONS_DOCKER} = 1;

# and we know where home is.
$ENV{MERITCOMMONS_HOME} = '/usr/local/meritcommons/meritcommons';

# and we know where our config file is.
my $config_file = "$ENV{MERITCOMMONS_HOME}/etc/meritcommons.conf";
my $c = parse_config($config_file);

# figure out what we'll be exec-ing
my @args;
foreach my $arg (@ARGV) {
    if ($arg =~ /\s+/) {
        push(@args, "'$arg'");
    } else {
        push(@args, $arg);
    }
}
my $to_run = join(' ', @args);

open my $fh, '>>', '/etc/hosts';
print $fh "127.0.0.1 @{[$c->{front_door_host}]}\n";
close $fh;

# set rlimits
setrlimit(RLIMIT_NOFILE, 999999, 999999);
setrlimit(RLIMIT_NPROC, 65536, 65536);
setrlimit(RLIMIT_STACK, 16777216, 16777216);

# since we've gotta do init-type things let's at least help kill zombies
my $reap_processes = sub {
    while ((my $pid = waitpid(-1, WNOHANG)) > 0) {
        if ($ENV{MERITCOMMONS_DEBUG}) {
            my @sig_name_by_num;
            @sig_name_by_num[ split(' ', $Config{sig_num}) ] = split(' ', $Config{sig_name});
            my $status = $?;
            my $exit_code = $? >> 8;
            my $fatal_signal = $sig_name_by_num[$? & 127];
            print "[boot] reaped process $pid; exit code $exit_code";
            if ($fatal_signal ne 'ZERO') {
                print "; killed with SIG_$fatal_signal";
            }
            print "\n";
        }
    }  
};

$SIG{CHLD} = $reap_processes;
$SIG{ALRM} = sub {
    $reap_processes->();
    alarm 5;
};

if ($ENV{STAY_ROOT}) {
    # set the alarm, we're about to launch.
    alarm 5;
    
    if (-e $config_file) {
        print "[@{[$c->{front_door_host}]}] running: $to_run (as root)\n";
        system(@ARGV);
    } else {
        print "[error]: please configure meritcommons in meritcommons/etc/meritcommons.conf before proceeding\n";
        exit 1;
    }
} else {
    my $run_as_uid = `id -u meritcommons`;
    my $run_as_gid = `id -g meritcommons`;
    chomp($run_as_uid, $run_as_gid);

    # linux just passes through the filesystem, mac os seems to mount in a
    # uid-agnostic way.  so we have to switch the IDs on linux only (for now)
    if ($ENV{LOCAL_SYSTEM} eq "Linux") {
        my $user_changed;
        if ($ENV{LOCAL_USER_ID} && $ENV{LOCAL_USER_ID} != $run_as_uid) {
            # update the MeritCommons user's uid so we don't have any permissions issues
            system("usermod -u $ENV{LOCAL_USER_ID} meritcommons");
            $run_as_uid = $ENV{LOCAL_USER_ID};
            $user_changed = 1;
        }

        if ($ENV{LOCAL_GROUP_ID} && $ENV{LOCAL_GROUP_ID} != $run_as_gid) {
            # update the MeritCommons user's uid so we don't have any permissions issues
            system("groupmod -g $ENV{LOCAL_GROUP_ID} meritcommons");
            $run_as_gid = $ENV{LOCAL_GROUP_ID};
            $user_changed = 1;
        }

        if ($user_changed) {
            system("chown -R $run_as_uid:$run_as_gid /var/run/postgresql")
        } 
    }   

    # setuid + gid to meritcommons
    setgid($run_as_gid);
    setuid($run_as_uid);

    unless ($ENV{SKIP_DB}) {
        unless (-e "/usr/local/meritcommons/var/pgsql/data/PG_VERSION") {
            print "[info] initializing new database\n";
            system("/usr/lib/postgresql/9.5/bin/initdb -D /usr/local/meritcommons/var/pgsql/data");
        }

        # start the database..
        system("/usr/lib/postgresql/9.5/bin/pg_ctl -D /usr/local/meritcommons/var/pgsql/data -l /usr/local/meritcommons/var/log/postgres.log -w start");

        # create the databases if they dont exist
        unless (db_exists("meritcommons")) {
            print "[info] creating 'meritcommons' database\n";
            system("psql -d template1 -tAc 'create database meritcommons;'");
        }

        unless (db_exists("meritcommons_async")) {
            print "[info] creating 'meritcommons_async' database\n";
            system("psql -d template1 -tAc 'create database meritcommons_async;'");
        }

        my $sphinx_started;
        # we should start sphinx too to keep things healthy
        if (-e '/usr/local/meritcommons/meritcommons/etc/sphinx.conf') {
            # start sphinx
            system("/usr/bin/searchd -c /usr/local/meritcommons/meritcommons/etc/sphinx.conf 2>&1 > /dev/null");
            $sphinx_started = 1;
        } else {
            print "\n[error]: please configure Sphinx in meritcommons/etc/sphinx.conf before proceeding\n\n";
            shutdown_services();
            exit 1; 
        }

        my $bloomd_started;
        # same with bloomd
        if (-e '/usr/local/meritcommons/meritcommons/etc/bloomd.conf') {
            system("/usr/bin/bloomd -f /usr/local/meritcommons/meritcommons/etc/bloomd.conf 2>&1 >> /usr/local/meritcommons/var/log/bloomd.log &");
            $bloomd_started = 1;
        } else {
            print "\n[error]: please configure bloomd in meritcommons/etc/bloomd.conf before proceeding\n\n";
            shutdown_services();
            exit 1;
        }

        my $memcached_started;
        # same with memcached
        if ((ref $c->{memcached_servers} eq "ARRAY") && scalar @{$c->{memcached_servers}}) {
            system("/usr/bin/memcached -m 256 -d -P /usr/local/meritcommons/var/memcached.pid");
            $memcached_started = 1;
        }

        # set the alarm for process cleanup, we're about to launch
        alarm 5;
        
        if (-e $config_file) {
            if (scalar(@ARGV) >= 1) {
                print "[@{[$c->{front_door_host}]}] running: $to_run\n";
                system(@ARGV);
                print "Cleaning up...\n";
                system("pg_ctl -l /usr/local/meritcommons/var/log/postgres.log -w stop");
                system("/usr/bin/searchd -c /usr/local/meritcommons/meritcommons/etc/sphinx.conf --stop 2>&1 > /dev/null") if $sphinx_started;
                kill("TERM", Mojo::File->new("/usr/local/meritcommons/var/memcached.pid")->slurp) if $memcached_started;
            } else {
                $SIG{INT} = $SIG{TERM} = \&shutdown_services;
                print "[@{[$c->{front_door_host}]}] booted.  CTRL-C to shutdown\n";
                while(1) {
                    sleep 3600;
                }
            }
        } else {
            print "\n[error]: please configure meritcommons using meritcommons.conf before proceeding\n\n";
            shutdown_services();
            exit 1;
        }
    }
}

sub shutdown_services {
    print "[@{[$c->{front_door_host}]}] shutting down...\n";
    system("pg_ctl -l /usr/local/meritcommons/var/log/postgres.log -w stop");
    system("/usr/bin/searchd -c /usr/local/meritcommons/meritcommons/etc/sphinx.conf --stop 2>&1 > /dev/null");
    system("killall bloomd 2>&1 >/dev/null");
    kill("TERM", Mojo::File->new("/usr/local/meritcommons/var/memcached.pid")->slurp);
    exit;
}

sub db_exists {
    my ($db) = @_;
    if (`psql -d template1 -tAc "select 1 from pg_database where datname='$db'"` == 1) {
        return 1;
    }
    return undef;
}

sub parse_config {
    my ($file) = @_;

    my $config = {};
    if (-e $file) {
        my $content = Mojo::File->new($file)->slurp;

        # Run Perl code in sandbox
        $config = eval 'package MeritCommons::DockerTools::Boot::Sandbox; no warnings;'
            . "use Mojo::Base -strict; $content";

        die qq|Can't load configuration from file "$file": $@| if $@;

        unless (ref($config) eq "HASH") {
            die qq|Configuration file "$file" did not return a hash reference.\n|
        }
    }

    return $config;
}
