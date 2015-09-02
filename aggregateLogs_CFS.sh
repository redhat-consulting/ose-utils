#!/bin/bash
#
#This script is simply collection of the commands located in the Openshift 3.0 Administration Guide for
# aggregating logs using the "Centralized File System" approach
#
#
#USAGE: ./aggregateLogs_CFS.sh 
#
#


function error_check {

    if [[ $1 -ne 0 ]];then
       echo "Error during $2 exit_code: ${status}"
       exit status
    fi
    echo "Completed $2"


}


#Set RPM name variable for less typing
export RPM=td-agent-2.2.0-0.x86_64.rpm

#Download rpm
curl http://packages.treasuredata.com/2/redhat/7/x86_64/$RPM -o /tmp/$RPM
status=$?
error_check $status "RPM Download"


#Install RPM
yum -y localinstall /tmp/$RPM
status=$?
error_check $status "Yum install"


#Install fluent-kubernetes gem
/opt/td-agent/embedded/bin/gem install fluent-plugin-kubernetes
status=$?
error_check $status "gem install fluent-plugin-kubernetes"


#Making config dir
mkdir -p /etc/td-agent/config.d
status=$?
error_check $status "create config dir"

#change Ownership
chown td-agent:td-agent /etc/td-agent/config.d
status=$?
error_check $status "change ownership of config dir"


#populating sysconfig file
echo "DAEMON_ARGS=
TD_AGENT_ARGS=\"/usr/sbin/td-agent --log /var/log/td-agent/td-agent.log --use-v1-config\"" > /etc/sysconfig/td-agent
status=$?
error_check $status "populate sysconfig file /etc/sysconfig/td-agent"


#appending line to td-agent.conf
echo "@include config.d/*.conf" >> /etc/td-agent/tdagent.conf
status=$?
error_check $status "appending line to td-agent.conf"

#Create the /etc/td-agent/config.d/kubernetes.conf file
echo "<source>
      type tail
      path /var/lib/docker/containers/*/*-json.log
      pos_file /var/log/td-agent/tmp/fluentd-docker.pos
      time_format %Y-%m-%dT%H:%M:%S
      tag docker.*
      format json
      read_from_head true
    </source>

    <match docker.var.lib.docker.containers.*.*.log>
      type kubernetes
      container_id ${tag_parts[5]}
      tag docker.${name}
    </match>

    <match kubernetes>
      type copy
      <store>
        type forward
        send_timeout 60s
        recover_wait 10s
        heartbeat_interval 1s
        phi_threshold 16
        hard_timeout 60s
        log_level trace
        require_ack_response true
        heartbeat_type tcp
        <server>
          name logging_name 1
          host host_name 2
          port 24224
          weight 60
        </server>

        <secondary>
          type file
          path /var/log/td-agent/forward-failed
        </secondary>
      </store>

      <store>
        type file
        path /var/log/td-agent/containers.log
        time_slice_format %Y%m%d
        time_slice_wait 10m
        time_format %Y%m%dT%H%M%S%z
        compress gzip
        utc
      </store>
    </match>" > /etc/td-agent/config.d/kubernetes.conf

status=$?
error_check $status "writing /etc/td-agent/config.d/kubernetes.conf"

chkconfig td-agent on
status=$?
error_check $status "enabling td-agent"


systemctl start td-agent
status=$?
error_check $status "starting td-agent"

echo "Success! Any errors will now be logged to the /var/log/td-agent/td-agent.log file." 
