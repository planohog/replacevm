#!/bin/bash
#############################################################
function usage() {
  echo "Usage: $0 -m vm_image_files_directory [-a] [-s] [-h]" >&2
  echo "   -m    Path to the folder containing the new/replacement VM image files (required)" >&2
  echo "   -a    Set VM to auto-start at system boot" >&2  
  echo "   -s    Start VM after install" >&2  
  echo "   -h    This message" >&2  
#  exit 1
}

VMSOURCEDIR=""
SETAUTOSTART="N"
STARTVM="N"

while getopts "m:ash" ARG; do
  case ${ARG} in
    m)
      VMSOURCEDIR="${OPTARG}"
      ;;
    a)
      SETAUTOSTART="Y"
      ;;
    s)
      STARTVM="Y"
      ;;
    h)
      usage
      ;;
  esac
done
                                                                    


if [[ `id -u` -ne 0 ]] ; then
  echo "Error: Must be run as root." >&2
  exit 1
fi

# Validate the command line arg is a directory 
if [[ ! -d "${VMSOURCEDIR}" ]] ; then
  echo "Error:  '${VMSOURCEDIR}' does not exist"
  usage
fi

VM=`basename ${VMSOURCEDIR}`
VMPATH="`dirname ${VMSOURCEDIR}`/${VM}"
IMGPATH="/var/lib/libvirt/images"
DEFPATH="/etc/libvirt/qemu/"
VMDEF="${DEFPATH}/${VM}.xml"


echo "VMSOURCEDIRE=${VMSOURCEDIR}"
echo "SETAUTOSTART=${SETAUTOSTART}"
echo "STARTVM=${STARTVM}"
echo "VM=${VM}"
echo "VMPATH=${VMPATH}"
echo "VMDEF=${VMDEF}"

if [[ -a ${VMDEF} ]] ; then

 if [[ ! -z `virsh list --name | grep ${VM}` ]] ; then 
    echo "VM is running, stopping...."
    virsh destroy ${VM} || true  2>/dev/null
 fi

echo "Checking for snapshots to delete..."
virsh snapshot-list "${VM}"
virsh snapshot-list "${VM}" --name | grep -v "^$" | while read SS ; do virsh snapshot-delete "${VM}" "${SS}" ; done
     
 if [[ ! -z `virsh list --all --name | grep ${VM}` ]] ; then  
  echo "Removing VM definition..."
  virsh undefine ${VM}
 fi
fi  

 if ls ${IMGPATH}/${VM}*BASE ; then
   chattr -i ${IMGPATH}/${VM}*BASE 
   chmod 660 ${IMGPATH}/${VM}*
 fi
echo "Unpacking new VM image files..."
cat ${VMPATH}/${VM}*.tar.gz* | tar -C / -xzv --overwrite

virsh define ${DEFPATH}/${VM}.xml

virsh domblklist "${VM}" \
   | tail -n +3 \
   | awk '{print $2}' \
   | grep -v "^$" \
   | grep -v "^-$" \
   | while read DSK
  do
     chown libvirt-qemu:libvirt-qemu ${DSK}*
     if ls ${DSK}*BASE  ; then
       chmod 660 ${DSK}*
       chmod 440 ${DSK}*BASE
       chattr +i ${DSK}*BASE
     fi
  done

echo "Creating baseli1ne snapshot..."

SSDATE=${SSDATE:-`date '+%Y-%m-%d'`}
virsh snapshot-create-as "${VM}" baseload "Post-installation ${SSDATE} "

virsh list --all

echo "$0: Done."
