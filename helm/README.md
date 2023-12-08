<!--
# Copyright (c) 2018-2023, NVIDIA CORPORATION. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#  * Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
#  * Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#  * Neither the name of NVIDIA CORPORATION nor the names of its
#    contributors may be used to endorse or promote products derived
#    from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS ``AS IS'' AND ANY
# EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
# PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
# OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
-->

[![License](https://img.shields.io/badge/License-BSD3-lightgrey.svg)](https://opensource.org/licenses/BSD-3-Clause)

# Kubernetes Deploy: Triton Inference Server Cluster

A helm chart for installing a single cluster of Triton Inference
Server is provided. By default the cluster contains a single instance
of the inference server but the *replicaCount* configuration parameter
can be set to create a cluster of any size, as described below.

This guide assumes you already have a functional Kubernetes cluster
and helm installed (see below for instructions on installing
helm). Note the following requirements:

* The helm chart deploys Prometheus and Grafana to collect and display Triton metrics. To use this helm chart you must install Prpmetheus and Grafana in your cluster as described below and your cluster must contain sufficient CPU resources to support these services.

* If you want Triton Server to use GPUs for inferencing, your cluster
must be configured to contain the desired number of GPU nodes with support for the NVIDIA driver and CUDA version required by the version
of the inference server you are using.

The steps below describe how to set-up a model repository, use helm to
launch the inference server, and then send inference requests to the
running server. You can access a Grafana endpoint to see real-time
metrics reported by the inference server.

## Installing Helm

### Helm v3

If you do not already have Helm installed in your Kubernetes cluster,
executing the following steps from the [official helm install
guide](https://helm.sh/docs/intro/install/) will
give you a quick setup.

## Installing OCI CLI

This guide uses OCI CLI for creating a bucket and copying files to that bucket. OCI object storage has an [Amazon S3 Compatibility API](https://docs.oracle.com/en-us/iaas/Content/Object/Tasks/s3compatibleapi.htm), which allows you to use your existing Amazon S3 tools (for example, the AWS CLI).

To install and configure the OCI CLI, please follow the instructions [in this link](https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm).

## Model Repository

If you already have a model repository you may use that with this helm
chart. If you do not have a model repository, you can checkout a local
copy of the inference server source repository to create an example
model repository::

```
git clone https://github.com/OguzPastirmaci/server.git
```

Fetch the example models:

```
cd server/docs/examples
./fetch_models.sh
```

Triton Server needs a repository of models that it will make available for inferencing. For this example you will place the model repository in an OCI Object Storage bucket. Use the **Region Identifier** in [this page](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) for your region (for example, `us-ashburn-1`).

```
oci os bucket create --name triton-inference-server-repository --compartment-id <compartment ID> --region <region>
```

Download the example model repository to your system and copy it into the OCI Object Storage bucket.

```
oci os object bulk-upload --bucket-name triton-inference-server-repository --prefix "model_repository/" --src-dir ./model_repository
```

### OCI Object Storage Repository
To load the model from the OCI Object Storage using the S3 Compatiblility API, you need to create a customer secret key.

`$USER` below is your user OCID. You can get it in the OCI Web Console by opening the **Profile** menu and click **My Profile**.

```
oci iam customer-secret-key create --user-id $USER --display-name 'triton' --query "data".{"AWS_SECRET_KEY_ID:\"id\",AWS_SECRET_ACCESS_KEY:\"key\""} --output=table
```

You will get an output similar to below:

```
+------------------------------------------+----------------------------------------------+
| AWS_SECRET_KEY_ID                        | AWS_SECRET_ACCESS_KEY                        |
+------------------------------------------+----------------------------------------------+
| 12349906bd96bbd2f1238df6c3fee22d7acd517  | KRkeeff9Mp3r3kPfxVdNG1ZMQEy9cy9vz+yv2XzGWDs= |
+------------------------------------------+----------------------------------------------+
```

Convert the following AWS S3 credentials in the base64 format and add it to the `values.yaml`.

**AWS_REGION**

Use the **Region Identifier** in [this page](https://docs.oracle.com/en-us/iaas/Content/General/Concepts/regions.htm) for the `AWS_REGION` in values region (for example, `us-ashburn-1`).

```
echo -n 'AWS_REGION' | base64
```

**AWS_SECRET_KEY_ID**

Use the `AWS_SECRET_KEY_ID` from the previous step.

```
echo -n 'AWS_SECRET_KEY_ID' | base64
```

**AWS_SECRET_ACCESS_KEY**

Use `AWS_SECRET_ACCESS_KEY` from the previous step.

```
echo -n 'AWS_SECRET_ACCESS_KEY' | base64
```

**modelRepositoryPath**

You will need to use the correct path for the model repository in values.yaml when using the OCI Object Storage Compatbility API.

`NAMESPACE` is your OCI Object Storage namespace. `REGION` is the region you used when creating the OCI Object Storage bucket.

```
s3://https://$NAMESPACE.compat.objectstorage.$REGION.oraclecloud.com:443/triton-inference-server-repository/model_repository
```

You can get your OCI Object Storage namespace by running `oci os ns get`. In the below output, the namespace is `axtaa4xl5cip`.

```
oci os ns get
{
  "data": "axtaa4xl5cip"
}
```

For example, if your namespace is `axtaa4xl5cip` and you created your bucket in `us-ashburn-1`, your model repository path will be:

```
s3://https://axtaa4xl5cip.compat.objectstorage.us-ashburn-1.oraclecloud.com:443/triton-inference-server-repository/model_repository
```

## Deploy Prometheus and Grafana

The inference server metrics are collected by Prometheus and viewable
by Grafana. The inference server helm chart assumes that Prometheus
and Grafana are available so this step must be followed even if you
don't want to use Grafana.

Use the `kube-prometheus-stack` to install these components. The *serviceMonitorSelectorNilUsesHelmValues* flag is needed so that

Prometheus can find the inference server metrics in the *example* release deployed below.

```
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

```
$ helm install example-metrics --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false prometheus-community/kube-prometheus-stack
```

Then port-forward to the Grafana service so you can access it from
your local browser.

```
$ kubectl port-forward service/example-metrics-grafana 8080:80
```

Now you should be able to navigate in your browser to localhost:8080
and see the Grafana login page. Use username=admin and
password=prom-operator to login.

An example Grafana dashboard is available in dashboard.json. Use the
import function in Grafana to import and view this dashboard.

## Deploy the Inference Server

Deploy the inference server using the default configuration with the
following commands.

```
$ cd <directory containing Chart.yaml>
$ helm install example .
```

Use kubectl to see status and wait until the inference server pods are
running.

```
$ kubectl get pods
NAME                                               READY   STATUS    RESTARTS   AGE
example-triton-inference-server-5f74b55885-n6lt7   1/1     Running   0          2m21s
```

There are several ways of overriding the default configuration as
described in this [helm
documentation](https://helm.sh/docs/using_helm/#customizing-the-chart-before-installing).

You can edit the values.yaml file directly or you can use the *--set*
option to override a single parameter with the CLI. For example, to
deploy a cluster of four inference servers use *--set* to set the
replicaCount parameter.

```
$ helm install example --set replicaCount=4 .
```

You can also write your own "config.yaml" file with the values you
want to override and pass it to helm.

```
$ cat << EOF > config.yaml
namespace: MyCustomNamespace
image:
  imageName: nvcr.io/nvidia/tritonserver:custom-tag
  modelRepositoryPath: gs://my_model_repository
EOF
$ helm install example -f config.yaml .
```

## Using Triton Inference Server

Now that the inference server is running you can send HTTP or GRPC
requests to it to perform inferencing. By default, the inferencing
service is exposed with a LoadBalancer service type. Use the following
to find the external IP for the inference server. In this case it is
34.83.9.133.

```
$ kubectl get services
NAME                             TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)                                        AGE
...
example-triton-inference-server  LoadBalancer   10.18.13.28    34.83.9.133   8000:30249/TCP,8001:30068/TCP,8002:32723/TCP   47m
```

The inference server exposes an HTTP endpoint on port 8000, and GRPC
endpoint on port 8001 and a Prometheus metrics endpoint on
port 8002. You can use curl to get the meta-data of the inference server
from the HTTP endpoint.

```
$ curl 34.83.9.133:8000/v2
```

Follow the [QuickStart](../../docs/getting_started/quickstart.md) to get the example
image classification client that can be used to perform inferencing
using image classification models being served by the inference
server. For example,

```
$ image_client -u 34.83.9.133:8000 -m inception_graphdef -s INCEPTION -c3 mug.jpg
Request 0, batch size 1
Image 'images/mug.jpg':
    504 (COFFEE MUG) = 0.723992
    968 (CUP) = 0.270953
    967 (ESPRESSO) = 0.00115997
```

## Cleanup

Once you've finished using the inference server you should use helm to
delete the deployment.

```
$ helm list
NAME            REVISION  UPDATED                   STATUS    CHART                          APP VERSION   NAMESPACE
example         1         Wed Feb 27 22:16:55 2019  DEPLOYED  triton-inference-server-1.0.0  1.0           default
example-metrics	1       	Tue Jan 21 12:24:07 2020	DEPLOYED	prometheus-operator-6.18.0   	 0.32.0     	 default

$ helm uninstall example
$ helm uninstall example-metrics
```

For the Prometheus and Grafana services, you should [explicitly delete
CRDs](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack#uninstall-helm-chart):

```
$ kubectl delete crd alertmanagerconfigs.monitoring.coreos.com alertmanagers.monitoring.coreos.com podmonitors.monitoring.coreos.com probes.monitoring.coreos.com prometheuses.monitoring.coreos.com prometheusrules.monitoring.coreos.com servicemonitors.monitoring.coreos.com thanosrulers.monitoring.coreos.com
```

You may also want to delete the OCI Object storage bucket you created to hold the
model repository.

```
oci os bucket delete --empty --bucket-name triton-inference-server-repository
```
