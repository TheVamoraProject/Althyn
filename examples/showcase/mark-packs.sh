#!/bin/bash
# Mark icon packs as Vamora packs (see pack_is_vamora): full-bleed icons, no tile.
for t in Tela-circle Tela-circle-dark Tela-circle-light; do
  f=/usr/share/icons/$t/index.theme
  grep -q '^VamoraPackage=' $f || sed -i '0,/^\[Icon Theme\]/s//[Icon Theme]\nVamoraPackage=true/' $f
done
grep -n -m2 "VamoraPackage\|Icon Theme" /usr/share/icons/Tela-circle/index.theme
