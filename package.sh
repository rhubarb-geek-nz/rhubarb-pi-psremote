#!/bin/sh -e
#
#  Copyright 2022, Roger Brown
#
#  This file is part of rhubarb pi.
#
#  This program is free software: you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation, either version 3 of the License, or (at your
#  option) any later version.
# 
#  This program is distributed in the hope that it will be useful, but WITHOUT
#  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
#  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
#  more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>
#
# $Id: package.sh 198 2022-09-25 11:56:06Z rhubarb-geek-nz $
#

cleanup()
{
	rm -rf control.tar.* control data data.tar.* debian-binary rpm.spec rpms
}

cleanup

rm -f *.deb *.rpm

trap cleanup 0

VERSION="1.0"
DPKGARCH=all
RELEASE=$(echo $(git log --oneline "$0" | wc -l))
PKGNAME=rhubarb-pi-psremote
CONFIGURATION="Subsystem powershell /usr/bin/pwsh -sshs -nologo"
CONFIGFILE=/etc/ssh/sshd_config

mkdir control data

if dpkg --print-architecture 2>/dev/null
then
	if test -z "$MAINTAINER"
	then
		echo MAINTAINER must be specified >&2
		false
	fi

	cat > control/postinst << EOF
#!/bin/sh -e
if grep "^$CONFIGURATION\$" $CONFIGFILE >/dev/null
then
	:
else
	if test "$( tail -c 1 $CONFIGFILE )" != ""
	then
		echo >> $CONFIGFILE
	fi
	echo "$CONFIGURATION" >> $CONFIGFILE
fi
EOF

	cat > control/postrm << EOF
#!/bin/sh -e
if grep "^$CONFIGURATION\$" $CONFIGFILE >/dev/null
then
	grep -v "^$CONFIGURATION\$" < "$CONFIGFILE" > "$CONFIGFILE~"
	cat "$CONFIGFILE~" > "$CONFIGFILE"
	rm "$CONFIGFILE~"
fi
EOF

	chmod +x control/postinst control/postrm

	mkdir -p data

	DEBFILE="$PKGNAME"_"$VERSION"-"$RELEASE"_"$DPKGARCH".deb

	cat > control/control <<EOF
Package: $PKGNAME
Version: $VERSION-$RELEASE
Architecture: $DPKGARCH
Maintainer: $MAINTAINER
Section: admin
Priority: extra
Depends: openssh-server, powershell
Description: PowerShell Remote Access for OpenSSH
EOF

	for d in control data
	do
		(
			set -e
			cd $d
			if test -f control
			then
				tar --owner=0 --group=0 --create --gzip --file ../$d.tar.gz control postinst postrm
			else
				tar --owner=0 --group=0 --create --gzip --file ../$d.tar.gz --files-from /dev/null
			fi
		)
	done

	rm -rf "$DEBFILE"

	echo "2.0" >debian-binary

	ar r "$DEBFILE" debian-binary control.tar.* data.tar.*
fi

if rpmbuild --version 2>/dev/null
then
	cat >rpm.spec <<EOF
Summary: PowerShell Remote Access for OpenSSH
Name: $PKGNAME
Version: $VERSION
Release: $RELEASE
Group: Applications/System
License: GPL
Requires: powershell, openssh-server
BuildArch: noarch
Prefix: /
%description
Enable remote PowerShell access for OpenSSH

%post
if test "\$1" -eq 1
then
	(
		set -e
		if grep "^$CONFIGURATION\$" $CONFIGFILE >/dev/null
		then
			:
		else
			if test "$( tail -c 1 $CONFIGFILE )" != ""
			then
				echo >> $CONFIGFILE
			fi
			echo "$CONFIGURATION" >> $CONFIGFILE
		fi
	)
fi
%postun
	(
		set -e
		if grep "^$CONFIGURATION\$" $CONFIGFILE >/dev/null
		then
			grep -v "^$CONFIGURATION\$" < "$CONFIGFILE" > "$CONFIGFILE~"
			cat "$CONFIGFILE~" > "$CONFIGFILE"
			rm "$CONFIGFILE~"
		fi
	)
%files
%clean
EOF

	PWD=$(pwd)
	rpmbuild --buildroot "$PWD/data" --define "_rpmdir $PWD/rpms" -bb "$PWD/rpm.spec"

	find rpms -type f -name "*.rpm" | while read N
	do
		rpm -qlvp "$N"
		mv "$N" .
		basename "$N"
	done
fi
