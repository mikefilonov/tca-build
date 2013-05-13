#!/bin/sh

PROJECT_DIR=""
BOOT_DIR="/usr/local/share/tca-build/boot"

[ -d "$BOOT_DIR" ] || { echo "No 'boot' directory at $BOOT_DIR"; exit 1;}


usage(){
    echo "Usage: tce-build [-r REPOSITORY] [-o output_iso] [-n project_name] [-t temporary_dir] project"
}

GETOPT=`getopt -o r:t:n:o: -n 'tca-build' -- "$@"`
[ $? != 0 ] && exit 1

eval set -- "$GETOPT"

while :
do
	case $1 in
	-r)
		REPOSITORY_DIR=$2
		shift 2
		;;
	-n)
		NAME=$2
		shift 2
		;;
	-t)
		BUILD_DIR=$2
		shift 2
		;;
	-o)
		ISO_FILE=$2
		shift 2
		;;
	--)
		shift
		PROJECT_DIR=$1
		[ -z "$PROJECT_DIR" ] && { usage; exit 2;}
		[ ! -d "$PROJECT_DIR" ] && { echo "'$PROJECT_DIR' is not a directory" ; exit 3;}
		break
		;;
	*)
		echo 'Invalid argument' $1
		exit 1
		;;
	esac
done


[ -z "$REPOSITORY_DIR" ] && REPOSITORY_DIR="/usr/local/share/tca-build/repository"
[ -z "$NAME" ] && NAME=$(basename $PROJECT_DIR)
[ -z "$BUILD_DIR" ] && BUILD_DIR="./.$NAME.build"
[ -z "$ISO_FILE" ] && ISO_FILE="$NAME.iso"

# echo -r "$REPOSITORY_DIR" -n "$NAME" -t "$BUILD_DIR" -o "$ISO_FILE"

mkdir -p "$BUILD_DIR"
cp -aL "$BOOT_DIR" "$BUILD_DIR"

mkdir -p ${BUILD_DIR}/cde
cp -aL "$PROJECT_DIR"/* ${BUILD_DIR}/cde

[ ! -e /etc/sysconfig/tcedir.bck ] && mv /etc/sysconfig/tcedir /etc/sysconfig/tcedir.bck
[ -e /etc/sysconfig/tcedir ] && rm /etc/sysconfig/tcedir
ln -s $(readlink -nf "$BUILD_DIR/cde") /etc/sysconfig/tcedir

while read packet
do
	if [ -f "$REPOSITORY_DIR"/$packet ]
	then
		[ ! -d "$BUILD_DIR"/cde/optional/ ] && mkdir -p "$BUILD_DIR"/cde/optional/
		cp -a "$REPOSITORY_DIR"/"$packet" "$BUILD_DIR"/cde/optional/
	else
		[ ! -e "$BUILD_DIR"/cde/optional/"$packet" ] && tce-load -w "$packet"
	fi
done < "$PROJECT_DIR"/onboot.lst

rm /etc/sysconfig/tcedir
mv /etc/sysconfig/tcedir.bck /etc/sysconfig/tcedir 

mkisofs -l -J -V "$NAME" -no-emul-boot -boot-load-size 4 -boot-info-table -b boot/isolinux/isolinux.bin -c boot/isolinux/boot.cat -o "${ISO_FILE}" "${BUILD_DIR}"

