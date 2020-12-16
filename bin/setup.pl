#!/usr/bin/env perl

#
# MeritCommons Docker Tools Setup
# [deps] cpanm Mojolicious IO::Prompt IPC::Run
#

use File::Basename 'dirname';
use File::Spec;
BEGIN {
    push @INC, join('/', File::Spec->splitdir(dirname(__FILE__)), '..', 'lib');
}

use Cwd qw/getcwd abs_path/;
use IO::Prompt;
use IPC::Run;
use MeritCommons::DockerTools::Config;
use Mojo::File;
use Term::ANSIColor;
use Getopt::Long qw/GetOptions :config no_auto_abbrev no_ignore_case/;

GetOptions(
    'c|core-only' => \my $core_only
);

if ($ENV{DOCKER_TOOLS_CORE_ONLY}) {
    $core_only = $ENV{DOCKER_TOOLS_CORE_ONLY};
}

print "MeritCommons Docker Setup\n";
print "(c) 2016-2017 Detroit Collaboration Works, LLC\n\n";

my $git = `which git`;
my $docker_repo = 'git.meritcommons.io:5050';

chomp($git);

unless ($git) {
    die color('bold red') . "[fatal] MeritCommons Docker Setup requires git to be installed\n" . color('reset');
}

my $docker = `which docker`;
chomp($docker);
unless ($docker) {
    die color('bold red') . "[fatal] MeritCommons Docker Setup requires docker to be installed\n" . warn color('reset');
}

my $c = new MeritCommons::DockerTools::Config;

my $ssh_key;
# the first TTY error will occur in this block.  make it all non fatal and catch below
eval {
    if ($c->{adt_home}) {   
        unless(prompt("MeritCommons Docker Tools already appears to be set up, reconfigure? [y/N] ", -yn1td=>"n")) {
            print color('red');
            print "User aborted setup\n";
            print color('reset');
            exit;
        }
    }

    if (-e "$ENV{HOME}/.ssh/id_ed25519.pub") {
        $ssh_key = Mojo::File->new("$ENV{HOME}/.ssh/id_ed25519.pub")->slurp;
    } elsif (-e "$ENV{HOME}/.ssh/id_rsa.pub") {
        $ssh_key = Mojo::File->new("$ENV{HOME}/.ssh/id_rsa.pub")->slurp;
    } else {
        if (prompt("No SSH key found, shall we generate one for you now? [Y/n] ", -yn1td=>"y")) {
            my $h = start(["ssh-keygen", '-t rsa'], '<pty<', \$in, '>pty>', \$out, '2>', \$err, timeout(10));
            $in .= "\n\n";
            $h->finish;
            $ssh_key = Mojo::File->new("$ENV{HOME}/.ssh/id_rsa.pub")->slurp;
        } else {
            print "Please set up SSH keys, and register them with your git.meritcommons.io user profile\n";
            print "See https://git.meritcommons.io/help/ssh/README.md for more information.\n";
            exit;
        }
    }

    unless (prompt("Have you configured your SSH key with git.meritcommons.io? [Y/n] ", -yn1td=>"y")) {
        print "Please copy and paste this SSH key into the 'ssh keys' section of your git.meritcommons.io account\n";
        print "Or into the 'deploy keys' section of your git.meritcommons.io project(s), remember to add it to the\n";
        print "meritcommons/core and meritcommons/plugins repositories as well\n";
        print "See https://git.meritcommons.io/help/ssh/README.md for more information.\n\n";
        print "$ssh_key\n";
        
        exit;
    }
};

if (my $error = $@) {
    if ($error =~ /such device or address/) {
        print(color('red'), 
            "Whoops, you're running an OS that isn't letting us mess with your TTY.  Congratulations.\n",
            "To continue, please run $ENV{HOME}/meritcommons-docker-tools/bin/setup.pl as $ENV{USER}\n",
            color('reset'), "\n"
        );
    } else {
        print(color('red'), 
            "This is an error we weren't expecting: $error\n",
            "I'm not 100% sure but try running $ENV{HOME}/meritcommons-docker-tools/bin/setup.pl as $ENV{USER}\n",
            "It might work.. it's worth a shot\n",
            color('reset'), "\n"
        );     
    }

    exit 1;
}

