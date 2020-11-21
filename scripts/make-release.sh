#!/bin/bash

set -e


VERSION=$1

if [ -z "$VERSION" ]
then
	echo "Need a version string."
	exit 1
fi

# source root directory of paperless
PAPERLESS_ROOT=$(git rev-parse --show-toplevel)

# output directory
PAPERLESS_DIST="$PAPERLESS_ROOT/dist"
PAPERLESS_DIST_APP="$PAPERLESS_DIST/paperless-ng"

if [ -d "$PAPERLESS_DIST" ]
then
	echo "Removing $PAPERLESS_DIST"
	rm "$PAPERLESS_DIST" -r
fi

mkdir "$PAPERLESS_DIST"
mkdir "$PAPERLESS_DIST_APP"
mkdir "$PAPERLESS_DIST_APP/docker"

# setup dependencies.

cd "$PAPERLESS_ROOT"

pipenv clean
pipenv install --dev
pipenv lock --keep-outdated -r > "$PAPERLESS_DIST_APP/requirements.txt"

# test if the application works.

cd "$PAPERLESS_ROOT/src"
pipenv run pytest --cov
pipenv run pycodestyle

# make the documentation.

cd "$PAPERLESS_ROOT/docs"
make clean html

# copy stuff into place

# the application itself

cp "$PAPERLESS_ROOT/.env" \
  "$PAPERLESS_ROOT/.dockerignore" \
	"$PAPERLESS_ROOT/CONTRIBUTING.md" \
	"$PAPERLESS_ROOT/LICENSE" \
	"$PAPERLESS_ROOT/Pipfile" \
	"$PAPERLESS_ROOT/Pipfile.lock" \
	"$PAPERLESS_ROOT/README.md" "$PAPERLESS_DIST_APP"

cp "$PAPERLESS_ROOT/paperless.conf.example" "$PAPERLESS_DIST_APP/paperless.conf"

# copy python source, templates and static files.
cd "$PAPERLESS_ROOT"
find src -wholename '*/templates/*' -o -wholename '*/static/*' -o -name '*.py' | cpio -pdm "$PAPERLESS_DIST_APP"

# build the front end.

cd "$PAPERLESS_ROOT/src-ui"
ng build --prod --output-hashing none --sourceMap=false --output-path "$PAPERLESS_DIST_APP/src/documents/static/frontend"

# documentation
cp "$PAPERLESS_ROOT/docs/_build/html/" "$PAPERLESS_DIST_APP/docs" -r

# docker files for building the image yourself
cp "$PAPERLESS_ROOT/docker/local/"* "$PAPERLESS_DIST_APP"
cp "$PAPERLESS_ROOT/docker/docker-compose.env" "$PAPERLESS_DIST_APP"

# docker files for pulling from docker hub
cp "$PAPERLESS_ROOT/docker/hub/"* "$PAPERLESS_DIST"
cp "$PAPERLESS_ROOT/.env" "$PAPERLESS_DIST"
cp "$PAPERLESS_ROOT/docker/docker-compose.env" "$PAPERLESS_DIST"

# auxiliary files required for the docker image
cp "$PAPERLESS_ROOT/docker/docker-entrypoint.sh" "$PAPERLESS_DIST_APP/docker/"
cp "$PAPERLESS_ROOT/docker/gunicorn.conf.py" "$PAPERLESS_DIST_APP/docker/"
cp "$PAPERLESS_ROOT/docker/imagemagick-policy.xml" "$PAPERLESS_DIST_APP/docker/"
cp "$PAPERLESS_ROOT/docker/supervisord.conf" "$PAPERLESS_DIST_APP/docker/"

# try to make the docker build.

cd "$PAPERLESS_DIST_APP"

docker build . -t "jonaswinkler/paperless-ng:$VERSION"

# works. package the app!

cd "$PAPERLESS_DIST"

tar -cJf "paperless-ng-$VERSION.tar.xz" paperless-ng/