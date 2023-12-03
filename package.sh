#!/bin/sh -e
# Copyright (c) 2023 Roger Brown.
# Licensed under the MIT License.

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

if test -d "$CONFIGFILE.d"
then
	mkdir -p "data$CONFIGFILE.d"
	echo "$CONFIGURATION" > "data$CONFIGFILE.d/50-$PKGNAME.conf"
fi

if dpkg --print-architecture 2>/dev/null
then
	if test -z "$MAINTAINER"
	then
		echo MAINTAINER must be specified >&2
		false
	fi

	if test -d data/etc
	then
		DEPENDS="openssh-server (>= 7.3), powershell"
	else
		DEPENDS="openssh-server, powershell"
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
	fi

	DEBFILE="$PKGNAME"_"$VERSION"-"$RELEASE"_"$DPKGARCH".deb

	cat > control/control <<EOF
Package: $PKGNAME
Version: $VERSION-$RELEASE
Architecture: $DPKGARCH
Maintainer: $MAINTAINER
Section: admin
Priority: extra
Depends: $DEPENDS
Description: PowerShell Remote Access for OpenSSH
EOF

	for d in control data
	do
		(
			set -e
			cd $d
			if test -z "$(find . -type f)"
			then
				tar --owner=0 --group=0 --create --gzip --file ../$d.tar.gz --files-from /dev/null
			else
				find * -type f | tar --owner=0 --group=0 --create --gzip --file ../$d.tar.gz --files-from -
			fi
		)
	done

	rm -rf "$DEBFILE"

	echo "2.0" >debian-binary

	ar r "$DEBFILE" debian-binary control.tar.* data.tar.*
fi

if rpmbuild --version 2>/dev/null
then
	if test -d data/etc
	then
		REQUIRES="powershell, openssh-server >= 7.3"
	else
		REQUIRES="powershell, openssh-server"
	fi

	(
		cat <<EOF
Summary: PowerShell Remote Access for OpenSSH
Name: $PKGNAME
Version: $VERSION
Release: $RELEASE
Group: Applications/System
License: MIT
Requires: $REQUIRES
BuildArch: noarch
Prefix: /
%description
Enable remote PowerShell access for OpenSSH

EOF

	if test -d data/etc
	then
		cat << EOF
%files
%defattr(-,root,root)
EOF

		(
			cd data
			find etc -type f | while read N
			do
				echo "/$N"
			done
		)

		cat << EOF
%clean
EOF
	else
		cat << EOF
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
		fi
	) > rpm.spec

	PWD=$(pwd)
	rpmbuild --buildroot "$PWD/data" --define "_rpmdir $PWD/rpms" -bb "$PWD/rpm.spec"

	find rpms -type f -name "*.rpm" | while read N
	do
		mv "$N" .
		basename "$N"
	done
fi