get_home();
get_core_repo();
get_plugins_repo();
unless ($core_only) {
    get_common_repo();
}

# Summarize...
my $confirm;
until ($confirm) {
    print "MeritCommons Docker Setup Summary\n";
    print "------------------------------\n";
    print "MeritCommons Docker Home:@{[color('blue')]} $c->{adt_home} @{[color('reset')]}\n";
    print "MeritCommons Core Repo  :@{[color('blue')]} $c->{core_repo} @{[color('reset')]}\n";
    print "MeritCommons Plugin Repo:@{[color('blue')]} $c->{plugins_repo} @{[color('reset')]}\n";
    print "MeritCommons Custom Repo:";
    if ($core_only) {
        print "@{[color('red')]} 'Core Only' mode enabled; customizations disabled @{[color('reset')]}\n";
    } else {
        print "@{[color('blue')]} $c->{common_repo} @{[color('reset')]}\n";
    }
    my $answer;
    if ($core_only) {
        $answer = lc(prompt("Change (D)irectory, (A)cademica Core Repo, (P)lugin Repo, or Y to continue [Y] ", -td=>'Y'));        
    } else {
        $answer = lc(prompt("Change (D)irectory, (A)cademica Core Repo, (P)lugin Repo, (C)ustomization Repo, or Y to continue [Y] ", -td=>'Y'));
    }

    if ($answer eq 'y') {
        $confirm = 1;
    } elsif ($answer eq 'd') {
        get_home();
    } elsif ($answer eq 'a') {
        get_core_repo();
    } elsif ($answer eq 'p') {
        get_plugins_repo();
    } elsif ($answer eq 'c') {
        get_common_repo();
    }
}

unless (-d $c->{adt_home}) {
    system (qw/mkdir -p/, $c->{adt_home});
}

unless (-d $c->{adt_home}) {
    die "[fatal] error creating $c->{adt_home} directory\n";
}

print color('cyan');
print "Cloning Repositories...\n";
print color('reset');

# most likely to be wrong first... common repo
unless ($core_only) {
    system($git, 'clone', $c->{common_repo}, "$c->{adt_home}/customizations");
    unless (-d "$c->{adt_home}/customizations") {
        warn color('bold red');
        warn "[fatal] could not clone customization repository $c->{common_repo}, please check that you have\n" . 
             "        proper access to this repository and that SSH keys are set up correctly.\n";
        warn color('reset');
        exit 1;
    }
}

# core repo...
system($git, 'clone', $c->{core_repo}, "$c->{adt_home}/meritcommons");
if (-d "$c->{adt_home}/meritcommons") {
    # symlink in theme(s), relatively.
    my $cwd = getcwd;
    chdir("$c->{adt_home}/meritcommons/themes/");
    system("ln -vs ../../customizations/meritcommons/themes/* .");
    chdir("$c->{adt_home}/meritcommons-plugins/lib/MeritCommons/Plugin");
    unless ($core_only) {
        system("ln -vs ../../../../customizations/plugins/lib/MeritCommons/Plugin/* .");
    }

    # go back to where we were before
    chdir($cwd);
    if (-d "$ENV{HOME}/.config/meritcommons_dockertools/etc") {
        print color('green');
        print "Pulling in config found in $ENV{HOME}/.config/meritcommons_dockertools/etc\n";
        system("rsync", "-avr", "$ENV{HOME}/.config/meritcommons_dockertools/etc/", "$c->{adt_home}/meritcommons/etc/");
        print color('reset');
    }
} else {
    warn color('bold red');
    warn "[fatal] could not clone core meritcommons repository $c->{core_repo}, please check that you have\n" . 
         "        proper access to this repository and that SSH keys are set up correctly.\n";
    warn color('reset');
    exit 1;
}

