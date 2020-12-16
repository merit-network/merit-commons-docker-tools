#!/usr/bin/env perl

print "DBD::Oracle builder\n";
print "(c) 2016 Detroit Collaboration Works, LLC\n";

system("mkdir /usr/local/oracle");
chdir("/usr/local/oracle");

local $| = 1;

my ($has_sqlplus, $detected_version);
print "Installing Instant Client...";
foreach my $file (`ls /tmp/instant_client`) {
  chomp $file;
  next if $file eq "build_dbd_oracle.pl";

  if ($file =~ /sqlplus/) {
    $has_sqlplus = 1;
  }
  if ($file =~ /\-(\d+\.\d+\.\d+\.\d)\.zip$/) {
    $detected_version = $1;
  }
  system("unzip -qq -o /tmp/instant_client/$file");
}

my $ic_dir = `ls -d /usr/local/oracle/*`;
chomp $ic_dir;

system("ln -s $ic_dir/* /usr/local/oracle");

print " done.\n";

# set up environment
$ENV{ORACLE_HOME} = '/usr/local/oracle';
$ENV{LD_LIBRARY_PATH} = $ENV{LD_LIBRARY_PATH} ? "/usr/local/oracle:$ENV{LD_LIBRARY_PATH}" : "/usr/local/oracle";
open my $fh, '>>', "$ENV{HOME}/.profile";
print $fh "export ORACLE_HOME=$ENV{ORACLE_HOME}\n";
print $fh "export LD_LIBRARY_PATH=$ENV{LD_LIBRARY_PATH}\n";
close $fh;

if ($has_sqlplus) {
  system("cpanm --notest DBD::Oracle");
} else {
  system("cpanm --look DBD::Oracle");
  system("perl ./Makefile.PL -V $detected_version");
  system("make");
  system("make install");
}

print "Work complete, exiting.\n";
