#!/bin/sh

VERSION=`python -c "import avoviirscollector; print(avoviirscollector.__version__)"`
echo Tagging release $VERSION
git add avoviirscollector/__init__.py
git commit -m 'version bump'
git push \
&& git tag $VERSION \
&& git push --tags