# plugins repo...
system($git, 'clone', $c->{plugins_repo}, "$c->{adt_home}/meritcommons-plugins");
unless (-d "$c->{adt_home}/meritcommons-plugins") {
    warn color('bold red');
    warn "[fatal] could not clone core plugins repository $c->{core_repo}, please check that you have\n" . 
         "        proper access to this repository and that SSH keys are set up correctly.\n";
    warn color('reset');
    exit 1;
}

#
# Build out var directories
#

print color('cyan');
print "Preparing var/ directory structure\n";
print color('green');

foreach my $dir (qw{bloomd log pgsql/data plugins public run/postgres sphinx/data state}) {
    unless (-d "$c->{adt_home}/var/$dir") {
        system(qw/mkdir -pv/, "$c->{adt_home}/var/$dir");
    }
}

print color('reset');
print "\n";

#
# Save configuration, we're pretty much sane now.
#

print color('cyan');
print "Saving configuration\n";
print color('reset');
print "\n";

$c->save;
write_env();

if (prompt(
    "Would you like to rebuild or download your MeritCommons Docker image from git.meritcommons.io? [a] ", 
        -menu=> ['download', 'build'], 
        -td=> 'a'
) eq "download") {
    # check to see if they're already logged in
    my $docker_logged_in;
    if (-e "$ENV{HOME}/.docker/config.json") {
        my $docker_cfg = Mojo::File->new("$ENV{HOME}/.docker/config.json")->slurp;
        if ($docker_cfg =~ /\Q$docker_repo\E/) {
            $docker_logged_in = 1;
        }
    }
    unless ($docker_logged_in) {
        print color('cyan');
        print "Running '" . color('cyan bold') . "docker login $docker_repo" . color("reset") . color("cyan") . "'\n";
        print "Please enter your git.meritcommons.io credentials when prompted";
        print color('reset');
        print "\n";
        my $gai_user = prompt("git.meritcommons.io username: ", -td=>"@{[$ENV{SUDO_USER} // $ENV{USER}]}");
        $gai_user =~ s/[\r\n]+//g;
        $gai_user =~ s/'/\\'/g;
        my $gai_password = prompt("git.meritcommons.io password: ", -te=>"*");
        $gai_password =~ s/[\r\n]+//g;
        $gai_password =~ s/'/\\'/g;
        system("docker login -u '$gai_user' -p '$gai_password' $docker_repo");
        print color('cyan');
        print "Running '" . color('cyan bold') . "docker pull $docker_repo/meritcommons/docker-tools" . color("reset") . color("cyan") . "'\n";
        print color('reset');
    }
    system("docker pull $docker_repo/meritcommons/docker-tools");
} else {
    print color('cyan');
    print "Building Docker Image\n";
    print color('reset');

    # build the docker image from the Dockerfile
    print color('green');
    system(qw/cp -vr/, join('/', File::Spec->splitdir(dirname(__FILE__)), '..', 'vendor'), $c->{adt_home});
    system(qw/cp -v/, join('/', File::Spec->splitdir(dirname(__FILE__)), '..', 'Dockerfile'), $c->{adt_home});
    print color('reset');
    print "\n";
    system(qw/docker build -t/, "$docker_repo/meritcommons/docker-tools", $c->{adt_home});
}

print color('cyan');
print "Installing scripts\n";
print color('reset');

install_scripts();

#
# subs
#

