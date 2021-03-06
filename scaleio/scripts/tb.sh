#!/bin/bash
while [[ $# > 1 ]]
do
  key="$1"

  case $key in
    -o|--os)
    OS="$2"
    shift
    ;;
    -zo|--zipos)
    ZIP_OS="$2"
    shift
    ;;
    -d|--device)
    DEVICE="$2"
    shift
    ;;
    -i|--installpath)
    INSTALLPATH="$2"
    shift
    ;;
    -v|--version)
    VERSION="$2"
    shift
    ;;
    -n|--packagename)
    PACKAGENAME="$2"
    shift
    ;;
    -f|--firstmdmip)
    FIRSTMDMIP="$2"
    shift
    ;;
    -s|--secondmdmip)
    SECONDMDMIP="$2"
    shift
    ;;
    -tb|--tbip)
    TBIP="$2"
    shift
    ;;
    -c|--clusterinstall)
    CLUSTERINSTALL="$2"
    shift
    ;;
    -dk|--dockerinstall)
    DOCKERINSTALL="$2"
    shift
    ;;
    -r|--rexrayinstall)
    REXRAYINSTALL="$2"
    shift
    ;;
    -ds|--swarminstall)
    SWARMINSTALL="$2"
    shift
    ;;
    -ms|--mesosinstall)
    MESOSINSTALL="$2"
    shift
    ;;
    -vf|--verifyfiles)
    VERIFYFILES="$2"
    shift
    ;;
    *)
    # unknown option
    ;;
  esac
  shift
done
echo DEVICE  = "${DEVICE}"
echo INSTALL PATH     = "${INSTALLPATH}"
echo VERSION    = "${VERSION}"
echo OS    = "${OS}"
echo PACKAGENAME    = "${PACKAGENAME}"
echo FIRSTMDMIP    = "${FIRSTMDMIP}"
echo SECONDMDMIP    = "${SECONDMDMIP}"
echo TBIP    = "${TBIP}"
echo CLUSTERINSTALL = "${CLUSTERINSTALL}"
echo DOCKERINSTALL     = "${DOCKERINSTALL}"
echo REXRAYINSTALL     = "${REXRAYINSTALL}"
echo SWARMINSTALL     = "${SWARMINSTALL}"
echo MESOSINSTALL     = "${MESOSINSTALL}"
echo VERIFYFILES     = "${VERIFYFILES}"
echo ZIP_OS    = "${ZIP_OS}"

VERSION_MAJOR=`echo "${VERSION}" | awk -F \. {'print $1'}`
VERSION_MINOR=`echo "${VERSION}" | awk -F \. {'print $2'}`
VERSION_MINOR_FIRST=`echo $VERSION_MINOR | awk -F "-" {'print $1'}`
VERSION_MAJOR_MINOR=`echo $VERSION_MAJOR"."$VERSION_MINOR_FIRST`
VERSION_MINOR_SUB=`echo $VERSION_MINOR | awk -F "-" {'print $2'}`
VERSION_MINOR_SUB_FIRST=`echo $VERSION_MINOR_SUB | head -c 1`
VERSION_SUMMARY=`echo $VERSION_MAJOR"."$VERSION_MINOR_FIRST"."$VERSION_MINOR_SUB_FIRST`

echo VERSION_MAJOR = $VERSION_MAJOR
echo VERSION_MAJOR_MINOR = $VERSION_MAJOR_MINOR
echo VERSION_SUMMARY = $VERSION_SUMMARY

echo "Checking Interface State: enp0s8"
INTERFACE_STATE=$(cat /sys/class/net/enp0s8/operstate)
if [ "${INTERFACE_STATE}" == "down" ]; then
  echo "Bringing Up Interface: enp0s8"
  ifup enp0s8
fi

truncate -s 100GB ${DEVICE}
yum install unzip numactl libaio wget bc -y

