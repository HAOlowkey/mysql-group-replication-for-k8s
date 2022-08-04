#!/usr/bin/env bash

set -o nounset
# ##############################################################################
# Globals, settings
# ##############################################################################
LANG=C

FILE_NAME="run_service"
VERSION="v1.1.1"
BIN_FILE="mysqld"
# ##############################################################################
# common function package
# ##############################################################################
die() {
    local status="${1}"
    shift
    local function_name="${1}"
    shift
    error "${function_name}" "$*"
    exit "$status"
}

error() {
    local function_name="${1}"
    shift
    local timestamp
    timestamp="$(date +"%Y-%m-%d %T %N")"

    [[ -f "${LOG_FILE}" ]] || touch "${LOG_FILE}"

    echo "[${timestamp}] ERR | (${VERSION})[${function_name}]: $* ;" | tee -a "${LOG_FILE}"
}

info() {
    local function_name="${1}"
    shift
    local timestamp
    timestamp="$(date +"%Y-%m-%d %T %N")"

    [[ -f "${LOG_FILE}" ]] || touch "${LOG_FILE}"

    echo "[${timestamp}] INFO| (${VERSION})[${function_name}]: $* ;" >>"${LOG_FILE}"
}

installed() {
    command -v "$1" >/dev/null 2>&1
}

wait_for_pid() {
    local func_name="wait_for_pid"

    local method="$1" # created | removed
    local pid="$2"    # process ID of the program operating on the pid-file
    local pid_file="$3"

    local i=0
    local avoid_race_condition="by checking again"
    local start_timeout=300

    while [[ ${i} -ne ${start_timeout} ]]; do
        case "$method" in
        'created')
            # wait for a PID-file to pop into existence.
            test -s "${pid_file}" && i='' && break
            ;;
        'removed')
            # wait for this PID-file to disappear
            test ! -s "${pid_file}" && i='' && break
            ;;
        *)
            error "${func_name}" "wait_for_pid () usage: wait_for_pid {created|removed} {pid}"
            return 2
            ;;
        esac

        # if server isn't running, then pid-file will never be updated
        if [[ -n "$pid" ]]; then
            if kill -0 "$pid" 2>/dev/null; then
                : # the server still runs
            else
                # The server may have exited between the last pid-file check and now.
                if test -n "$avoid_race_condition"; then
                    avoid_race_condition=""
                    continue # Check again.
                fi

                # there's nothing that will affect the file.
                error "${func_name}" "The server quit without updating PID file (${pid_file})."
                return 3 # not waiting any more.
            fi
        fi

        echo -n "."
        ((i++))
        sleep 1
    done

    if [[ -n "$i" ]]; then
        error "${func_name}" "wait_for_pid timeout(${start_timeout})"
        return 4
    fi

    return 0
}

