#!/usr/bin/env bash

set -exuo pipefail

#  Script invoked by llmux when switching models

CMD="${1:?missing command}"
PORT="${2:?missing port}"
MODEL="${LLMUX_MODEL:?missing model name}"

# maps to the docker host
HEALTH_URL=http://host.docker.internal:$PORT/health

# This is created on the host by the listener service
# and bind mounted by docker in the compose file.
FIFO=/run/llmux-fifo/llmux.fifo


wait_until_alive () {
    local deadline res

    deadline=$((SECONDS + "${1:-60}"))
    while [[ $SECONDS -lt $deadline ]]; do
        res=0
        curl --max-time 3 -sf "${HEALTH_URL}" || res=$?
        if [[ $res -ne 0 ]]; then
            echo "curl returned error($res)..." >&2 
            sleep 0.5
            continue
        fi
        return 0
    done
    return 1
}

wait_until_dead () {
    local deadline
    local res

    deadline=$((SECONDS + "${1:-60}"))
    while [[ $SECONDS -lt $deadline ]]; do
        res=0
        curl --max-time 5 -sf "${HEALTH_URL}" || res=$?
        case "$res" in
            0|8|9|22|33|35|36|52|55|56|60|61|63|67|70|73|78)
                # we got a response from server... so it's still alive
                #
                # 0  -> OK
                # 8  -> CURLE_WEIRD_SERVER_REPLY
                # 9  -> CURLE_REMOTE_ACCESS_DENIED
                # 22 -> response code >= 400
                # 33 -> CURLE_RANGE_ERROR
                # 35 -> CURLE_SSL_CONNECT_ERROR
                # 36 -> CURLE_BAD_DOWNLOAD_RESUME
                # 52 -> CURLE_GOT_NOTHING
                # 55 -> CURLE_SEND_ERROR
                # 56 -> CURLE_RECV_ERROR
                # 60 -> CURLE_PEER_FAILED_VERIFICATION
                # 61 -> CURLE_BAD_CONTENT_ENCODING
                # 63 -> CURLE_FILESIZE_EXCEEDED
                # 67 -> CURLE_LOGIN_DENIED
                # 70 -> CURLE_REMOTE_DISK_FULL
                # 73 -> CURLE_REMOTE_FILE_EXISTS
                # 78 -> CURLE_REMOTE_FILE_NOT_FOUND
                sleep 0.5
                continue
                ;;
            7|28)
                # server is
                # 7  -> COULDNT_CONNECT
                # 28 -> CURLE_OPERATION_TIMEDOUT (overal timeout)
                return 0
                ;;
            *)
                # the result is inconclusive or irrelevant to http, and retrying won't help.
                echo "curl returned unexpected client error code=$res" >&2
                return 1
                ;;
        esac
    done
    # still alive
    return 1
}

# send the command on the fifo -- return an error
# if we can't write the message ($2) within N seconds ($1)
send_nonblocking () {
    local deadline=$((SECONDS + "${1:?missing timeout value}")) 
    local cmd="${2:?missing command}"
    
    while [[ $SECONDS -lt $deadline ]]; do
        dd if=<(echo "$cmd") of="$FIFO" oflag=nonblock 2>/dev/null || {
            echo "no reader on fifo..." >&2
            sleep 1
            continue
        }
        return 0
    done
    return 1
}

res=0
case "$CMD" in
    wake)
        send_nonblocking 10 "start $PORT $MODEL"
        wait_until_alive 300
        ;;
    sleep)
        send_nonblocking 10 "stop $PORT $MODEL"
        wait_until_dead 300
        ;;
    *)
        echo "invalid command: $CMD" >&2
        exit 1
esac

