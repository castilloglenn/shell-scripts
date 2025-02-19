goto() {
    project=$1
    cd "$HOME${CLIENT_DIRECTORY}$project"
}

tw() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-web"
    code .
}

tm() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-mobile"
    code .
}

tb() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-backend"
    code .
}

ts() {
    cd "$HOME${CLIENT_DIRECTORY}takokase-scripts"
    code .
}

