package MeritCommons::DockerTools::Config;

# Object for parsing config files
# Copyright 2016 Detroit Collaboration Works, LLC

use Mojo::File;
use Data::Dumper;

sub new {
    my ($class) = @_;

    my $file = "$ENV{HOME}/.config/meritcommons_dockertools/adt.conf";
    my $config = {};
    if (-e $file) {
        my $content = Mojo::File->new($file)->slurp;

        # Run Perl code in sandbox
        $config = eval 'package MeritCommons::DockerTools::Config::Sandbox; no warnings;'
            . "use Mojo::Base -strict; $content";

        die qq{Can't load configuration from file "$file": $@} if $@;

        die qq{Configuration file "$file" did not return a hash reference.\n}
        unless ref $config eq 'HASH';
    }

    return bless $config, $class;
}

sub save {
    my ($self) = @_;
    # write this config out.
    unless (-d "$ENV{HOME}/.config/meritcommons_dockertools") {
        system("mkdir -p $ENV{HOME}/.config/meritcommons_dockertools");
    }

    # sanitize this object.
    my $config;
    foreach my $key (keys %$self) {
        $config->{$key} = "$self->{$key}";
    }

    local $Data::Dumper::Terse = 1;
    open my $new_file, '>', "$ENV{HOME}/.config/meritcommons_dockertools/adt.conf";
    print $new_file Dumper($config);
    close $new_file;
}

1;