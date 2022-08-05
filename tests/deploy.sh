#!/usr/bin/env bash

DOCKER_BUILDX_ARCH="linux/amd64,linux/arm64" 

GIT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
BRANCH=${BRANCH:-$GIT_BRANCH}
MAILU_VERSION=${MAILU_VERSION:-$GIT_BRANCH}
PINNED_MAILU_VERSION=${PINNED_MAILU_VERSION:-$GIT_BRANCH}

echo "[debug] Rebuilding image with buildx"
echo "[troubleshooting] '/bin/sh: Invalid ELF image for this architecture' -> 'docker run --rm --privileged multiarch/qemu-user-static --reset -p yes'"

if [[ -z $(docker buildx ls | grep multiarch) ]]; then
    docker buildx create --name multiarch --platform $DOCKER_BUILDX_ARCH --use
fi

docker buildx inspect multiarch --bootstrap

readarray components < <(yq e -o=j -I=0 '.services[]' build.yml)

#Deploy for main releases
#Images are built with tag PINNED_MAILU_VERSION (x.y.z).
#We are tagging them as well with MAILU_VERSION (x.y)
#After that, both tags are pushed to the docker repository.
# if [ "$PINNED_MAILU_VERSION" != "" ] && [ "$BRANCH" != "master" ]
# then
#   images=$(docker-compose -f tests/build.yml config | awk -F ':' '/image:/{ print $2 }')
#   for image in $images
#   do
#     docker tag "${image}":"${PINNED_MAILU_VERSION}" "${image}":${MAILU_VERSION}
#   done
#   #Push PINNED_MAILU_VERSION images
#   docker-compose -f tests/build.yml push
#   #Push MAILU_VERSION images
#   PINNED_MAILU_VERSION=$MAILU_VERSION docker-compose -f tests/build.yml push
#   exit 0
# fi

#Deploy for master. For master we only publish images with tag master
#Images are built with tag PINNED_MAILU_VERSION (commit hash).
#We are tagging them as well with MAILU_VERSION (master)
#Then we publish the images with tag master
if [ "$PINNED_MAILU_VERSION" != "" ] && [ "$BRANCH" == "master" ]
then
  # images=$(docker-compose -f tests/build.yml config | awk -F ':' '/image:/{ print $2 }')
  # for image in $images
  # do
  #   docker tag "${image}":"${PINNED_MAILU_VERSION}" "${image}":${MAILU_VERSION}
  # done

  for component in "${components[@]}"; do
    echo "$component"
    DOCKER_IMAGE=$(echo "$component" | yq e '.image' - | cut -d ':' -f 1)
    PROJECT_DIR=$(echo "$component" | yq e '.build.context' -)
    ROOT_BUILD_CMD="docker buildx build --platform $DOCKER_BUILDX_ARCH"
    # BUILD_CMD="$ROOT_BUILD_CMD -t ${DOCKER_IMAGE}:${PINNED_MAILU_VERSION} ${PROJECT_DIR}"
    # BUILD_CMD="$BUILD_CMD --build-arg VERSION=$PINNED_MAILU_VERSION"
    # BUILD_CMD="$BUILD_CMD --push"
    # echo ${BUILD_CMD}
    # eval ${BUILD_CMD}
    #Push MAILU_VERSION images
    BUILD_CMD="PINNED_MAILU_VERSION=$MAILU_VERSION $ROOT_BUILD_CMD -t ${DOCKER_IMAGE}:${MAILU_VERSION} ${PROJECT_DIR}"
    BUILD_CMD="$BUILD_CMD --build-arg VERSION=$MAILU_VERSION"
    BUILD_CMD="$BUILD_CMD --push"
    echo ${BUILD_CMD}
    eval ${BUILD_CMD}
  done
  exit 0
fi
