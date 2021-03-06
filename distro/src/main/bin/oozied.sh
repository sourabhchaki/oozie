#!/bin/bash
#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

if [ $# -le 0 ]; then
  echo "Usage: oozied.sh (start|stop|run|status) [<catalina-args...>]"
  exit 1
fi

actionCmd=$1
shift

# resolve links - $0 may be a softlink
PRG="${0}"

while [ -h "${PRG}" ]; do
  ls=`ls -ld "${PRG}"`
  link=`expr "$ls" : '.*-> \(.*\)$'`
  if expr "$link" : '/.*' > /dev/null; then
    PRG="$link"
  else
    PRG=`dirname "${PRG}"`/"$link"
  fi
done

BASEDIR=`dirname ${PRG}`
BASEDIR=`cd ${BASEDIR}/..;pwd`
MAPR_CONF_DIR=/opt/mapr/conf
ENV_FILE=env.sh

source ${BASEDIR}/bin/oozie-sys.sh

# MapR change. Source env.sh if it exists 
if [[ -n $(find ${MAPR_CONF_DIR} -name "${ENV_FILE}" -print) ]]; then
    source ${MAPR_CONF_DIR}/env.sh 
fi

CATALINA=${OOZIE_CATALINA_HOME:-${BASEDIR}/oozie-server}/bin/catalina.sh

setup_catalina_opts() {
  # The Java System properties 'oozie.http.port' and 'oozie.https.port' are not
  # used by Oozie, they are used in Tomcat's server.xml configuration file
  #
  echo "Using   CATALINA_OPTS:       ${CATALINA_OPTS}"

  catalina_opts="-Doozie.home.dir=${OOZIE_HOME}";
  catalina_opts="${catalina_opts} -Doozie.config.dir=${OOZIE_CONFIG}";
  catalina_opts="${catalina_opts} -Doozie.log.dir=${OOZIE_LOG}";
  catalina_opts="${catalina_opts} -Doozie.data.dir=${OOZIE_DATA}";

  catalina_opts="${catalina_opts} -Doozie.config.file=${OOZIE_CONFIG_FILE}";

  catalina_opts="${catalina_opts} -Doozie.log4j.file=${OOZIE_LOG4J_FILE}";
  catalina_opts="${catalina_opts} -Doozie.log4j.reload=${OOZIE_LOG4J_RELOAD}";

  catalina_opts="${catalina_opts} -Doozie.http.hostname=${OOZIE_HTTP_HOSTNAME}";
  catalina_opts="${catalina_opts} -Doozie.admin.port=${OOZIE_ADMIN_PORT}";
  catalina_opts="${catalina_opts} -Doozie.http.port=${OOZIE_HTTP_PORT}";
  catalina_opts="${catalina_opts} -Doozie.https.port=${OOZIE_HTTPS_PORT}";
  catalina_opts="${catalina_opts} -Doozie.base.url=${OOZIE_BASE_URL}";
  catalina_opts="${catalina_opts} -Doozie.https.keystore.file=${OOZIE_HTTPS_KEYSTORE_FILE}";
  catalina_opts="${catalina_opts} -Doozie.https.keystore.pass=${OOZIE_HTTPS_KEYSTORE_PASS}";
  catalina_opts="${catalina_opts} -Dmapr.library.flatclass=true"; 
  catalina_opts="${catalina_opts} ${MAPR_AUTH_CLIENT_OPTS}"; 

  # add required native libraries such as compression codecs
  # MAPR CHANGE: Add mapr lib to the java library path
  catalina_opts="${catalina_opts} -Djava.library.path=${JAVA_LIBRARY_PATH}:/opt/mapr/lib";

  # MAPR Change: Set parameters in oozie-site.xml based on if MapR security is enabled or not
  if [ "$MAPR_SECURITY_STATUS" = "true" ]; then
      catalina_opts="${catalina_opts} -Dmapr_sec_type=org.apache.hadoop.security.authentication.server.MultiMechsAuthenticationHandler"
      catalina_opts="${catalina_opts} -Dmapr_sec_enabled=true"
   else
      catalina_opts="${catalina_opts} -Dmapr_sec_type=simple"
      catalina_opts="${catalina_opts} -Dmapr_sec_enabled=false"
  fi

  echo "Adding to CATALINA_OPTS:     ${catalina_opts}"

  export CATALINA_OPTS="${CATALINA_OPTS} ${catalina_opts}"
}

setup_oozie() {
  if [ ! -e "${CATALINA_BASE}/webapps/oozie.war" ]; then
    echo "WARN: Oozie WAR has not been set up at ''${CATALINA_BASE}/webapps'', doing default set up"
    ${BASEDIR}/bin/oozie-setup.sh
    if [ "$?" != "0" ]; then
      exit -1
    fi
  fi
  echo
}

case $actionCmd in
  (start|run)
    setup_catalina_opts
    setup_oozie 
    ;;
  (stop)
    setup_catalina_opts

    # A bug in catalina.sh script does not use CATALINA_OPTS for stopping the server
    export JAVA_OPTS=${CATALINA_OPTS}
    ;;
  (status)
    if [ ! -z "$CATALINA_PID" ]; then
     if [ -f "$CATALINA_PID" ]; then
       if [ -s "$CATALINA_PID" ]; then
         if [ -r "$CATALINA_PID" ]; then
           PID=`cat "$CATALINA_PID"`
           ps -p $PID >/dev/null 2>&1
           if [ $? -eq 0 ] ; then
             echo "Tomcat is running with PID $PID."
             exit 0
           fi
          fi
       fi
     fi
    fi
    echo "Most likely Tomcat is not running"
    exit 1
    ;;
esac

exec $CATALINA $actionCmd "$@"