sub install_scripts {
    my $bin_dir = "$c->{adt_home}/bin";
    unless (-d $bin_dir) {
        system(qw/mkdir -pv/, $bin_dir);
    }

    #
    # basic scripts for system management.  things that are likely to be also on the host OS should
    # be prefixed with ad_, and things that you want to run as root should be prefixed with ad_root_ 
    #

    foreach my $script (qw/meritcommons ad_bash ad_psql ad_root_bash/) {
        open my $fh, '>', "$bin_dir/$script";
        my $run_line;
        if ($script =~ /^ad_(\w+)$/) {
            my $cmd = $1;
            if ($cmd =~ /^root_(\w+)$/) {
                $ENV{STAY_ROOT} = 1;
                $run_line = 'exec $DOCKER_EXEC ' . $1 . ' "$@"';
            } elsif ($cmd =~ /^skipdb_(\w+)$/) {
                $ENV{SKIP_DB} = 1;
                $run_line = 'exec $DOCKER_EXEC ' . $1 . ' "$@"';
            } else {
                $run_line = 'exec $DOCKER_EXEC ' . $1 . ' "$@"';
            }
        } else {
            $run_line = 'exec $DOCKER_EXEC $(basename $0) "$@"';
        }
        print $fh <<"EOF";
#!/bin/sh

# (c) 2016-2017 Detroit Collaboration Works, LLC
# generated by MeritCommons Docker Tools at @{[scalar localtime]}

@{[$ENV{SKIP_DB} ? "SKIP_DB=$ENV{SKIP_DB}" : ()]}
@{[$ENV{STAY_ROOT} ? "STAY_ROOT=$ENV{STAY_ROOT}" : ()]}

. $ENV{HOME}/.config/meritcommons_dockertools/adt.env

# set DOCKER_EXEC to what it should be.
set_exec;

$run_line
EOF
        close $fh;
        chmod(0755, "$bin_dir/$script");
        print color('green');
        print "Created script: $bin_dir/$script\n";
        print color('reset');
    }

    #
    # ad_pull_all - a convenience script for pulling updates from all git repos currently checked out
    #

    open my $fh, '>', "$bin_dir/ad_pull_all";
    print $fh <<"EOF";
#!/bin/sh

. $ENV{HOME}/.config/meritcommons_dockertools/adt.env

GIT="git -C";

echo "[meritcommons]";
\$GIT \$ADOCK/meritcommons branch -r | grep -v '\\->' | while read remote; do \$GIT \$ADOCK/meritcommons branch --track "\${remote#origin/}" "\$remote" 2> /dev/null; done
\$GIT \$ADOCK/meritcommons fetch --all
\$GIT \$ADOCK/meritcommons pull --all
echo "[meritcommons-plugins]";
\$GIT \$ADOCK/meritcommons-plugins branch -r | grep -v '\\->' | while read remote; do \$GIT \$ADOCK/meritcommons-plugins branch --track "\${remote#origin/}" "\$remote" 2> /dev/null; done
\$GIT \$ADOCK/meritcommons-plugins fetch --all
\$GIT \$ADOCK/meritcommons-plugins pull --all
EOF

    unless ($core_only) {
        print $fh <<"EOF";
echo "[customizations]";
\$GIT \$ADOCK/customizations branch -r | grep -v '\\->' | while read remote; do \$GIT \$ADOCK/customizations branch --track "\${remote#origin/}" "\$remote" 2> /dev/null; done
\$GIT \$ADOCK/customizations fetch --all
\$GIT \$ADOCK/customizations pull --all
EOF
    }
    
    close $fh;

    chmod(0755, "$bin_dir/ad_pull_all");
    print color('green');
    print "Created script: $bin_dir/ad_pull_all\n";
    print color('reset');

    #
    # morbo-meritcommons in docker environments will always run morbo-meritcommons-inotify 
    # needs some better-than-default love here.
    #

    my $customizations_string = "-w \${ULA}/customizations/plugins/lib -w \${ULA}/customizations/meritcommons/themes -w \${ULA}/customizations/meritcommons/lib" unless $core_only;
    open $fh, '>', "$bin_dir/morbo-meritcommons";
    print $fh <<"EOF";
#!/bin/sh

. $ENV{HOME}/.config/meritcommons_dockertools/adt.env
set_exec;
EXTRA_WATCHES="-w \${ULA}/meritcommons/lib -w \${ULA}/meritcommons/etc -w \${ULA}/meritcommons/templates -w \${ULA}/plugins/lib\\
 -w \${ULA}/meritcommons/public -w \${ULA}/meritcommons/script -w \${ULA}/meritcommons/doc -w \${ULA}/meritcommons/themes\\
 $customizations_string"

\$DOCKER_EXEC morbo-meritcommons-inotify \$@ \$EXTRA_WATCHES

EOF

    close $fh;

    chmod(0755, "$bin_dir/morbo-meritcommons");
    print color('green');
    print "Created script: $bin_dir/morbo-meritcommons\n";
    print color('reset');

    #
    # ad_boot, run boot.pl with no args
    #
    open $fh, '>', "$bin_dir/ad_boot";
    print $fh <<"EOF";
#!/bin/sh

. $ENV{HOME}/.config/meritcommons_dockertools/adt.env
set_exec;
\$DOCKER_EXEC

EOF
    close $fh;
   
    chmod(0755, "$bin_dir/ad_boot");
    print color('green');
    print "Created script: $bin_dir/ad_boot\n";
    print color('reset');

    #
    # ad_subl, open all this stuff in sublime text
    #
    
    my $customizations_string = "$c->{adt_home}/customizations" unless $core_only;
    open $fh, '>', "$bin_dir/ad_subl";
    print $fh <<"EOF";
#!/bin/sh

subl $c->{adt_home}/meritcommons $c->{adt_home}/meritcommons-plugins $customizations_string

EOF
    close $fh;

    chmod(0755, "$bin_dir/ad_subl");
    print color('green');
    print "Created script: $bin_dir/ad_subl\n";
    print color('reset');

    #
    # install boot loader script
    #

    unless (-d "$c->{adt_home}/dbin") {
        system(qw/mkdir -pv/, "$c->{adt_home}/dbin");
    }

    #
    # scan for bootloaders..
    #
    my $dbin_dir = abs_path(join('/', File::Spec->splitdir(dirname(__FILE__)), '..', 'dbin'));
    my $bootloader_menu = {};
    opendir my $dh, $dbin_dir;
    while (my $file = readdir($dh)) {
        next if $file =~ /^\./;
        if ($file =~ /^(\w+)\-boot.pl$/) {
            $bootloader_menu->{$1} = "$dbin_dir/$file";
        }
    }

    print "\nChoose MeritCommons Docker Boot Loader [a]\n";
    my $bootloader = prompt(-menu=>$bootloader_menu, -td=>"a");
    print "Installing Docker Boot Loader\n";
    print color('green');
    system(qw/cp -v/, $bootloader, "$c->{adt_home}/dbin/boot.pl");
    print color('reset');

    if (-e "$ENV{HOME}/.bashrc") {
        if (`grep '$bin_dir' $ENV{HOME}/.bashrc | grep PATH | wc -l` == 1) {
            print color('bold green');
            print "\n** Good: $bin_dir is already included in your \$PATH\n";
            print color('reset');
        } else {
            if (prompt("May I please add $bin_dir to your \$PATH? [y/N] ", -yn1d=>"n")) {
                open my $bashrc, '>>', "$ENV{HOME}/.bashrc";
                print $bashrc "\n# added automatically by MeritCommons Docker Tools at @{[scalar localtime ]}\nexport PATH=$bin_dir:\$PATH\n";
                close $bashrc;
                print color('bold yellow');
                print "\n** Note: added $bin_dir to your \$PATH, please run 'source $ENV{HOME}/.bashrc' or re-open your session to refresh\n";
                print color('reset');
            } else {
                print color('bold red');
                print "\n** Note: please add $bin_dir to your \$PATH\n";
                print color('reset');
            }
        }
    } else {
        print color('bold red');
        print "\n** Note: please add $bin_dir to your \$PATH\n";
        print color('reset');
    }
}

