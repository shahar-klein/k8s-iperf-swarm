#!/bin/bash


num_iperf_servers=2
num_iperf_clients=2
thread_per_client=1
time_per_client=10

Usage() {
	echo "Usage: $0 -s num-servers[default: $num_iperf_servers] -c num-clients[default: $num_iperf_clients] -P num-threads-per-client[default: $thread_per_client] -l msg_size -b Bandwidth(kmgKMG) -t run-time[default: $time_per_client]"
	exit
}

PROTO=TCP
while getopts ":b:l:s:c:t:P:hu" opt; do
  case ${opt} in
    s )
      num_iperf_servers=$OPTARG
      ;;
    c )
      num_iperf_clients=$OPTARG
      ;;
    P )
      thread_per_client=$OPTARG
      ;;
    t )
      time_per_client=$OPTARG
      ;;
    b )
      BW=$OPTARG
      B_FLAG="-b $BW"
      ;;
    l )
      L=$OPTARG
      L_FLAG="-l $L"
      ;;
    u ) 
      PROTO=UDP
      P_FLAG="-u"
      ;;
    h )
	    Usage
      ;;
    \? )
	    Usage
      ;;
    : )
	    Usage
      ;;
  esac
done
shift $((OPTIND -1))

clear
echo
echo

echo "Going to swarm with: proto: $PROTO, $num_iperf_servers Servers, $num_iperf_clients Clients each runing $thread_per_client threads, for $time_per_client Seconds."

#run the server side
kubectl delete -f iperf.yaml
kubectl create -f iperf.yaml
#resize
kubectl scale --current-replicas=3 --replicas=$num_iperf_servers deployment/iperf-server-deployment
#wait for all up
echo "Waiting for all iperf servers to come up"
kubectl wait deployment/iperf-server-deployment --for=condition=available --timeout=120s

#get cluster-ip
CLUSTER_IP=`kubectl get svc iperf-server-service | tail -n 1 | awk '{print $3}'`

for (( i=0; i<$num_iperf_clients; i++ ))
do
        kubectl delete --ignore-not-found pods iperf$i  
done

#run the clients in a loop and wait for them to finish
for (( i=0; i<$num_iperf_clients; i++ ))
do 
        kubectl run iperf$i  --image=shaharklein/ub-iperf:latest --restart=Never -- iperf $P_FLAG $B_FLAG $L_FLAG -c $CLUSTER_IP  -P $thread_per_client -t $time_per_client -i 1 -o /tmp/iperf.log
done

echo "Waiting $time_per_client seconds for clients...."
sleep $time_per_client
sleep 2
# print stats
for (( i=0; i<$num_iperf_clients; i++ )) 
do 
        kubectl logs iperf$i 
done

#clean up
for (( i=0; i<$num_iperf_clients; i++ ))
do
        kubectl delete pods iperf$i  
done
#kubectl delete -f iperf.yaml

