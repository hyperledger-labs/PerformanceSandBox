# PerformanceSandBox

## Short Description
The Performance Sandbox is a Sandbox for Hyperledger Projects Performance research usage. It allows easy use of performance related works with this sandbox lab.

## Scope of Project
PSWG published [white paper](https://www.hyperledger.org/wp-content/uploads/2018/10/HL_Whitepaper_Metrics_PDFVersion.pdf) in previous activities. Ref to a sample blockchain network as below, defined serval metrics.
![What is Performance Sandbox](./docs/images/PerformanceSandBox(2022May).png "What is Perfomance Sandbox")
Now with this proejct, we are upgrading observer client from traditional monitoring to observability and monitoring in the future.

> Traditional Monitoring
Traditionally, monitoring has focused on time series metrics. The process was always the same; collect a bunch of metrics, put those metrics on charts on dashboards, figure out which metrics to set alerts for, and choose some thresholds for alerting.

> Observability
While still including all the numbers and graphs from monitoring, it adds the knowledge of what is meaningful to be monitored to all the different, previously separate teams. On top of that, Observability adds Distributed Tracing, basically a microservices stack trace. What that means will be discussed in a few minutes. And not to forget, meaningful log analytics, far beyond the simple regex based error search. We gather information directly from the inside of the service and bring it together with everything else we know of the system. When looking at Observability we see three pillars to bring insight and understanding into our issue: Health and Performance Metrics, (Distributed) Traces, and Logs.

> Monitoring
Monitoring is the process that connects observability and controllability. Controllability here being the ability to rectify the system when its inferred state deviates or needs to adapt to changes including those within the environment or the management process.

Which means we are going to support Metrics, (Distributed) Traces, and Logs with a all in one sandbox, as PerformanceSandbox. It will gather information directly from the inside of the service and bring it together. Get ready for any kind observability or operator relate things with user's business, by basic information/data collection.

## What's benefits for you with PerformanceSandbox
By bring monitoring from the inside of applications and
services, and bring it together with everything else we know of the system. So that we are further design, think and evaluate performance from different perspectives, either single service or system as a whole.
1. PerformanceSandbox helps you understand metrics, shortcomings and evolutions for your blockchain service by analyzing bottlenecks or scalability.
1. PerformanceSandbox helps you start with a performance or operator related work(or observability driven development in short), as it can be your local development env.

## Target for this PerformanceSandbox
Find and define new things with blockchain performance, as in blockchain world, it is distributed and has different workloads amang IO as network, file system, and crypto logic generally as compute works. Hence by PerformanceSandbox we hope to make
- Single Tx analysis from black box to white box by distributed tracing.
Traditionally, when we talking about letnecy and other metrics for specific transaction, we rely on timestemp from different part of components. Hence, by distributed tracing, we are attempting to make analysis from black box to white box. To get better understanding as how much time spend on crypto, IO, consensus, etc.
- Overall system insight for blockchain system performance. By collection all information as system status as metrics or others, we can have a insight from overall side. For example, 
> In previous white paper defined metric as read latency for specific transactions, and now, are we able to have a p99 read latency happens on application or sdk side?

> Considering crypto is heavy compute workload on CPU, by gathering CPU metrics and latency metrics together, it's easy for us to know if workload too much or not.

## Design & implementation
PerformanceSandbox bases on kubernetes(as kind/minikube) as infrastructure, integrated with logging, metrics and distributed tracing.
- PerformanceSandbox supports user deploy a target network(as test-network for asset transform for Fabric), as SUT(system under test).
- PerformanceSandbox supports any traffic generator such as [Tape](https://github.com/Hyperledger-TWGC/tape), keep sending traffic to the target network/SUT.

### Flexible is considered and discussed:
- Migration from Kind/Minikube to other k8s platform. In this lab, we will use k8s as infrastructure, hence it is easy to migrate to any other k8s based infrastructure.
- Replace with other blockchain system from Fabric to others. So far, the POC and demos been made base on Hyperledger Fabric, as the orange area shows the blockchain system, can be replaced with any kind of blockchain system you wanted.
- Traffic generator, so far deployed demo with Tape, as it is k8s development. It can be replaced with Caliper or Jmeter. Tape is a sample performance tool for Hyperledger Fabric without SDK(close to blockchain network itself). Caliper is based on Hyperledger Fabric SDK(more close to application level). For Jmeter, assuming you expose RESTFUL endpoint to enduser. You may need use Jmeter to create traffic as end to end performance research.
- Size of SUT, you are able to scale the size for SUT, as it is blockchain based on k8s.

## Features(currently support Hyperledger Fabric)
- [x] [Deploy monitoring system to Kind or minikube.](./docs/k8s.md)
- [x] [Dashboard for monitoring system.](./docs/dashboard.md)
- [x] [Deploy fabric network.](./docs/SUT.md)
- [x] [Deploy your own chaincode for test as NFT.](./docs/SUT.md)
- [x] [Deploy traffic generator system.](./docs/Traffic.md)
- [x] [Deploy with local image support.](./docs/SUT.md)
- [x] [Deploy Sample application support.](./docs/App.md)
- [x] [Test Sample application with jmeter](./docs/App.md)

## [FAQ](https://github.com/hyperledger-labs/PerformanceSandBox/wiki/FAQ)

## Initial Committers
- [Sam Yuan](https://github.com/SamYuan1990)

# Code of Conduct guidelines
Please review the Hyperledger [Code of
Conduct](https://wiki.hyperledger.org/community/hyperledger-project-code-of-conduct)
before participating. It is important that we keep things civil.

## Contribution
Here is steps in short for any contribution. 
1. check license and code of conduct
1. fork this project
1. make your own feature branch
1. change and commit your changes, please use `git commit -s` to commit as we enabled [DCO](https://probot.github.io/apps/dco/)
1. raise PR

## Sponsor
- haris.javaid@amd.com - Member of Hyperledger PSWG

## [Project meeting](https://wiki.hyperledger.org/display/PSWG/Performance+and+Scale+Working+Group)
