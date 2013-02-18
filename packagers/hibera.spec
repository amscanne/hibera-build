Name: hibera
Summary: %{summary}
Version: %{version}
Release: %{release}
Group: System
License: Apache
URL: %{url}
Packager: %{maintainer}
BuildArch: %{architecture}
BuildRoot: %{_tmppath}/%{name}.%{version}-buildroot

# To prevent ypm/rpm/zypper/etc from complaining about FileDigests when
# installing we set the algorithm explicitly to MD5SUM. This should be
# compatible across systems (e.g. RedHat or openSUSE) and is backwards
# compatible.
%global _binary_filedigest_algorithm 1

%description
%{summary}

%install
rm -rf $RPM_BUILD_ROOT
install -d $RPM_BUILD_ROOT
rsync -rav --delete ../../dist/* $RPM_BUILD_ROOT

%files
/usr/
/etc/init.d/hibera
%config /etc/hibera.conf

%post
chkconfig --add hibera
exit 0
%preun
if [ "$1" = 0 ] ; then
    /etc/init.d/hibera stop
    chkconfig --del hibera
fi
exit 0
%postun
if [ "$#" -gt "1" ]; then
    if /etc/init.d/hibera status | grep running; then
        /etc/init.d/hibera restart
    fi
fi
exit 0

%changelog
* Sun Feb 17 2013 Adin Scannell <adin@scannell.ca>
- Initial package creation.
