#!/usr/bin/env bash

set -e
UNAME=`uname| tr '[:upper:]' '[:lower:]'`
SED_SUFF=$([ "$UNAME" = "darwin" ] && echo ' ""' || echo "")
RL_SUFF=$([ "$UNAME" = "darwin" ] && echo "" || echo " -f")
SCRIPT_DIR=$(dirname -- "$(readlink "$RL_SUFF" "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")

mkdir -p $SCRIPT_DIR/testdir/bin $SCRIPT_DIR/testdir/helm
export PATH=$SCRIPT_DIR/testdir/bin:$PATH
TEST_REPO=chart-testing-action
TEST_REPO_VERSION=v1.0.0
KIND_REPO=kind-action
KIND_REPO_VERION=v1.0.0-alpha.3
INPUT_CONFIG=ct.yaml

Setup() {
	if [ ! -f $SCRIPT_DIR/testdir/bin/helm > /dev/null 2>&1 ]; then
		wget https://get.helm.sh/helm-v3.0.2-$UNAME-amd64.tar.gz
		tar -zxf helm-v3.0.2-$UNAME-amd64.tar.gz -C $SCRIPT_DIR/testdir/helm
		rm -f helm-v3.0.2-$UNAME-amd64.tar.gz
		cp $SCRIPT_DIR/testdir/helm/$UNAME-amd64/helm $SCRIPT_DIR/testdir/bin/helm
	    	chmod +x $SCRIPT_DIR/testdir/bin/helm
	fi
	rm -f $SCRIPT_DIR/testdir/chart-changed
	pushd $SCRIPT_DIR/testdir > /dev/null
		local dr=$TEST_REPO
		if [ ! -d $dr ]; then
			git clone https://github.com/helm/$dr.git
			pushd $dr > /dev/null
				git checkout tags/$TEST_REPO_VERSION -b dgraph-test
				sed -i$SED_SUFF \
					-e 's|run_ct$|touch\ '$SCRIPT_DIR'/testdir/chart-changed;run_ct|' \
					ct.sh
			popd > /dev/null
		fi
		dr=$KIND_REPO
		if [ ! -d $dr ]; then
			git clone https://github.com/helm/$dr.git
			pushd $dr > /dev/null
				git checkout tags/$KIND_REPO_VERION -b dgraph-test
				sed -i$SED_SUFF \
					-e 's|/usr/local|'$SCRIPT_DIR'/testdir|' \
					-e 's/linux/'$UNAME'/' \
					-e 's|install_kind$|[\ !\ -f\ '$SCRIPT_DIR'/testdir/bin/kind\ ]\ \&\& install_kind|' \
					-e 's|install_kubectl$|[\ !\ -f\ '$SCRIPT_DIR'/testdir/bin/kubectl\ ]\ \&\& install_kind|' \
					-e 's/sudo//' \
					kind.sh
			popd > /dev/null
		fi
	popd > /dev/null
	kind delete cluster --name chart-testing > /dev/null 2>&1 || true
}

Lint() {
	INPUT_COMMAND=lint INPUT_CONFIG=$INPUT_CONFIG bash $SCRIPT_DIR/testdir/$TEST_REPO/main.sh
}

SetupKind() {
	if [ -f $SCRIPT_DIR/testdir/chart-changed ]; then
		INPUT_INSTALL_LOCAL_PATH_PROVISIONER=1 bash $SCRIPT_DIR/testdir/$KIND_REPO/main.sh
	fi
}

InstallTest() {
	INPUT_COMMAND=install INPUT_CONFIG=$INPUT_CONFIG bash $SCRIPT_DIR/testdir/$TEST_REPO/main.sh
}

GoTests() {
	pushd $SCRIPT_DIR/tests > /dev/null
		go test -v .
	popd > /dev/null
}

if [ ! -z "$RELEASE" ]; then
	INPUT_CONFIG=ct-rel.yaml
fi

if [ -z "$1" ]; then
	Setup
	Lint
	SetupKind
	InstallTest
	GoTests
else
	$1
fi
