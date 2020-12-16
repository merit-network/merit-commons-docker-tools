# MeritCommons Docker Tools

This repository contains a Dockerfile for building an MeritCommons image as well as scripts that
can be used to run MeritCommons commands in ways that emulate a local install to the best of its
ability.

## Make sure docker.io, curl and git are installed on your machine

 * Debian derived: `sudo apt-get install docker.io git curl`
 * macOS: `curl` should already be installed, install XCode for `git`.  See https://docs.docker.com/engine/installation/mac/ for instructions on getting Docker installed
 * RHEL/CentOS: install newer verisons of `git` and `curl` from EPEL and install Docker using these instructions: https://docs.docker.com/engine/installation/linux/centos/ 

## MeritCommons Docker Tools Installation Methods

### The super quick way (completely legit)
 `curl -s https://git.meritcommons.io/meritcommons/docker-tools/raw/master/bin/adt-install.sh | sudo bash`

**Note**: if you get an error like 
> Cannot write to terminal: No such device or address at /home/bratwurst/meritcommons-docker-tools/bin/setup.pl

Simply run `~/meritcommons-docker-tools/bin/setup.pl` as your regular user.  Some OSes let us do weird things with TTYs and some don't, but the setup is interactive and so it needs to interact with you.  All of the root work should be done by the point you get this error message anyway, so don't worry about sudo.

### The less quick way
 * Install cpanminus 
  * curl -L https://cpanmin.us | perl - --sudo App::cpanminus
 * Clone this repository and install deps
  * git clone git@git.meritcommons.io:meritcommons/docker-tools.git ~/meritcommons-docker-tools
  * cd ~/meritcommons-docker-tools
  * cpanm --installdeps .
 * run `bin/setup.pl`
 * Answer a few questions
 * Grab a cup of coffee, build and setup could take 20-30 minutes

### Notes
 * Files in `~/.config/meritcommons_dockertools/etc/` will be installed automagically in `meritcommons/etc` of your
   development environment
 * The `ad_subl` command will open all three major components of your development environment using `subl`, 
   if you aren't using Sublime Text or don't have the `subl` helper set up yet, then it will do nothing for
   you.
 * The only environment variable currently honored from the calling side is `MERITCOMMONS_DEBUG`, more may be
   honored in time.
 * The `development` bootloader is the one you want to use if you are going to be using these tools to work
   on MeritCommons

### Caution

This may or may not break your existing MeritCommons development environment so if everything's 
already working fine for you on your workstation please review the script and run at your own
peril!  _if it ain't broke, don't fix it_.  At this point in time though, it is extremely likely
that containers will become the default way to deploy MeritCommons in production.  So, if you want
your development environment to be more like production this is by far the best way to go.

### Getting Rid of your old MeritCommons Development Environment

 * Copy your config out to a place where it will be automatically installed in the MeritCommons Docker Tools environment: 

`mkdir -p ~/.config/meritcommons_dockertools/etc/ && rsync -avpr --progress /usr/local/meritcommons/meritcommons/etc/ ~/.config/meritcommons_dockertools/etc/` 

 * make sure to `git commit` and `git push` all local changes up to the repo and blow away your old MeritCommons setup

`rm -rf /usr/local/meritcommons`

 * Make sure to remove references to `.sysbashrc` from `~/.bashrc` and `~/.bash_profile` or your shell of choice's corresponding configurations (they _will_ conflict with `meritcommons/docker-tools`)
