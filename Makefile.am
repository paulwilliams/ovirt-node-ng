# Copyright (C) 2016 Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

SQUASHFSFILENAME = @IMAGENAME@.squashfs.img
RPMMANIFESTNAME = @IMAGENAME@.manifest-rpm
RPMUNSIGNEDNAME = @IMAGENAME@.unsigned-rpms
INSTALLEDIMAGEFILE = @IMAGENAME@.installed.qcow2

docbookdir = $(prefix)/share/doc/@PACKAGE_NAME@/book
docbookimgsdir = $(prefix)/share/doc/@PACKAGE_NAME@/book/imgs
nodetoolsdir = $(prefix)/share/@PACKAGE_NAME@/tools

EXTRA_DIST = \
	docs/man/nodectl.8 \
	scripts/nodectl-motd.sh \
	scripts/nodectl-run-banner.sh

SUBDIRS = \
	src \
	$(NULL)

man_MANS = \
	docs/man/nodectl.8 \
	$(NULL)

dist_doc_DATA = \
	README \
	$(NULL)

dist_docbook_DATA = \
	docs/book/administration.md \
	docs/book/book.json \
	docs/book/build.md \
	docs/book/cover.jpg \
	docs/book/customization.md \
	docs/book/design.md \
	docs/book/engine.md \
	docs/book/fsh.md \
	docs/book/getting-started.md \
	docs/book/install.md \
	docs/book/testing.md \
	docs/book/upgrade.md \
	docs/book/imgs/build-flow.dot \
	$(NULL)

dist_docbookimgs_DATA = \
	docs/book/imgs/build-flow.dot \
	docs/book/imgs/build-flow.dot.png \
	docs/book/imgs/ngn-flow-components.dot \
	docs/book/imgs/ngn-flow-components.dot.png \
	docs/book/imgs/ngn-flow.dot \
	docs/book/imgs/ngn-flow.dot.png \
	$(NULL)

dist_nodetools_DATA = \
	scripts/create-nightly-boot-iso.sh \
	scripts/derive-boot-iso.sh \
	scripts/liveimg-comparison.sh \
	scripts/node-inject.sh \
	$(NULL)

dist_bin_SCRIPTS = \
	scripts/create-node-installation-iso \
	$(NULL)

dist_sbin_SCRIPTS = \
	scripts/nodectl \
	$(NULL)

debug-ks: data/@IMAGENAME@.ks
	sed -i 's/^poweroff/#poweroff/' $<

# Building a "LiveOS" vm for debugging ks issues
debug-squashfs: LMCOPTS=--vnc vnc
debug-squashfs: | debug-ks $(SQUASHFSFILENAME)
	@echo debug-squashfs $(SQUASHFSFILENAME)

squashfs: $(SQUASHFSFILENAME) $(RPMMANIFESTNAME) $(RPMUNSIGNEDNAME)
	@echo squashfs: $(SQUASHFSFILENAME)
	@echo squashfs rpm-manifest: $(RPMMANIFESTNAME)
	@echo squashfs rpm-unsigned: $(RPMUNSIGNEDNAME)

installed-squashfs: DOMNAME=node-$(shell date +%F-%H%M)
installed-squashfs: data/ci-image-install.ks $(SQUASHFSFILENAME) @BOOTISO@
	qemu-img create -f qcow2 $(INSTALLEDIMAGEFILE) 63G
	virt-install \
		--name $(DOMNAME) \
		--boot menu=off \
		--network none \
		--memory 4096 \
		--vcpus 4 \
		--os-variant rhel7 \
		--rng random \
		--noreboot \
		--location @BOOTISO@ \
		--extra-args "inst.ks=file:///ci-image-install.ks console=ttyS0" \
		--initrd-inject data/ci-image-install.ks \
		--check disk_size=off,path_in_use=off \
		--graphics none \
		--wait 60 \
		--disk path=$(INSTALLEDIMAGEFILE),bus=virtio,cache=unsafe,discard=unmap,format=qcow2 \
		--disk path=$(SQUASHFSFILENAME),readonly=on,device=disk,bus=virtio,serial=livesrc
	virsh dumpxml $(DOMNAME) > installed-squashfs-domain.xml
	virsh undefine $(DOMNAME)
	@echo "The squashfs '$(SQUASHFSFILENAME)' got installed into the file '$(INSTALLEDIMAGEFILE)'"

debug-installed: installed-squashfs
	virsh define installed-squashfs-domain.xml

