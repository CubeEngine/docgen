#!/bin/bash

scriptDir="$(dirname "$(realpath "$0")")"
configDir="${scriptDir}/data/config"
genDocsDir="${configDir}/cubeengine/modules/docs"

docsDir="${scriptDir}/../docs"

# docker settings
NETWORK_NAME="forge_network"

MYSQL_CONTAINER_NAME="docgen_mysql"
MYSQL_ROOT_PASSWORD="<db-root-pw>"
MYSQL_DATABASE="minecraft"
MYSQL_USER="minecraft"
MYSQL_PASSWORD="<db-user-pw>"

MONGODB_CONTAINER_NAME="docgen_mongodb"
MONGODB_DBNAME="cubeengine"
MONGODB_USERNAME="minecraft"
MONGODB_PASSWORD="<mongo-db-user-pw>"

FORGE_CONTAINER_NAME="docgen_forge"
FORGE_JAVA_VM_ARGS="-Xmx1G"
FORGE_MODS_DIR="${scriptDir}/data/mods"

generate_docs() {
    pushd "${scriptDir}"
        echo "Creates a docker network..."
        docker network create -d bridge "${NETWORK_NAME}"

        echo "Creates and starts the MySQL container..."
        docker run --name "${MYSQL_CONTAINER_NAME}" -d --rm \
            --network="${NETWORK_NAME}" \
            --env MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD}" \
            --env MYSQL_DATABASE="${MYSQL_DATABASE}" \
            --env MYSQL_USER="${MYSQL_USER}" \
            --env MYSQL_PASSWORD="${MYSQL_PASSWORD}" \
            mysql:5.7

        echo "Creates and starts the MongoDB container..."
        docker run --name "${MONGODB_CONTAINER_NAME}" -d --rm \
            --network="${NETWORK_NAME}" \
            --env MONGODB_DBNAME="${MONGODB_DBNAME}" \
            --env MONGODB_USERNAME="${MONGODB_USERNAME}" \
            --env MONGODB_PASSWORD="${MONGODB_PASSWORD}" \
            frodenas/mongodb:3.0

        echo "Updates the cubeengine/forge image..."
        docker pull cubeengine/forge:latest

        echo "Creates and starts the Forge container in foreground..."
        docker run --name "${FORGE_CONTAINER_NAME}" --rm \
            --network="${NETWORK_NAME}" \
            --env DB_HOST="${MYSQL_CONTAINER_NAME}" \
            --env DB_NAME="${MYSQL_DATABASE}" \
            --env DB_USER="${MYSQL_USER}" \
            --env DB_PASSWORD="${MYSQL_PASSWORD}" \
            --env MONGO_DB_HOST="${MONGODB_CONTAINER_NAME}" \
            --env MONGO_DB_NAME="${MONGODB_DBNAME}" \
            --env MONGO_DB_USER="${MONGODB_USERNAME}" \
            --env MONGO_DB_PASSWORD="${MONGODB_PASSWORD}" \
            --env JAVA_VM_ARGS="${FORGE_JAVA_VM_ARGS}" \
            --env CUBEENGINE_DOCS_SHUTDOWN="true" \
            --volume="${configDir}:/opt/minecraft/config" \
            --volume="${FORGE_MODS_DIR}:/opt/minecraft/mods" \
            cubeengine/forge:latest

        echo "Stops background docker containers..."
        docker stop "${MONGODB_CONTAINER_NAME}" "${MYSQL_CONTAINER_NAME}"

        echo "Removes the docker network..."
        docker network rm "${NETWORK_NAME}"

        if [ ! -f "${genDocsDir}/README.md" ]
        then
            echo "The docs couldn't be created!"
            exit 1
        fi
    popd
}

push_changes() {
    rm -vr "${docsDir}/*.md"
    mv -v "${genDocsDir}/*" "${docsDir}"

    pushd "${docsDir}"
        git add .
        git status
        git commit -m "docs were updated automatically"
        git status
        #git push origin master
    popd
}

echo "Generate Docs..."
generate_docs

echo "Push doc changes to git repo..."
push_changes
