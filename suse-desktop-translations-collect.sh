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
	osc getbinaries $PROJECT $PACKAGE $REPOSITORY $ARCH translate-suse-desktop.tar.gz
	tar xf binaries/translate-suse-desktop.tar.gz
	rm -rf binaries
done
msgcat *.pot -o ../po/suse-desktop-translations.pot
#BEGIN deprecated import
mkdir ../oldimport.tmp
for POT in *.pot ; do
	sed "/^msgstr /,\${/^msgid/imsgctxt \"Name(${POT%.pot}.desktop)\"
}" <$POT >../oldimport.tmp/${POT##*/}.dftname
	sed "/^msgstr /,\${/^msgid/imsgctxt \"GenericName(${POT%.pot}.desktop)\"
}" <$POT >../oldimport.tmp/${POT##*/}.dftgenericname
	sed "/^msgstr /,\${/^msgid/imsgctxt \"Comment(${POT%.pot}.desktop)\"
}" <$POT >../oldimport.tmp/${POT##*/}.dftcomment
	sed "/^msgstr /,\${/^msgid/imsgctxt \"Keywords(${POT%.pot}.desktop)\"
}" <$POT >../oldimport.tmp/${POT##*/}.dftkeywords
done
#END deprecated import
cd ..
rm -r collect.tmp

cd po
for PO in *.po ; do
	msgmerge $PO suse-desktop-translations.pot -o $PO.new
	mv $PO.new $PO
done
cd -

#BEGIN deprecated import
cd oldimport.tmp
msgcat *.pot.dft* -o suse-desktop-translations-dft.pot
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
mkdir clean
for PO in *.po ; do
	msgmerge --force-po $PO suse-desktop-translations-dft.pot -o clean/$PO.obsolette
	msgattrib --force-po --no-obsolete clean/$PO.obsolette -o clean/$PO.no-obsolete
	# Process translated strings
	msgattrib --force-po clean/$PO.no-obsolete --no-fuzzy -o clean/$PO.no-fuzzy
	msgmerge --force-po clean/$PO.no-fuzzy ../po/suse-desktop-translations.pot -o clean/$PO.no-fuzzy-sdt
	msgattrib --force-po --clear-fuzzy --translated --no-obsolete clean/$PO.no-fuzzy-sdt -o clean/$PO.no-fuzzy-sdt-translated
	# Process fuzzy strings with fuzzy patching
	msgattrib --force-po clean/$PO.no-obsolete --only-fuzzy -o clean/$PO.fuzzy
	msgmerge --force-po clean/$PO.fuzzy ../po/suse-desktop-translations.pot -o clean/$PO.fuzzy-sdt
	msgattrib --force-po --no-obsolete --translated clean/$PO.fuzzy-sdt -o clean/$PO.fuzzy-sdt-no-obsolete
	# Merge translated and fuzzy strings back
	msgcat --use-first clean/$PO.no-fuzzy-sdt-translated clean/$PO.fuzzy-sdt-no-obsolete -o clean/$PO
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
rm -r oldimport.tmp
#END deprecated import

cd po
for PO in *.po ; do
	msgmerge $PO suse-desktop-translations.pot -o $PO.new
	mv $PO.new $PO
done
