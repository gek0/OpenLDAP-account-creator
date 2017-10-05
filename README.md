# OpenLDAP-account-creator
Create LDAP account for new employees

About
-----
Bash script used to account for new employees.

Password hashing algorithms available are `MD5`, `Crypt` or `SSHA` which is strongest and recommended.

User info added: `groupUid`, `userUid`, `email`, `username`, `loginShell`, `homeDirectory` and others.

This script is available to everyone for forking, sending commit request...

If you like it, star it, use it or anything else. :)

Testing environment
----------------
* OS: Ubuntu 16.04.3 LTS (Xenial) x86_64
* Shell: Bash, 4.3.48(1)-release
* OpenLDAP server, slapd utility: openldap-2.4.42

Usage
-----
All variables needed should be defined on top of the script.

OpenLDAP server password is asked on every run.

Requires `sudo` privileges if no LDAP utilty is installed or utility for sending mails (if used).

Run as any other BASH script - `./ldap_account.sh` or `source ldap_account.sh`.


More Information
----------------
* [OpenLDAP documnetation](http://www.openldap.org/)
* [ldapadd utility | man pages](http://www.openldap.org/software//man.cgi?query=ldapadd&sektion=1&apropos=0&manpath=OpenLDAP+2.4-Release)
* [ldapsearch utility | man pages](http://www.openldap.org/software//man.cgi?query=ldapsearch&apropos=0&sektion=1&manpath=OpenLDAP+2.4-Release&format=html)
* [ldapwhoami utility | man pages](http://www.openldap.org/software//man.cgi?query=ldapwhoami&apropos=0&sektion=1&manpath=OpenLDAP+2.4-Release&format=html)
* [LDAP configuration | ldap.conf](http://www.openldap.org/software//man.cgi?query=ldap.conf&sektion=5&apropos=0&manpath=OpenLDAP+2.4-Release)