#!/bin/bash
PROJECT=openSUSE:Factory
REPOSITORY=standard
ARCH=x86_64
DESKTOP_FILE_TRANSLATIONS_BRANCH=master

set -o errexit
shopt -s nullglob
set -x

mkdir collect.tmp

if ! test -d desktop-file-translations-$DESKTOP_FILE_TRANSLATIONS_BRANCH ; then
	git clone -b $DESKTOP_FILE_TRANSLATIONS_BRANCH https://github.com/openSUSE/desktop-file-translations.git desktop-file-translations-$DESKTOP_FILE_TRANSLATIONS_BRANCH
else
	cd desktop-file-translations-$DESKTOP_FILE_TRANSLATIONS_BRANCH
	git pull
	cd -
fi

cd collect.tmp

LIST=$(osc whatdependson $PROJECT translate-suse-desktop $REPOSITORY $ARCH | sed /:/d)
for PACKAGE in $LIST ; do
	osc getbinaries $PROJECT $PACKAGE $REPOSITORY $ARCH translate-suse-desktop.gz
	tar xf binaries/translate-suse-desktop.gz
	rm -rf binaries
done
msgcat *.pot -o ../po/suse-desktop-translations.pot
cd ..
rm -r collect.tmp

cd po
for PO in *.po ; do
	msgmerge $PO suse-desktop-translations.pot -o $PO.new
	mv $PO.new $PO
done
cd -

#BEGIN deprecated import
# WARNING: This imported does not work properly for strings that never
# existed in update-desktop-files. Fuzzy match can propose a completely
# different string.

mkdir oldimport.tmp
cd oldimport.tmp
for PO in ../desktop-file-translations-$DESKTOP_FILE_TRANSLATIONS_BRANCH/*/update-desktop-files{-apps,}.po ; do
	LNG=${PO%/*}
	LNG=${LNG##*/}
	if ! test -f $LNG.po ; then
		ln $PO $LNG.po
	else
		# Ignore errors, especially in plural forms.
		msgcat --use-first --force-po $LNG.po $PO -o $LNG.po.msgcat || :
		mv $LNG.po.msgcat $LNG.po
	fi
done
mkdir all
mkdir all/fuzzy
mkdir all/no-fuzzy
mkdir clean
mkdir clean/fuzzy
mkdir clean/no-fuzzy
# The new po files don't use msgctxt, so all translations are made fuzzy by
# msgmerge. Process fuzzy and non-fuzzy strings separately.
for PO in *.po ; do
	msgattrib --force-po --fuzzy $PO -o all/fuzzy/$PO
	msgattrib --force-po --no-fuzzy $PO -o all/no-fuzzy/$PO
done
cd all
for PO in fuzzy/*.po ; do
	msgmerge --force-po $PO ../../po/suse-desktop-translations.pot -o ../clean/$PO.pre1
	msgattrib --force-po --translated --no-obsolete ../clean/$PO.pre1 -o ../clean/$PO.pre2
	msgattrib --force-po --set-fuzzy ../clean/$PO.pre2 -o ../clean/$PO
done
for PO in no-fuzzy/*.po ; do
	msgmerge --force-po $PO ../../po/suse-desktop-translations.pot -o ../clean/$PO.pre1
	msgattrib --force-po --translated --no-obsolete ../clean/$PO.pre1 -o ../clean/$PO.pre2
	msgattrib --force-po --clear-fuzzy ../clean/$PO.pre2 -o ../clean/$PO
done
cd ..
for PO in *.po ; do
	msgcat --use-first clean/no-fuzzy/$PO clean/fuzzy/$PO -o clean/$PO
done
cd clean
for PO in *.po ; do
	if test -f ../../po/$PO ; then
		msgcat --use-first ../../po/$PO $PO -o ../../po/$PO.new
		mv ../../po/$PO.new ../../po/$PO
	else
		ln $PO ../../po/$PO
	fi
done
cd ../..
#rm -r oldimport.tmp
#END deprecated import
