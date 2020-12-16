#
# vlad assures you this is totally legit.
#
curl -sL https://cpanmin.us | perl - --sudo App::cpanminus
SUDO_USER_HOME=$(eval echo "~$SUDO_USER");
su $SUDO_USER -c "git clone git@git.meritcommons.io:meritcommons/docker-tools.git ~/meritcommons-docker-tools"
cd "${SUDO_USER_HOME}/meritcommons-docker-tools"
cpanm --installdeps .
su $SUDO_USER -c "PATH=/bin:/usr/bin:/usr/local/bin:${SUDO_USER_HOME}/bin ~/meritcommons-docker-tools/bin/setup.pl"
exit