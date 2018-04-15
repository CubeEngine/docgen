#!/bin/bash

scriptDir="$(dirname "$(realpath "$0")")"
configDir="${scriptDir}/data/config"
genDocsDir="${configDir}/cubeengine/modules/docs"

docsDir="${scriptDir}/../docs"

GIT_USER_NAME="CubeEngine Bot"
GIT_USER_EMAIL="management@cubeisland.de"

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
FORGE_JAVA_VM_ARGS="-Xmx512M"
FORGE_MODS_DIR="${scriptDir}/data/mods"
FORGE_WORLD_DIR="${scriptDir}/data/world"

generate_docs() {
    pushd "${scriptDir}"
        echo "Creates volume directories (so that they have the correct access rights)..."
        mkdir -vp "${configDir}"

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
        docker pull cubeengine/forge:1.12.2

        echo "Deletes dangling cubeengine/forge images..."
        docker rmi $(docker images --filter "reference=cubeengine/forge" --filter "dangling=true" -q)

        echo "Creates and starts the Forge container in foreground..."
        docker run --name "${FORGE_CONTAINER_NAME}" --rm \
            --user="$(id -u):$(id -g)" \
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
            --volume="${configDir}:/home/minecraft/server/config" \
            --volume="${FORGE_MODS_DIR}:/home/minecraft/server/mods" \
            --volume="${FORGE_WORLD_DIR}:/home/minecraft/server/world" \
            cubeengine/forge:1.12.2

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
    echo "Removes all .md files from the docs repo..."
    rm -v "${docsDir}"/*.md
    rm -v "${docsDir}"/modules/*.md

    echo "Moves all generated doc files to the docs repo directory..."
    cp -Rv "${genDocsDir}"/* "${docsDir}"

    pushd "${docsDir}"
        git add .
        git status

        git config user.name "${GIT_USER_NAME}"
        git config user.email "${GIT_USER_EMAIL}"
        git commit -m "docs were updated automatically"

        git push origin master
    popd
}

echo "Generate Docs..."
generate_docs

echo "Push doc changes to git repo..."
push_changes
