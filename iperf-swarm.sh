#!/bin/bash


num_iperf_servers=2
num_iperf_clients=2
thread_per_client=4
time_per_client=10

Usage() {
	echo "Usage: $0 -s num-servers[default: $num_iperf_servers] -c num-clients[default: $num_iperf_clients] -t num-threads-per-client[default: $thread_per_client] -T run-time[default: $time_per_client]"
	exit
}

while getopts ":s:c:t:T:h" opt; do
  case ${opt} in
    s )
      num_iperf_servers=$OPTARG
      ;;
    c )
      num_iperf_clients=$OPTARG
      ;;
    t )
      thread_per_client=$OPTARG
      ;;
    T )
      time_per_client=$OPTARG
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

echo "Going to swarm with: $num_iperf_servers Servers, $num_iperf_clients Clients each runing $thread_per_client threads, for $time_per_client Seconds."

#run the server side
kubectl delete -f iperf.yaml
kubectl create -f iperf.yaml
#resize
kubectl scale --current-replicas=3 --replicas=$num_iperf_servers deployment/iperf-server-deployment
#wait for all up
echo "Waiting for all iperf servers to come up"
until [ $(kubectl get deployment iperf-server-deployment | tail -n 1 | awk '{print $5}') -eq $num_iperf_servers ]; 
do
        sleep 1
        echo -n .
done
echo

#get cluster-ip
CLUSTER_IP=`kubectl get svc iperf-server-service | tail -n 1 | awk '{print $3}'`

for (( i=0; i<$num_iperf_clients; i++ ))
do
        kubectl delete pods iperf$i  
done

#run the clients in a loop and wait for them to finish
for (( i=0; i<$num_iperf_clients; i++ ))
do 
        kubectl run iperf$i  --image=shaharklein/ub-iperf:latest --restart=Never -- iperf -c $CLUSTER_IP  -P $thread_per_client -t $time_per_client
done

echo "Waiting $time_per_client seconds for clients...."
sleep $time_per_client
sleep 2
# print stats
for (( i=0; i<$num_iperf_clients; i++ )) 
do 
        kubectl logs iperf$i | grep SUM 
done

#clean up
for (( i=0; i<$num_iperf_clients; i++ ))
do
        kubectl delete pods iperf$i  
done
kubectl delete -f iperf.yaml

