goto() {
    project=$1
    cd "$HOME${CLIENT_DIRECTORY}$project"
}

tw() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-web"
    code .
}

two() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-web"
}

tm() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-mobile"
    code .
}

tmo() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-mobile"
}

tb() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-backend"
    code .
}

tbo() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-backend"
}

ts() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-scripts"
    code .
}

tso() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-scripts"
}

tbs() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-batch-service"
    code .
}

tbso() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-batch-service"
}

fe() {
    cd "$HOME${CLIENT_DIRECTORY}ta_lms_fe"
}

feo() {
    cd "$HOME${CLIENT_DIRECTORY}ta_lms_fe"
    code .
}

be() {
    cd "$HOME${CLIENT_DIRECTORY}ta_lms_be"
}

beo() {
    cd "$HOME${CLIENT_DIRECTORY}ta_lms_be"
    code .
}

afe() {
    cd "$HOME${CLIENT_DIRECTORY}ta_lms_admin_fe"
}

afeo() {
    cd "$HOME${CLIENT_DIRECTORY}ta_lms_admin_fe"
    code .
}

lt() {
    cd "$HOME${CLIENT_DIRECTORY}opz-loadtest"
}

lto() {
    cd "$HOME${CLIENT_DIRECTORY}opz-loadtest"
    code .
}
