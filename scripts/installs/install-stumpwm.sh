#!/bin/bash -x

set -euo pipefail


APT_GET="apt-get"
if command -v yum; then
    APT_GET="yum"
fi

sudo ${APT_GET} install -y sbcl curl autoconf make texinfo rlwrap

sudo ${APT_GET} install -y xinit x11-xserver-utils \
     xbacklight xcalib xsel upower xscreensaver

QL_SETUP="${HOME}/quicklisp/setup.lisp"
if ! test -f "${QL_SETUP}"; then
    curl -O https://beta.quicklisp.org/quicklisp.lisp
    curl -O https://beta.quicklisp.org/quicklisp.lisp.asc
    gpg --verify quicklisp.lisp.asc quicklisp.lisp
    sbcl --load quicklisp.lisp --non-interactive --eval  \
	'(quicklisp-quickstart:install)'
    rm quicklisp.lisp{,.asc}
fi

ADDBLOCK=${HOME}/git/erjoalgo-gnu-scripts/insert-text-block

SBCLRC="${HOME}/.sbclrc"
if test ! -e "${SBCLRC}"; then
    # sbcl --load "${QL_SETUP}" --non-interactive --eval '(ql:add-to-init-file)' \
    # 	< /dev/null
    ${ADDBLOCK} ";;; 2a00bf58-9854-4512-8e13-a85409493a54-ql:add-to-init-file-manual" \
	"${SBCLRC}"<<EOF
  ;;; The following lines added by ql:add-to-init-file:
  #-quicklisp
  (let ((quicklisp-init (merge-pathnames "quicklisp/setup.lisp"
                                         (user-homedir-pathname))))
    (when (probe-file quicklisp-init)
      (load quicklisp-init)))
EOF
fi

sbcl --load "${SBCLRC}" --script /dev/stdin <<EOF
(mapcar 'ql:quickload
	'(
"clx"
"cl-ppcre"
"swank"
"quicklisp-slime-helper"
"usocket"
"alexandria"
))
EOF

mkdir -p "${HOME}/src" && cd "${HOME}/src"
cd "${HOME}/.local"

if ! test -d stumpwm; then
    git clone https://github.com/stumpwm/stumpwm.git
fi

STUMPWM="$(pwd)/stumpwm"
cd stumpwm

if ! command -v stumpwm; then #the executable
    ./autogen.sh
    ./configure
    make
    test -d ~/bin || mkdir ~/bin
    sudo make install
    # sudo ln -sf "${STUMPWM}/stumpwm" /usr/local/bin
fi

if command -v yum; then
   sudo yum groupinstall "X Window System";
fi


# autologin to stumpwm on tty1
ADDBLOCK=${HOME}/git/erjoalgo-gnu-scripts/insert-text-block
AUTOLOGIN_CONF="/etc/systemd/system/getty@tty1.service.d/autologin.conf"
sudo mkdir -p $(dirname "${AUTOLOGIN_CONF}")
sudo ${ADDBLOCK} '# e8a6c230-997f-4dd5-9b57-7e3b31ab67bc'  \
     "${AUTOLOGIN_CONF}" <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin "${USER}" %I
EOF

sudo ${APT_GET} install -y nc