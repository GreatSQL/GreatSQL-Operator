#!/bin/bash
images=(
        kube-apiserver:v1.23.17
        kube-controller-manager:v1.23.17
        kube-scheduler:v1.23.17
        kube-proxy:v1.23.17
        pause:3.6
        etcd:3.5.1-0
        coredns:1.8.6
)

for imageName in ${images[@]};do
        docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName
        docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName k8s.gcr.io/$imageName
        docker rmi registry.cn-hangzhou.aliyuncs.com/google_containers/$imageName 
done
EOF