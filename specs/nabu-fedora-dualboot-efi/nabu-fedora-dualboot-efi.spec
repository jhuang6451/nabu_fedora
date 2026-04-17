%global debug_package %{nil}

Name:           nabu-fedora-dualboot-efi
Version:        0.1
Release:        1%{?dist}
BuildArch:      aarch64
Summary:        rEFInd boot manager files for dual-booting on Xiaomi Pad 5 (nabu)
License:        GPLv3+ and others
URL:            https://github.com/jhuang6451/nabu_fedora
Source0:        https://github.com/jhuang6451/nabu_fedora_packages/releases/download/%{name}-%{version}/%{name}-%{version}.tar.gz

%description
This package installs the rEFInd boot manager and theme files to the EFI
System Partition for dual-booting Fedora and Android on the Xiaomi Pad 5 (nabu).
It doesn't contain the UKI file needed to boot fedora, however,
for that's built during the kernel installing process.

%prep
%autosetup

%build
# Nothing to build, we are just packaging files.

%install
# The source tarball contains the 'boot' directory.
# We copy it into the buildroot.
cp -a boot %{buildroot}/

%files
%defattr(644, root, root, 755)
# Own the directories we are shipping to the ESP
/boot/efi/EFI/Android
/boot/efi/EFI/BOOT

%changelog
* Tue Sep 30 2025 jhuang6451 <xplayerhtz123@outlook.com> - 0.1-1
- Initial package creation
