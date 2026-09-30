# iptsd (alex-lentz-Fork mit haptischem Klick fuer das Surface Laptop 7) als Fedora-RPM.
# Gebaut im aarch64-Chroot mit Fedoras Toolchain (einheitliche branch-protection-Flags, kein SIGILL).
%global commit 3663e96
Name:           iptsd
Version:        3
Release:        0.sl7.git%{commit}%{?dist}
Summary:        Userspace daemon for Surface touch devices (SL7 haptic touchpad fork)
License:        GPL-2.0-or-later
URL:            https://github.com/alex-lentz/iptsd
Source0:        iptsd-%{commit}.tar.gz
BuildRequires:  meson ninja-build gcc-c++ cmake pkgconf-pkg-config
BuildRequires:  cli11-devel eigen3-devel fmt-devel inih-devel spdlog-devel guidelines-support-library-devel
BuildRequires:  systemd-rpm-macros
Requires:       systemd-udev
Provides:       iptsd-sl7 = %{version}-%{release}

%description
Fork of linux-surface/iptsd by alex-lentz: adds the haptic (force) click of the
Surface Laptop 7 touchpad (frame 0x94 button bit -> BTN_LEFT), a sleep hook and
click debouncing. Built for the SL7 Fedora KDE image.

%prep
%autosetup -n iptsd-%{commit}

%build
%meson -Dsample_config=true -Dservice_manager=systemd -Ddebug_tools=calibrate,dump,perf
%meson_build

%install
%meson_install
install -d %{buildroot}%{_sysconfdir}/iptsd.d
find %{buildroot} \( -type f -o -type l \) | sed "s|^%{buildroot}||" | grep -v '^/etc/iptsd.conf$' > files.list

%post
%udev_rules_update

%files -f files.list
%config(noreplace) %{_sysconfdir}/iptsd.conf
%dir %{_sysconfdir}/iptsd.d

%changelog
* Tue Sep 22 2026 Martin (SL7-Projekt) - 3-0.sl7.git3663e96
- Fork alex-lentz/iptsd @3663e96 (2026-07-16) fuer Surface Laptop 7
