# Third-party package licenses and provenance

The root [LICENSE](../LICENSE) is the existing MIT license of the SFTP project's own files. Changing the Linux distribution used by the container does not automatically change that license. This file is an inventory prompt, **not a legal compliance certification**.

Alpine packages are independently licensed. In the Alpine edge package index:
- `whois` is provided in **edge/community** and is marked **GPL-2.0-or-later**.
- OpenSSH, Fail2Ban, Bash, rsyslog, BusyBox, musl, iptables, nftables and other dependencies each have their own licenses; inspect exact versions and transitive packages at build time.
- License information can be queried from the Alpine APK package metadata; availability and exact licenses can change across edge updates.

Before publishing an image:
1. Generate a package inventory and SBOM for the actual image digest.
2. Preserve required copyright/license notices, and satisfy any applicable GPL notice/source-offer obligations for binaries being distributed.
3. Keep third-party software licenses distinct from the project's MIT license.
4. Recheck the inventory after rolling edge upgrades and image rebuilds.
5. Do not describe any build as FIPS-certified or CISA-certified without appropriate evaluation.

References:
- https://pkgs.alpinelinux.org/package/edge/community/x86_64/whois
- https://wiki.alpinelinux.org/wiki/Creating_an_Alpine_package
- https://wiki.alpinelinux.org/wiki/Package_policies
