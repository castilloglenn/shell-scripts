cs_activate_penpot() {
    cd ${PENPOT_DIRECTORY}
    make start
}

cs_stop_penpot() {
    cd ${PENPOT_DIRECTORY}
    make stop
}