product.img:
	bash scripts/create-product-img.sh $@

offline-installation-iso: product.img
	PRODUCTIMG=$(PWD)/product.img BOOTISO=$(BOOTISO) SQUASHFS=$(SQUASHFSFILENAME) DERVICEBOOTISOSCRIPT=scripts/derive-boot-iso.sh bash scripts/create-nightly-boot-iso.sh

@BOOTISO@:
	curl $(CURLOPTS) -O @BOOTISOURL@

LMC ?= livemedia-creator
%.squashfs.img: data/%.ks @BOOTISO@
	$(LMC) $(LMCOPTS) --kernel-args="inst.nosave=all" --make-pxe-live --iso @BOOTISO@ --ks $< --resultdir build --tmp @TMPDIR@
	mv -v build/*squash* "$@"

# Short TMPDIR otherwise we run into trouble with guestfish < 1.33.27-1.fc24
# # -x -v to be more verbose
IN_ROOTFS=export LIBGUESTFS_TMPDIR=/var/tmp ; guestfish --ro -a $(SQUASHFSFILENAME) run : mount /dev/sda / : mount-loop /LiveOS/rootfs.img / : sh
$(RPMMANIFESTNAME): $(SQUASHFSFILENAME)
	$(IN_ROOTFS) "rpm -qa" > $@

$(RPMUNSIGNEDNAME): $(SQUASHFSFILENAME)
	$(IN_ROOTFS) "rpm -qa --qf '%{name}-%{version}-%{release}.%{arch} (%{SIGPGP:pgpsig})\n'" | grep -v "Key ID" > $@

packaging/ovirt-node-ng.spec: PLACEHOLDER_RPM=ovirt-node-ng-image-update-placeholder
packaging/ovirt-node-ng.spec: PLACEHOLDER_RPM_VERSION=$(shell $(IN_ROOTFS) "rpm -q --qf %{version} $(PLACEHOLDER_RPM)")
packaging/ovirt-node-ng.spec: PLACEHOLDER_RPM_RELEASE=$(shell $(IN_ROOTFS) "rpm -q --qf %{release} $(PLACEHOLDER_RPM)")
packaging/ovirt-node-ng.spec: packaging/ovirt-node-ng.spec.in
	sed \
		-e "s/\@WITH_IMAGE\@/$(WITH_IMAGE)/" \
		-e "s/\@IMAGENAME\@/$(IMAGENAME)/" \
		-e "s/\@PACKAGE_VERSION\@/$(PACKAGE_VERSION)/" \
		-e "s/\@PACKAGE_RPM_VERSION\@/$(PACKAGE_RPM_VERSION)/" \
		-e "s/\@PACKAGE_RPM_RELEASE\@/$(PACKAGE_RPM_RELEASE)/" \
		-e "s/\@PLACEHOLDER_RPM_VERSION\@/$(PLACEHOLDER_RPM_VERSION)/" \
		-e "s/\@PLACEHOLDER_RPM_RELEASE\@/$(PLACEHOLDER_RPM_RELEASE)/" \
		-e "s/\@DOCS\@/$(DOCS)/" \
		-e "s/\@TOOLS\@/$(TOOLS)/" \
		$< > $@

RPMBUILD = rpmbuild
TMPREPOS = tmp.repos

if WITH_IMAGE
rpm srpm: packaging/ovirt-node-ng.spec $(RPMMANIFESTNAME) $(RPMUNSIGNEDNAME) $(SQUASHFSFILENAME) product.img
else
rpm srpm: packaging/ovirt-node-ng.spec
endif
	rm -fr "$(TMPREPOS)"
	mkdir -p $(TMPREPOS)/{SPECS,RPMS,SRPMS,SOURCES}
	make dist
	$(RPMBUILD) \
		--define="_topdir `pwd`/$(TMPREPOS)" \
		--define "_sourcedir `pwd`" \
		-ba packaging/ovirt-node-ng.spec
	@echo
	@echo "srpm and rpm(s) available at '$(TMPREPOS)'"
	@echo

clean-local:
	-rm -vrf $(SQUASHFSFILENAME) $(RPMMANIFESTNAME) $(RPMUNSIGNEDNAME) $(INSTALLEDIMAGEFILE) packaging/ovirt-node-ng.spec build

# If you wonder, check does not depend on installed-squashfs, because we do not
# # want to enforce a rebuild if check is called
check:
	$(MAKE) -C tests check

clean-build-and-check: | clean squashfs installed-squashfs check
	echo Done