get_pid() {
    local func_name="get_pid"
    local bin_file="${1}"

    local pid
    # get PID when PPID = 0
    pid="$(pgrep -P 0 -x "${bin_file}")"
    [[ -n "${pid}" ]] || pid="$(pgrep -P 1 -x "${bin_file}")"

    echo "${pid}"
}
# ##############################################################################
# service manager action function
# action function can use function( die ) and exit
# ##############################################################################
service_init() {
    local func_name="${FILE_NAME}.service_init"

    info "${func_name}" "Starting run ${func_name} ..."
    local flag
    flag="$(cat "${INIT_FLAG_FILE}" 2>/dev/null)"
    [[ "${flag}" != "SUCCESS" ]] || {
        die 0 "${func_name}" "${func_name} done, skip ${func_name} !"
    }

    local config_file="${CONFIG_PATH}/my-${HOSTNAME##*-}.cnf"
    [[ -f "${config_file}" ]] || die 21 "${func_name}" "${config_file} not exits!"

    local data_dir
    data_dir="$(awk -F '=' '/^datadir=/{print $2}' "${config_file}")" || die 22 "${func_name}" "get data_dir failed!"

    local tmp_dir
    tmp_dir="$(awk -F '=' '/^tmpdir=/{print $2}' "${config_file}")" || die 23 "${func_name}" "get tmp_dir failed!"

    local bin_log_dir
    bin_log_dir="$(awk -F '=' '/^log-bin=/{print $2}' "${config_file}")" || die 24 "${func_name}" "get bin_log_dir failed!"

    local relay_log_dir
    relay_log_dir="$(awk -F '=' '/^relay-log=/{print $2}' "${config_file}")" || die 25 "${func_name}" "get relay_log_dir failed!"

    local run_user
    run_user="$(awk -F '=' '/^user=/{print $2}' "${config_file}")" || die 26 "${func_name}" "get run_user failed!"

    rm -rf "${data_dir}" "${tmp_dir}" "${bin_log_dir}" "${relay_log_dir}"

    cp "${config_file}" "${DATA_PATH}/my.cnf" || die 27 "${func_name}" "cp my.cnf failed!"

    # create mysql dir and change owner to mysql user
    mkdir -p "${data_dir}" "${tmp_dir}" "${bin_log_dir}" "${relay_log_dir}"
    chown -R "${run_user}.${run_user}" "${DATA_PATH}" "${data_dir}" "${tmp_dir}" "${bin_log_dir}" "${relay_log_dir}"

    # generate init sql
    local init_sql
    init_sql="$(mktemp "/tmp/init.XXXXXX.sql")"
    chmod a+r "${init_sql}"

    case "${ARCH_MODE}" in
    "standalone")
        cat <<EOF >"${init_sql}"
SET @@SESSION.SQL_LOG_BIN=0;
INSERT INTO mysql.plugin (name, dl) VALUES ('validate_password', 'validate_password.so');
ALTER USER root@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';
CREATE USER ${MYSQL_USER}@'%' IDENTIFIED BY '${MYSQL_PASS}';
GRANT ALL ON *.* to ${MYSQL_USER}@'%';
FLUSH PRIVILEGES;
EOF
        ;;
    "group-replication")
        cat <<EOF >"${init_sql}"
SET @@SESSION.SQL_LOG_BIN=0;
INSERT INTO mysql.plugin (name, dl) VALUES ('validate_password', 'validate_password.so');
ALTER USER root@'localhost' IDENTIFIED BY '${ROOT_PASSWORD}';
CREATE USER ${MYSQL_USER}@'%' IDENTIFIED BY '${MYSQL_PASS}';
GRANT ALL ON *.* to ${MYSQL_USER}@'%';
INSTALL PLUGIN group_replication SONAME 'group_replication.so';
CREATE USER ${REPL_USER}@'%' IDENTIFIED BY '${REPL_PASS}';
GRANT REPLICATION SLAVE ON *.* TO ${REPL_USER}@'%';
CREATE USER ${MONITOR_USER}@'%' IDENTIFIED BY '${MONITOR_PASS}';
GRANT SELECT ON sys.* TO ${MONITOR_USER}@'%';
GRANT USAGE,REPLICATION CLIENT ON *.* TO ${MONITOR_USER}@'%';
FLUSH PRIVILEGES;
EOF
        ;;
    *)
        die 28 "${func_name}" "ARCH_MODE ${ARCH_MODE} not support!"
        ;;
    esac

    info "${func_name}" "Starting initialize!"
    "${BIN_FILE}" --defaults-file="${DATA_PATH}/my.cnf" --initialize-insecure --init-file="${init_sql}" || {
        rm -f "${init_sql}"
        die 29 "${func_name}" "Initialize failed!"
    }
    info "${func_name}" "Initialize done !"
    rm -f "${init_sql}"

    echo "SUCCESS" >"${INIT_FLAG_FILE}"
    info "${func_name}" "run ${func_name} done."
}