if [ "${VERIFYFILES}" == "true" ]; then

  URL="http://downloads.emc.com/emc-com/usa/ScaleIO/ScaleIO_Linux_v"$VERSION_MAJOR_MINOR".zip"

  echo "Verifying that the SIO package is available from downloads.emc.com"
  echo "If you don't want this to happen set VERIFYFILES to false in the Vagrantfile"
  if curl --output /dev/null --silent --head --fail "$URL"; then
    echo "URL exists: $URL. Continuing."
  else
    echo "URL does not exist: $URL. Please try to run \"vagrant up\" again."
    exit
  fi

  FILESIZE=`curl -sI $URL | grep Content-Length | awk '{print $2}' | tr -d $'\r' | bc -l`

  if [ "$FILESIZE" -lt 1 ]; then
    echo "The file on downloads.emc.com doesn't look correct. Please try to run \"vagrant up\" again."
    exit
  else
    echo "The file on downloads.emc.com is larger than 0 bytes. Continuing."
  fi

fi

cd /vagrant

if [ -f "ScaleIO_Linux_v"$VERSION_MAJOR_MINOR".zip" ]; then
  STOREDFILE=`wc -c <"ScaleIO_Linux_v"$VERSION_MAJOR_MINOR".zip" | awk '{print $1}'`
  echo "Stored file size is" $STOREDFILE
  echo "File on downloads.emc.com is" $FILESIZE
  if [ "$FILESIZE" -gt "$STOREDFILE" ]; then
    echo "The file size of the stored ScaleIO zip is incorrect. Will remove and download the new one."
    rm "ScaleIO_Linux_v"$VERSION_MAJOR_MINOR".zip"
  else
    echo "The file sizes of the stored ScaleIO zip and the zip file on downloads.emc.com are the same. Continuing."
  fi
fi

if [ ! -f "ScaleIO_Linux_v"$VERSION_MAJOR_MINOR".zip" ];
then
  echo "Downloading SIO package from downloads.emc.com"
  wget -nv http://downloads.emc.com/emc-com/usa/ScaleIO/ScaleIO_Linux_v"$VERSION_MAJOR_MINOR".zip -O ScaleIO_Linux_v"$VERSION_MAJOR_MINOR".zip
fi

echo "Uncompressing SIO package"
unzip -n "ScaleIO_Linux_v"$VERSION_MAJOR_MINOR".zip" -d /vagrant/scaleio/

DIR=`unzip -l "ScaleIO_Linux_v"$VERSION_MAJOR_MINOR".zip" | awk '{print $4}' | grep $ZIP_OS | awk -F'/' '{print $1 "/" $2 "/" $3}' | head -1`

echo "Entering directory /vagrant/scaleio/$DIR"
cd /vagrant/scaleio/$DIR

MDMRPM=`ls -1 | grep "\-mdm\-"`
SDSRPM=`ls -1 | grep "\-sds\-"`
SDCRPM=`ls -1 | grep "\-sdc\-"`

if [ "${CLUSTERINSTALL}" == "true" ]; then
  echo "Installing MDM $MDMRPM"
  MDM_ROLE_IS_MANAGER=0 rpm -Uv $MDMRPM 2>/dev/null
  echo "Installing SDS $SDSRPM"
  rpm -Uv $SDSRPM 2>/dev/null
  echo "Installing SDC $SDCRPM"
  MDM_IP=${FIRSTMDMIP},${SECONDMDMIP} rpm -Uv $SDCRPM 2>/dev/null
fi

if [ "${DOCKERINSTALL}" == "true" ]; then
  echo "Installing Docker"
  curl -sSL https://get.docker.com/ | sh
  echo "Setting Docker Permissions"
  usermod -aG docker vagrant
  echo "Setting Docker service to Start on boot"
  chkconfig docker on
  service docker restart
fi

if [ "${REXRAYINSTALL}" == "true" ]; then
  echo "Installing REX-Ray"
  /vagrant/scripts/rexray.sh
  service docker restart
fi

if [ "${SWARMINSTALL}" == "true" ]; then
  echo "Configuring Host as Docker Swarm Manager - will be demoted to Worker later by MDM1"
  docker swarm init --listen-addr ${TBIP} --advertise-addr ${TBIP}
  docker swarm join-token -q worker > /vagrant/swarm_worker_token
  docker swarm join-token -q manager > /vagrant/swarm_manager_token
fi

if [ "${MESOSINSTALL}" == "true" ]; then
  /vagrant/scripts/mesos-node.sh
fi

if [[ -n $1 ]]; then
  echo "Last line of file specified as non-opt/last argument:"
  tail -1 $1
fi
