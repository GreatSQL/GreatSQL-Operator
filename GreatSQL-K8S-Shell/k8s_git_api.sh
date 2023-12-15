#!/bin/bash
echo "------------- ⬇ PV ⬇-------------"
kubectl get pv -n greatsql
echo "  "
echo "------------ ⬇ PVC ⬇------------"
kubectl get pvc -n greatsql
echo "  "
echo "--------- ⬇ ConfigMap ⬇---------"
kubectl get ConfigMap -n greatsql
echo "  "
echo "---------- ⬇ Service ⬇----------"
kubectl get service -n greatsql
echo "  "
echo "-------- ⬇ StatefulSet ⬇--------"
kubectl get StatefulSet -n greatsql
echo "  "
echo "------------ ⬇ Pod ⬇------------"
kubectl get pod -n greatsql
echo "---------- Get API 完成----------"