service_start() {
    local func_name="${FILE_NAME}.service_start"
    info "${func_name}" "Starting run ${func_name} ..."

    local config_file="${CONFIG_PATH}/my-${HOSTNAME##*-}.cnf"
    [[ -f "${config_file}" ]] || die 21 "${func_name}" "${config_file} not exits!"

    local run_user
    run_user="$(awk -F '=' '/^user=/{print $2}' "${config_file}")" || die 22 "${func_name}" "get run_user failed!"

    chown -R "${run_user}.${run_user}" "${DATA_PATH}" || die 23 "${func_name}" "chown dir failed!"

    cp "${config_file}" "${DATA_PATH}/my.cnf" || die 24 "${func_name}" "cp my.cnf failed!"

    info "${func_name}" "Starting mysql"
    "${BIN_FILE}" --defaults-file="${DATA_PATH}/my.cnf"
}

service_status() {
    mysqladmin status -uroot -p"${ROOT_PASSWORD}" -S "${DATA_PATH}/mysql.sock"
}

service_stop() {
    local func_name="${FILE_NAME}.service_stop"
    info "${func_name}" "Starting run ${func_name} ..."

    local pids
    pids="$(get_pid "${BIN_FILE}")"
    if [[ -n "${pids}" ]]; then
        local p
        info "${func_name}" "Shutting down ${UNIT_TYPE} ..."
        for p in $(get_pid "${BIN_FILE}"); do
            kill "${p}"
        done

        local pid
        # get PID
        pid="$(get_pid "${BIN_FILE}")"
        [[ -z "${pid}" ]] || {
            # mysqld should remove the pid file when it exits, so wait for it.
            wait_for_pid removed "${pid}" || {
                die 41 "${func_name}" "wait_for_pid failed!"
            }
        }
        rm -f "${PID_FILE}"
    else
        rm -f "${PID_FILE}"
        info "${func_name}" "SUCCESS! remove pid file, ${UNIT_TYPE} is not running!"
    fi
    info "${func_name}" "run ${func_name} done."
}

