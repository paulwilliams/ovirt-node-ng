# vim: et sts=2 sw=2

set -ex

# Fix to get all branch informations
git -c remote.origin.fetch=+refs/heads/*:refs/remotes/origin/* fetch

export BRANCH=${GIT_BRANCH:-$(git describe --all --contains HEAD | egrep -o "[^/]*$")}
export BRANCH=${BRANCH#*/}

export ARTIFACTSDIR=$PWD/exported-artifacts

export PATH=$PATH:/sbin:/usr/sbin
export TMPDIR=$PWD/tmp

export LIBGUESTFS_BACKEND=direct
# Short TMPDIR otherwise we run into trouble with guestfish < 1.33.27-1.fc24
# # -x -v to be more verbose
export LIBGUESTFS_TMPDIR=/var/tmp
export LIBGUESTFS_CACHEDIR=$LIBGUESTFS_TMPDIR

# Disabled for now, because we see outdated packages with the cache
## Only set a proxy if we can reach it
#export http_proxy=http://proxy.phx.ovirt.org:3128
#if curl -m 1 -o /dev/null --fail --proxy $http_proxy "http://www.ovirt.org"; then
#  export CURLOPTS="-x $http_proxy"
#  export LMCOPTS="--proxy $http_proxy"
#fi

save_logs() {
  sudo ln -fv \
    data/ovirt-node*.ks \
    *.log \
    "$ARTIFACTSDIR/"
}

trap save_logs EXIT

prepare() {
  mknod /dev/kvm c 10 232 || :
  virt-host-validate || :

  mkdir "$TMPDIR"
  mkdir "$ARTIFACTSDIR"
  echo "Defaults !requiretty" >> /etc/sudoers

  virsh list --name | xargs -rn1 virsh destroy || true
  virsh list --all --name | xargs -rn1 virsh undefine --remove-all-storage || true
  losetup -O BACK-FILE | grep iso$ | xargs -r umount -vf
}

build() {
  # Build the squashfs for a later export
  ./autogen.sh --with-tmpdir=/var/tmp

  sudo -E make squashfs
  sudo -E make product.img rpm
  sudo -E make offline-installation-iso

  sudo mv -fv ovirt-node-ng-image.squashfs.img \
              ovirt-node-ng-image-$(date +%Y%m%d).squashfs.img

  sudo ln -fv \
    *manifest* \
    *unsigned* \
    tmp.repos/SRPMS/*.rpm \
    tmp.repos/RPMS/noarch/*.rpm \
    ovirt-node*.squashfs.img \
    product.img \
    ovirt-node*.iso \
    "$ARTIFACTSDIR/"
}

check() {
  # script is used, because virt-install requires a tty
  # (which ain't available in Jenkins)
  touch lock
  timeout=1200 #in secs
  sudo -E script -efqc "make installed-squashfs && make check && rm -rf lock"
  set +x
  while [ -f lock ]; do
    if [ $timeout -eq 0 ];
    then
      echo "test timeout error"
      exit 1
    fi
    timeout=$(( timeout - 1 ))
    sleep 1
  done
  set -x

  sudo ln -fv \
    ovirt-node-ng-image.installed.qcow2 \
    "$ARTIFACTSDIR/"
}

checksum() {
  pushd "$ARTIFACTSDIR/"
  sha256sum * > CHECKSUMS.sha256 || :

  # Helper to redirect to latest installation iso
  INSTALLATIONISO=$(ls *.iso)
  cat << EOF > latest-installation-iso.html
<html>
  <head>
    <meta http-equiv='refresh' content='0; url="$INSTALLATIONISO"'/>
  </head>
  <body>
    If the download doesn't start, <a href="$INSTALLATIONISO">click here</a>
  </body>
</html>
EOF
  popd
}
prepare
build
# DISABLE checks until they are fixed
#check
checksum
