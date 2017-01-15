#!/bin/sh -e

version=$(cat VERSION)
addon_file="$(pwd)/hm-lgtv-${version}.tar.gz"
tmp_dir=$(mktemp -d)

cp -a update_script "${tmp_dir}"


(cd ${tmp_dir}; tar --owner=root --group=root -czvf "${addon_file}" .)
rm -rf "${tmp_dir}"

