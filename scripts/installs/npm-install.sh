#!/bin/bash -x

set -euo pipefail
cd
test -d .nvm || git clone https://github.com/creationix/nvm.git .nvm

for PROFILE_FILE in \
    /etc/profile.d/node-env.sh \
        ${HOME}/.profile \
        ${HOME}/.bash_profile \
    ; do
    insert-text-block '# 69596022-9179-4a5c-be28-a6d12bcdc132-install-nvm' ${PROFILE_FILE} <<"EOF"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
EOF
done

cat<<EOF
NVM installed. Now run:


source ${HOME}/.profile;
nvm install stable
nvm alias default node
npm --version
EOF
