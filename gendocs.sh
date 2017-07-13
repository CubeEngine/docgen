#!/bin/bash

timeout=120
scriptDir="$(dirname "$(realpath "$0")")"
docsDir="${scriptDir}/data/config/cubeengine/modules/docs"

generate_docs() {
    pushd "${scriptDir}"
        # start the container
        echo "starts the containers..."
        docker-compose up -d

        mkdir -vp "${docsDir}"

        echo "wait for doc files..."
        inotifywait -t ${timeout} -e create -e moved_to "${docsDir}"

        # sleep another five seconds to ensure that the files were created completely
        sleep 5

        # print docker logs
        echo "Docker logs:"
        docker-compose logs

        # clean up environment
        echo "Clean up environment..."
        docker-compose rm -fsv

        if [ ! -f "${scriptDir}/modules" ]
        then
            echo "The docs couldn't be created."
            exit 1
        fi
    popd
}

echo "Generate Docs..."
generate_docs