replication_init() {
    local func_name="${FILE_NAME}.replication_init"

    info "${func_name}" "Starting run ${func_name} ..."

    if [[ "${ARCH_MODE}" == "standalone" ]]; then
        info "${func_name}" "architecture is standalone, no need to execute replication init"
        exit 0
    fi

    #判断服务状态是否正常
    sleep 5
    service_status || {
        die 21 "${func_name}" "check service status failed!"
    }

    info "${func_name}" "check service status success!"

    #如果状态已经是ONLINE 则跳过集群状态初始化状态
    local sql="SELECT member_state FROM performance_schema.replication_group_members WHERE member_host LIKE '${HOSTNAME}%';"

    local member_state
    member_state="$(mysql -u"root" -S "${DATA_PATH}/mysql.sock" -p''"${ROOT_PASSWORD}"'' -AN -s -e "${sql}" 2>/dev/null)"

    info "${func_name}" "member_status is ${member_state}"

    if [[ "${member_state}" == "ONLINE" ]]; then
        info "${func_name}" "${HOSTNAME} has been in this group, no need to join!"
        exit 0
    fi

    local repl_flag
    repl_flag="$(cat "${REPL_FLAG_FILE}" 2>/dev/null)"
    if [[ "${repl_flag}" != "SUCCESS" ]]; then
        if [[ ${HOSTNAME##*-} -eq 0 ]]; then
            sql="CHANGE MASTER TO MASTER_USER='${REPL_USER}', MASTER_PASSWORD='${REPL_PASS}' FOR CHANNEL 'group_replication_recovery';
        STOP GROUP_REPLICATION;
        SET GLOBAL group_replication_bootstrap_group=ON;
        START GROUP_REPLICATION;
        SET GLOBAL group_replication_bootstrap_group=OFF;
        "
        else
            sql="CHANGE MASTER TO MASTER_USER='${REPL_USER}', MASTER_PASSWORD='${REPL_PASS}' FOR CHANNEL 'group_replication_recovery';
        STOP GROUP_REPLICATION;
        START GROUP_REPLICATION;"
        fi
        mysql -u"root" -S "${DATA_PATH}/mysql.sock" -p''"${ROOT_PASSWORD}"'' -AN -s -e "${sql}" &>>"${LOG_FILE}" || {
            die 23 "${func_name}" " ${sql} failed"
        }
        info "${func_name}" "start group_replication success"

        if [[ ${HOSTNAME##*-} -eq 2 ]]; then
            sql="SELECT MEMBER_HOST FROM performance_schema.replication_group_members WHERE MEMBER_ROLE='PRIMARY';"
            local primary_node
            primary_node="$(mysql -uroot -pRoot@123! -S /mysql/mysql.sock -AN -s -e "${sql}" 2>/dev/null)"
            [[ -n "${primary_node}" ]] || die 24 "${func_name}" "get primary node failed!"

            cat <<EOF >/tmp/sys.sql
USE sys;


DROP VIEW IF EXISTS gr_member_routing_candidate_status;

DROP FUNCTION IF EXISTS IFZERO;
DROP FUNCTION IF EXISTS LOCATE2;
DROP FUNCTION IF EXISTS GTID_NORMALIZE;
DROP FUNCTION IF EXISTS GTID_COUNT;
DROP FUNCTION IF EXISTS gr_applier_queue_length;
DROP FUNCTION IF EXISTS gr_member_in_primary_partition;
DROP FUNCTION IF EXISTS gr_transactions_to_cert;

DELIMITER \$\$

CREATE FUNCTION IFZERO(a INT, b INT)
RETURNS INT
DETERMINISTIC
RETURN IF(a = 0, b, a)\$\$

CREATE FUNCTION LOCATE2(needle TEXT(10000), haystack TEXT(10000), offset INT)
RETURNS INT
DETERMINISTIC
RETURN IFZERO(LOCATE(needle, haystack, offset), LENGTH(haystack) + 1)\$\$

CREATE FUNCTION GTID_NORMALIZE(g TEXT(10000))
RETURNS TEXT(10000)
DETERMINISTIC
RETURN GTID_SUBTRACT(g, '')\$\$

CREATE FUNCTION GTID_COUNT(gtid_set TEXT(10000))
RETURNS INT
DETERMINISTIC
BEGIN
  DECLARE result BIGINT DEFAULT 0;
  DECLARE colon_pos INT;
  DECLARE next_dash_pos INT;
  DECLARE next_colon_pos INT;
  DECLARE next_comma_pos INT;
  SET gtid_set = GTID_NORMALIZE(gtid_set);
  SET colon_pos = LOCATE2(':', gtid_set, 1);
  WHILE colon_pos != LENGTH(gtid_set) + 1 DO
     SET next_dash_pos = LOCATE2('-', gtid_set, colon_pos + 1);
     SET next_colon_pos = LOCATE2(':', gtid_set, colon_pos + 1);
     SET next_comma_pos = LOCATE2(',', gtid_set, colon_pos + 1);
     IF next_dash_pos < next_colon_pos AND next_dash_pos < next_comma_pos THEN
       SET result = result +
         SUBSTR(gtid_set, next_dash_pos + 1,
                LEAST(next_colon_pos, next_comma_pos) - (next_dash_pos + 1)) -
         SUBSTR(gtid_set, colon_pos + 1, next_dash_pos - (colon_pos + 1)) + 1;
     ELSE
       SET result = result + 1;
     END IF;
     SET colon_pos = next_colon_pos;
  END WHILE;
  RETURN result;
END\$\$

CREATE FUNCTION gr_applier_queue_length()
RETURNS INT
DETERMINISTIC
BEGIN
  RETURN (SELECT sys.gtid_count( GTID_SUBTRACT( (SELECT
Received_transaction_set FROM performance_schema.replication_connection_status
WHERE Channel_name = 'group_replication_applier' ), (SELECT
@@global.GTID_EXECUTED) )));
END\$\$


CREATE FUNCTION gr_transactions_to_cert() RETURNS int(11)
    DETERMINISTIC
BEGIN
  RETURN (select  performance_schema.replication_group_member_stats.COUNT_TRANSACTIONS_IN_QUEUE AS transactions_to_cert
    FROM
        performance_schema.replication_group_member_stats where MEMBER_ID=@@SERVER_UUID );
END\$\$

CREATE FUNCTION my_server_uuid() RETURNS TEXT(36) DETERMINISTIC NO SQL RETURN (SELECT @@global.server_uuid as my_id);\$\$

CREATE VIEW gr_member_routing_candidate_status AS
    SELECT
        IFNULL((SELECT
                        IF(MEMBER_STATE = 'ONLINE'
                                    AND ((SELECT
                                        COUNT(*)
                                    FROM
                                        performance_schema.replication_group_members
                                    WHERE
                                        MEMBER_STATE != 'ONLINE') >= ((SELECT
                                        COUNT(*)
                                    FROM
                                        performance_schema.replication_group_members) / 2) = 0),
                                'YES',
                                'NO')
                    FROM
                        performance_schema.replication_group_members
                            JOIN
                        performance_schema.replication_group_member_stats rgms USING (member_id)
                    WHERE
                        rgms.MEMBER_ID = my_server_uuid()),
                'NO') AS viable_candidate,
        IF((SELECT
                    ((SELECT
                                GROUP_CONCAT(performance_schema.global_variables.VARIABLE_VALUE
                                        SEPARATOR ',')
                            FROM
                                performance_schema.global_variables
                            WHERE
                                (performance_schema.global_variables.VARIABLE_NAME IN ('read_only' , 'super_read_only'))) <> 'OFF,OFF')
                ),
            'YES',
            'NO') AS read_only,
        IFNULL(sys.gr_applier_queue_length(), 0) AS transactions_behind,
        IFNULL(sys.gr_transactions_to_cert(), 0) AS transactions_to_cert;\$\$

DELIMITER ;
EOF

            mysql -u"${MYSQL_USER}" -h"${primary_node}" -p''"${MYSQL_PASS}"'' -AN -s -e "source /tmp/sys.sql" &>>"${LOG_FILE}" || {
                die 25 "${func_name}" " source /tmp/sys.sql failed"
            }
        fi
        echo "SUCCESS" >"${REPL_FLAG_FILE}"
    fi

    info "${func_name}" "run ${func_name} done."
}
# ##############################################################################
# The main() function is called at the action function.
# ##############################################################################
main() {
    local func_name="main"
    local object="${1}"
    local action="${2:-}"

    local flag
    flag="$(cat "${INIT_FLAG_FILE}" 2>/dev/null)"

    case "${object}" in
    "service")
        case "${action}" in
        "init")
            service_init
            ;;
        "start")
            [[ "${flag}" == "SUCCESS" ]] || die 11 "${func_name}" "service_init without SUCCESS!"
            service_start
            ;;
        "stop")
            [[ "${flag}" == "SUCCESS" ]] || die 11 "${func_name}" "service_init without SUCCESS!"
            service_stop
            ;;
        "status")
            service_status
            ;;
        esac
        ;;
    "replication")
        local input="${3:-}"

        [[ "${flag}" == "SUCCESS" ]] || die 11 "${func_name}" "service_init without SUCCESS!"

        case "${action}" in
        "init")
            replication_init "${input}"
            ;;
        esac
        ;;
    esac
}

[ -v DATA_PATH ] || die 10 "Globals" "get env DATA_PATH failed !"
[ -v CONFIG_PATH ] || die 10 "Globals" "get env CONFIG_PATH failed !"
[ -v ROOT_PASSWORD ] || die 10 "Globals" "get env ROOT_PASSWORD failed!"
[ -v ARCH_MODE ] || die 10 "Globals" "get env ARCH_MODE failed!"
if [[ "${ARCH_MODE}" == "group-replication" ]]; then
    [ -v REPL_USER ] || die 10 "Globals" "get env REPL_USER failed!"
    [ -v REPL_PASS ] || die 10 "Globals" "get env REPL_PASS failed!"
    [ -v MONITOR_USER ] || die 10 "Globals" "get env MONITOR_USER failed!"
    [ -v MONITOR_PASS ] || die 10 "Globals" "get env MONITOR_PASS failed!"
fi
LOG_FILE="${DATA_PATH}/${FILE_NAME}.log"
INIT_FLAG_FILE="${DATA_PATH}/.init.flag"
REPL_FLAG_FILE="${DATA_PATH}/.repl.flag"

main "${@:-""}"
