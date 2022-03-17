## Description
This project is part of a knowledge sharing presentation done in-house with the purpose of displaying how to run a kubernetes cluster (locally) and deploy http/grpc services on it that can receive external traffic. It uses KinD (Kubernetes in Docker) and the nginx-ingress controller(maintained by kubernetes

## prerequisites

* **Docker**  [installation docs](https://docs.docker.com/get-docker/)
* **kubectl** [installation guide](https://kubernetes.io/docs/tasks/tools/)
* **KinD**    [installation guide](https://kind.sigs.k8s.io/docs/user/quick-start/)
* **openssl** [docs](https://www.openssl.org/source/)
* **grpcurl** [repo](https://github.com/fullstorydev/grpcurl#installation) to make gRPC requests

## Steps

### Create local Kubernetes cluster
Run `make create-cluster`

Running the command above will execute `kind create cluster --config infra/kind_config.yml` 
which will create a **Kubernetes** cluster running on docker based on the configuration 
located in `infra/kind_config.yml` file. The Kubernetes cluster will have 1 **control-plane**
node and 3 **worker** nodes

### Deploy http service
Run `make apply-deloyment`

This will execute `kubectl apply -f infra/deployment.yml` command which will provision 2
[Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) which creates 
2 [ReplicaSets](https://kubernetes.io/docs/concepts/workloads/controllers/replicaset/) that 
will bring up 2 [Pods](https://kubernetes.io/docs/concepts/workloads/pods/) each. Those pods consist
of one container running the `hashicorp/http-echo:0.2.3` image. This image is a simple
http server that can return the text given by the `-text` argument. In our example one deployment
will run the containers with `-text=foo` and the other with `-text=bar`. Those containers expose the
port `5678` which is the default port of this [image](https://hub.docker.com/r/hashicorp/http-echo/)

#### Communicate with those containers
We can spin up a new pod with an `apline` image by running 
`kubectl run -i --tty --rm debug --image=alpine --restart=Never -- sh` after that we can install
cURL `apk add curl` 

in order to communicate form our `debug` pod to the 2 deployments we created previously we have
to know their IP addresses to find them we can use `kubectl get pods -n default` command
to find out the pod names (you should be able to see 2 `bar-deployment*`, 2 `foo-deployment*` and the `debug` pods).
Then we can use the `kubectl describe pod {pod-name}` command to get some more details about a specific Pod

Pods have the following DNS record
`{IP address separated with dashes}.{namespace of the pod}.pod.cluster.local` so you could make a
request to the pods by using the DNS record or by using directly the pod's IP address.

#### Networking
Kubernetes has the [Service](https://kubernetes.io/docs/concepts/services-networking/service/) concept 
as "an abstract way to expose an application running on a set of Pods as a network service."

So we can create a service resource for the deployments we added on the previous set by running
`make apply-services` command. Run `kubectl get services -n default` to see the service resources 
created. Now there are also DNS records for this service `{service-name}.{namespace}.svc.cluster.local`.
You can now try to do a `nslookup` form the `debug` container `nslookup bar-service` which should 
return something like
```
Name:   bar-service.default.svc.cluster.local
Address: 10.96.193.17
```

also you can call those services e.g `curl bar-service:80`, `curl foo-service:80` note that we 
use the port **80** here because we have configured in the Service resource definition the port mapping
from port **80** to port **5678**

#### External traffic
Kubernetes has the [Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/) resource
to manage the external access to the services.

you can run `make apply-ingress` to create this resource for our services which is configured to
route the traffic `{host}/bar` to **bar-service** and `{host}/foo` to the **foo-service**. When running 
`kubectl get ingress` command you should see an output similar to this one:

```
NAME           CLASS    HOSTS   ADDRESS   PORTS   AGE
http-ingress   <none>   *                 80      10s
```

An ingress my itself does not do anything, there is a need to have an [Ingress controller](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/).
For this example we'll use the [nginx ingress controller](https://github.com/kubernetes/ingress-nginx) maintained by the Kubernetes.

to apply it run `make install-nginx-controller` this will create a nginx-controller and wait for it to become ready
you can run `kubectl get pods -n ingress-nginx` to see the pods created by the command.

After the above command you can access your services by calling the `localhost/foo` and `localhost/bar` endpoints
(You can use a browser or cURL for the requests)


#### gRPC routing with TLS termination
Next we'll see how to route traffic to a gRPC service, you can run `make apply-grpc`
this will create certificates for `demo.localhost`
You can add a record to your `/etc/hosts` file 

```
127.0.0.1  demo.localhost
```

and store the certificate in a [secret](https://kubernetes.io/docs/concepts/configuration/secret/). 

Additionally, it will create a deployment, service and an Ingress.

After that you should be able to call the gRPC service from your host
`grpcurl -insecure -d '{"name":"Adjoe"}' demo.localhost:443 helloworld.Greeter/SayHello`

### destroying the local environment
Simply run `make delete-cluster`

### quickstart
running `make up` will create the cluster and all the resources mentioned above.