sub write_env {
    my $file = "$ENV{HOME}/.config/meritcommons_dockertools/adt.env";
    my $customizations_string = "-v \$ADOCK/customizations:\$ULA/customizations" unless $core_only;
    Mojo::File->new($file)->spurt(<<"EOF");
# generated by MeritCommons Docker Tools at @{[scalar localtime]}
ADOCK="$c->{adt_home}";
ULA="/usr/local/meritcommons";
DOCKER_VMAP="-v \$ADOCK/var:\$ULA/var \
    -v \$ADOCK/meritcommons:\$ULA/meritcommons \
    -v \$ADOCK/dbin:\$ULA/bin \
    -v \$ADOCK/meritcommons-plugins:\$ULA/plugins \
    $customizations_string";
DOCKER_ENV="-e LOCAL_USER_ID=\$(id -u) \
    -e LOCAL_GROUP_ID=\$(id -g) \
    -e LOCAL_SYSTEM=\$(uname -s) \
    -e PGDATA=/usr/local/meritcommons/var/pgsql/data \
    -e PERL5LIB=/usr/local/meritcommons/meritcommons/lib:/usr/local/meritcommons/plugins/lib \
    -e MERITCOMMONS_DEBUG=\$MERITCOMMONS_DEBUG \
    -e MERITCOMMONS_NO_PLUGINS=\$MERITCOMMONS_NO_PLUGINS \
    -e MERITCOMMONS_PLUGINS_DEBUG=\$MERITCOMMONS_PLUGINS_DEBUG \
    -e SELENIUM_TESTING=\$SELENIUM_TESTING";
DOCKER_PMAP="-p 127.0.0.1:3000:3000/tcp";
DOCKER_IMAGE="$docker_repo/meritcommons/docker-tools";
DOCKER_EXEC_USER="meritcommons";

if [ -t 1 ]
then
    DOCKER_INTERACTIVE="-i";
fi

if [ ! -z "\$STAY_ROOT" ]
then
    DOCKER_ENV="-e STAY_ROOT=1 \${DOCKER_ENV}";
    DOCKER_EXEC_USER="root";
fi

if [ ! -z "\$SKIP_DB" ]
then
    DOCKER_ENV="-e SKIP_DB=1 \${DOCKER_ENV}";
fi

set_exec() {
    STOPPED_CONTAINER=\$(docker ps -q --filter=status=exited --filter=name=meritcommons-docker-tools | tr -d '\\n');
    if [ ! -z "\$STOPPED_CONTAINER" ]
    then
        echo "[docker-tools] restarting 'stopped' container \$STOPPED_CONTAINER";
        docker start \$STOPPED_CONTAINER;
    fi
    RUNNING_CONTAINER=\$(docker ps -q --filter=name=meritcommons-docker-tools | tr -d '\\n');
    if [ ! -z "\$RUNNING_CONTAINER" ]
    then
        # run the command as the meritcommons user in the currently booted and running container
        DOCKER_EXEC="docker exec \$DOCKER_INTERACTIVE -t -u \$DOCKER_EXEC_USER \$RUNNING_CONTAINER";
    else
        # start and boot the container
        DOCKER_EXEC="docker run \$DOCKER_INTERACTIVE -t --rm --name meritcommons-docker-tools \$DOCKER_VMAP \$DOCKER_ENV \$DOCKER_PMAP -u root \$DOCKER_IMAGE boot.pl"
    fi
}

EOF
}

sub get_home {
    $c->{adt_home} = prompt(
        "What directory should set up shop in? [$ENV{HOME}/MeritCommonsDocker] ", 
        -td => "$ENV{HOME}/MeritCommonsDocker"
    );
}

sub get_core_repo {
    $c->{core_repo} = prompt(
        "What repository should we load MeritCommons Core from? [git\@git.meritcommons.io:meritcommons/core.git] ", 
        -td => 'git@git.meritcommons.io:meritcommons/core.git'
    );
}

sub get_plugins_repo {
    $c->{plugins_repo} = prompt(
        "What repository should we load MeritCommons Plugins from? [git\@git.meritcommons.io:meritcommons/plugins.git] ",
        -td => 'git@git.meritcommons.io:meritcommons/plugins.git'
    );
}

sub get_common_repo {
    $c->{common_repo} = prompt(
        "What repository should we load theme and plugin customizations from? [git\@git.meritcommons.io:wayne-state/common.git] ", 
        -td => 'git@git.meritcommons.io:wayne-state/common.git'
    );
}


