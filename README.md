# supplychan-security-tekton


# Supply Chain Security and SLSA

Santiago Torres-Arias, assitant professor in Prudent university, gave an
intressing analogy in this
[podcast](https://kubernetespodcast.com/episode/174-in-toto/) to the
supply-chain security. When clients buy an orange juice in the supermarcket,
they verify the FDA certificat on the bottles which establish the trust between
the client and the producer. The main goals of supply chain security is to make
sure that source code of software artifacts are well protected, the building
process is not compromised and the artifact is well delivered to clients without
modification.

The [official website](https://slsa.dev/spec/v1.0/threats-overview) of SLSA
(Supply-Chain Levels for Software Artifacts), gives the analysis of the
vulnerability from the dev phrase to the deploy phrase. 

<center>
    
![The Supply Chain vulnerability](https://slsa.dev/images/v1.0/supply-chain-threats.svg)
*supply chain vulnerablility*

</center>

Additionally, slsa defines 4 supply-chain security levels, In the following
[figure](https://www.chainguard.dev/unchained/building-trust-in-our-software-supply-chains-with-slsa),
one can find the requirements for each security levels. 

<center>
    
   ![slsa
    requirement](https://assets.website-files.com/6228fdbc6c971401d02a9c42/631de087c664e8f26f642e80_Untitled.png)

</center>



Some projects are there to enhence the supply-chain security. The most famous
project is called [sigstore](https://www.sigstore.dev/). It makes the supply
chain security easier by providing [keyless signing
methode](https://docs.sigstore.dev/cosign/openid_signing/) therefore developpers
are no longer responsible to keep the signing key well protected.


<!--<center>

![Security](https://s3.rezel.net/codimd/uploads/upload_7fd2e8785413e614c22c25215d3c4407.jpg)

*Security*

</center>

-->


## Tekton and Tekton Chain

The [presentation](https://youtu.be/iZpFtalj4xE) gave two demo to achieve slsa
L2 with Tekton chain and slsa L3 with github action. I was insterested in Tekton
Chain so I spent time to undertand how tekton chain works. 

[Tekton](https://tekton.dev/) is kubernetes native CI/CD pipeline. It has three
levels of building blocks: `Step`, `Task`and `Pipeline`. A `Step` is mapped to
container. A `Task` a sequence of steps running in the sequence of container
encapulated into a pod. A `Pipeline` is just a list of `Tasks` that can be
executed sequentially or parallelly. The detail of Tekton can be found in its
official website. 


[Tekton chain](https://tekton.dev/docs/chains/) is a tool that can revieve that
result of the tekton building pipeline and generate signed provenance. The
provenance will contains the environment variable, the digest and on which
environment the artifact is builded. 

<center>
    
![](https://s3.rezel.net/codimd/uploads/upload_dd67a65ea30d4464eaab4bac90ffa91d.png)
*[How Tekton Chain works](https://tekton.dev/docs/chains/signed-provenance-tutorial/)*

</center>

A demo to illustrate how to use Tekton chain is shown in the [Demonstration](#Demonstration)


### Slsa Level 3 with Tekton Chain

The only reason why Tekton chain cannot achieve slsa L3 is that Tekton chain
cannot provide the Non-falsifable provanance because the data that Tekton chain
consume in order to generate the provanance is not authenticated. 

![](https://s3.rezel.net/codimd/uploads/upload_0ce873e545fc8975af19fae58acdf264.png)


In this [conference](https://youtu.be/Ij0Mtoj5hpA)
([slide](https://static.sched.com/hosted_files/ossna2022/e2/Tekton%20%26%20SPIRE%20%281%29.pdf)),
they identified the problems of slsa and provided the roadmap to achieve the
slsa L3 by integrating spiffe/spire. 

The feature related to non-falsifable is called **[TaskRun Result
Attestation](https://tekton.dev/docs/pipelines/spire/)**. It is still currently
an alpha experimental feature so the documentation isn't completed. I tried to
enable the feature by following the instruction but I couldn't manage to do it. 

# Demonstration

## SLSA L2 with Tekton chain

### Setup
```bash
$ ./setup.sh
```
The script
- deploys  [tekton pipeline](https://tekton.dev/docs/installation/pipelines/)
  and [tekton chain](https://tekton.dev/docs/chains/#installation) in the
  kubernetes cluster. 
- configures Tekton Chain. [doc](https://github.com/tektoncd/chains/blob/main/docs/config.md)
    ```    
    "artifacts.taskrun.format": "in-toto"
    "artifacts.taskrun.storage": "oci, tekton"
    "transparency.enabled": "true"
    ```
- load 3 tasks [`git-clone`](https://hub.tekton.dev/tekton/Task/git-clone/0.9),
  [`buildpacks`](https://hub.tekton.dev/tekton/Task/buildpacks/0.5) and
  [`buildpacks-phases`](https://hub.tekton.dev/tekton/Task/buildpacks-phases/0.2)
  and a pipeline
  [`buildpacks-pipeline`](https://hub.tekton.dev/tekton/pipeline/buildpacks) into Tekton pipeline.
  [demo ref](https://youtu.be/EHZA_kMHmYE?t=1034)
- Installs
  [`cosign`](https://github.com/tektoncd/chains/blob/main/docs/config.md)
  command to using sigstore project solution. 
- Generate signingkey with [`cosign`](https://github.com/tektoncd/chains/blob/main/docs/config.md)
- Installs [`crane`](https://github.com/google/go-containerregistry) command to
  interact with container registries.
- Generate signingkey with [`cosign`](https://github.com/tektoncd/chains/blob/main/docs/config.md)
- deploys tekton dashboard for better UI. 
- installs tekton CLI `tkn`

### Check the installation 
One can check the loaded tasks and pipelines with the command `tkn`.

```bash
$ tkn task ls
NAME                DESCRIPTION              AGE
buildpacks          The Buildpacks task...   2 hours ago
buildpacks-phases   The Buildpacks-Phas...   2 hours ago
git-clone           These Tasks are Git...   2 hours ago
```

```bash
$ tkn pipeline ls
NAME                   AGE              LAST RUN   STARTED   DURATION   STATUS
buildpacks-pipeline    22 seconds ago   ---        ---       ---        ---
```

### Building artifacts with provenance 

The following command is going to clone a sample [docker container source
code](https://github.com/PoisWu/docker-source-code) that I learned from gin204
with `git-clone` task. After, Tekton chain will sign the provenance with a
private key stored as `signing-secrets` secret in `tekton-chains` namespace push
to `ttl.sh/tekton-test:1h`

```bash
$ kubectl create -f run-buildpacks.yaml
```

After waiting for a while, we can check the execution result with 

```bash
$ tkn pipelinerun describe --last
```
```console
Name:              buildpacks-pipelinerun-spvj6
Namespace:         default
Pipeline Ref:      buildpacks
Service Account:   default
Labels:
 app.kubernetes.io/version=0.1
 tekton.dev/pipeline=buildpacks
Annotations:
 chains.tekton.dev/cert-pipelinerun-7c1b8ea6-126a-4987-bada-d0f751e293cf=
 chains.tekton.dev/chain-pipelinerun-7c1b8ea6-126a-4987-bada-d0f751e293cf=
 chains.tekton.dev/payload-pipelinerun-7c1b8ea6-126a-4987-bada-d0f751e293cf=eyJjb25kaXRpb25zIjpbeyJ0eXBlIjoiU3VjY2VlZGVkIiwic3RhdHVzIjoiVHJ1ZSIsImxhc3RUcmFuc2l0aW9uVGltZSI6IjIwMjMtMDYtMTlUMTk6Mzg6MzJaIiwicmVhc29uIjoiQ29tcGxldGVkIiwibWVzc2FnZSI6IlRhc2tzIENvbXBsZXRlZDogMiAoRmFpbGVkOiAwLCBDYW5jZWxsZWQgMCksIFNraXBwZWQ6IDEifV0sInN0YXJ0VGltZSI6IjIwMjMtMDYtMTlUMTk6Mzc6NDZaIiwiY29tcGxldGlvblRpbWUiOiIyMDIzLTA2LTE5VDE5OjM4OjMyWiIsInBpcGVsaW5lU3BlYyI6eyJkZXNjcmlwdGlvbiI6IlRoZSBCdWlsZHBhY2tzIHBpcGVsaW5lIGJ1aWxkcyBzb3VyY2UgZnJvbSBhIEdpdCByZXBvc2l0b3J5IGludG8gYSBjb250YWluZXIgaW1hZ2UgYW5kIHB1c2hlcyBpdCB0byBhIHJlZ2lzdHJ5LCB1c2luZyBDbG91ZCBOYXRpdmUgQnVpbGRwYWNrcy4iLCJ0YXNrcyI6W3sibmFtZSI6ImZldGNoLWZyb20tZ2l0IiwidGFza1JlZiI6eyJuYW1lIjoiZ2l0LWNsb25lIiwia2luZCI6IlRhc2sifSwicGFyYW1zIjpbeyJuYW1lIjoidXJsIiwidmFsdWUiOiJodHRwczovL2dpdGh1Yi5jb20vUG9pc1d1L2RvY2tlci1zb3VyY2UtY29kZSJ9LHsibmFtZSI6InJldmlzaW9uIiwidmFsdWUiOiIifV0sIndvcmtzcGFjZXMiOlt7Im5hbWUiOiJvdXRwdXQiLCJ3b3Jrc3BhY2UiOiJzb3VyY2Utd3MifSx7Im5hbWUiOiJzc2gtZGlyZWN0b3J5Iiwid29ya3NwYWNlIjoiZ2l0LWNyZWRlbnRpYWxzIn1dfSx7Im5hbWUiOiJidWlsZC10cnVzdGVkIiwidGFza1JlZiI6eyJuYW1lIjoiYnVpbGRwYWNrcyIsImtpbmQiOiJUYXNrIn0sIndoZW4iOlt7ImlucHV0IjoidHJ1ZSIsIm9wZXJhdG9yIjoiaW4iLCJ2YWx1ZXMiOlsidHJ1ZSIsInllcyIsIlRSVUUiLCJUcnVlIl19XSwicnVuQWZ0ZXIiOlsiZmV0Y2gtZnJvbS1naXQiXSwicGFyYW1zIjpbeyJuYW1lIjoiQlVJTERFUl9JTUFHRSIsInZhbHVlIjoiZG9ja2VyLmlvL2NuYnMvc2FtcGxlLWJ1aWxkZXI6YmlvbmljQHNoYTI1Njo2YzAzZGQ2MDQ1MDNiNTk4MjBmZDE1YWRiYzY1YzBhMDc3YTQ3ZTMxZDQwNGEzZGNhZDE5MGYzMTc5ZTkyMGI1In0seyJuYW1lIjoiQVBQX0lNQUdFIiwidmFsdWUiOiJ0dGwuc2gvdGVrdG9uLXRlc3Q6MWgifSx7Im5hbWUiOiJTT1VSQ0VfU1VCUEFUSCIsInZhbHVlIjoiIn0seyJuYW1lIjoiUFJPQ0VTU19UWVBFIiwidmFsdWUiOiJ3ZWIifSx7Im5hbWUiOiJFTlZfVkFSUyIsInZhbHVlIjpbXX0seyJuYW1lIjoiUlVOX0lNQUdFIiwidmFsdWUiOiIifSx7Im5hbWUiOiJDQUNIRV9JTUFHRSIsInZhbHVlIjoiIn0seyJuYW1lIjoiVVNFUl9JRCIsInZhbHVlIjoiMTAwMCJ9LHsibmFtZSI6IkdST1VQX0lEIiwidmFsdWUiOiIxMDAwIn1dLCJ3b3Jrc3BhY2VzIjpbeyJuYW1lIjoic291cmNlIiwid29ya3NwYWNlIjoic291cmNlLXdzIn0seyJuYW1lIjoiY2FjaGUiLCJ3b3Jrc3BhY2UiOiJjYWNoZS13cyJ9LHsibmFtZSI6ImRvY2tlcmNvbmZpZyIsIndvcmtzcGFjZSI6ImRvY2tlci1jcmVkZW50aWFscyJ9XX0seyJuYW1lIjoiYnVpbGQtdW50cnVzdGVkIiwidGFza1JlZiI6eyJuYW1lIjoiYnVpbGRwYWNrcy1waGFzZXMiLCJraW5kIjoiVGFzayJ9LCJ3aGVuIjpbeyJpbnB1dCI6InRydWUiLCJvcGVyYXRvciI6Im5vdGluIiwidmFsdWVzIjpbInRydWUiLCJ5ZXMiLCJUUlVFIiwiVHJ1ZSJdfV0sInJ1bkFmdGVyIjpbImZldGNoLWZyb20tZ2l0Il0sInBhcmFtcyI6W3sibmFtZSI6IkJVSUxERVJfSU1BR0UiLCJ2YWx1ZSI6ImRvY2tlci5pby9jbmJzL3NhbXBsZS1idWlsZGVyOmJpb25pY0BzaGEyNTY6NmMwM2RkNjA0NTAzYjU5ODIwZmQxNWFkYmM2NWMwYTA3N2E0N2UzMWQ0MDRhM2RjYWQxOTBmMzE3OWU5MjBiNSJ9LHsibmFtZSI6IkFQUF9JTUFHRSIsInZhbHVlIjoidHRsLnNoL3Rla3Rvbi10ZXN0OjFoIn0seyJuYW1lIjoiU09VUkNFX1NVQlBBVEgiLCJ2YWx1ZSI6IiJ9LHsibmFtZSI6IkVOVl9WQVJTIiwidmFsdWUiOltdfSx7Im5hbWUiOiJQUk9DRVNTX1RZUEUiLCJ2YWx1ZSI6IndlYiJ9LHsibmFtZSI6IlJVTl9JTUFHRSIsInZhbHVlIjoiIn0seyJuYW1lIjoiQ0FDSEVfSU1BR0UiLCJ2YWx1ZSI6IiJ9LHsibmFtZSI6IlVTRVJfSUQiLCJ2YWx1ZSI6IjEwMDAifSx7Im5hbWUiOiJHUk9VUF9JRCIsInZhbHVlIjoiMTAwMCJ9XSwid29ya3NwYWNlcyI6W3sibmFtZSI6InNvdXJjZSIsIndvcmtzcGFjZSI6InNvdXJjZS13cyJ9LHsibmFtZSI6ImNhY2hlIiwid29ya3NwYWNlIjoiY2FjaGUtd3MifSx7Im5hbWUiOiJkb2NrZXJjb25maWciLCJ3b3Jrc3BhY2UiOiJkb2NrZXItY3JlZGVudGlhbHMifV19XSwicGFyYW1zIjpbeyJuYW1lIjoiQlVJTERFUl9JTUFHRSIsInR5cGUiOiJzdHJpbmciLCJkZXNjcmlwdGlvbiI6IlRoZSBpbWFnZSBvbiB3aGljaCBidWlsZHMgd2lsbCBydW4gKG11c3QgaW5jbHVkZSBsaWZlY3ljbGUgYW5kIGNvbXBhdGlibGUgYnVpbGRwYWNrcykuIn0seyJuYW1lIjoiVFJVU1RfQlVJTERFUiIsInR5cGUiOiJzdHJpbmciLCJkZXNjcmlwdGlvbiI6IldoZXRoZXIgdGhlIGJ1aWxkZXIgaW1hZ2UgaXMgdHJ1c3RlZC4gV2hlbiBmYWxzZSwgZWFjaCBidWlsZCBwaGFzZSBpcyBleGVjdXRlZCBpbiBpc29sYXRpb24gYW5kIGNyZWRlbnRpYWxzIGFyZSBvbmx5IHNoYXJlZCB3aXRoIHRydXN0ZWQgaW1hZ2VzLiIsImRlZmF1bHQiOiJmYWxzZSJ9LHsibmFtZSI6IkFQUF9JTUFHRSIsInR5cGUiOiJzdHJpbmciLCJkZXNjcmlwdGlvbiI6IlRoZSBuYW1lIG9mIHdoZXJlIHRvIHN0b3JlIHRoZSBhcHAgaW1hZ2UuIn0seyJuYW1lIjoiU09VUkNFX1VSTCIsInR5cGUiOiJzdHJpbmciLCJkZXNjcmlwdGlvbiI6IkEgZ2l0IHJlcG8gdXJsIHdoZXJlIHRoZSBzb3VyY2UgY29kZSByZXNpZGVzLiJ9LHsibmFtZSI6IlNPVVJDRV9SRUZFUkVOQ0UiLCJ0eXBlIjoic3RyaW5nIiwiZGVzY3JpcHRpb24iOiJUaGUgYnJhbmNoLCB0YWcgb3IgU0hBIHRvIGNoZWNrb3V0LiIsImRlZmF1bHQiOiIifSx7Im5hbWUiOiJTT1VSQ0VfU1VCUEFUSCIsInR5cGUiOiJzdHJpbmciLCJkZXNjcmlwdGlvbiI6IkEgc3VicGF0aCB3aXRoaW4gY2hlY2tlZCBvdXQgc291cmNlIHdoZXJlIHRoZSBzb3VyY2UgdG8gYnVpbGQgaXMgbG9jYXRlZC4iLCJkZWZhdWx0IjoiIn0seyJuYW1lIjoiRU5WX1ZBUlMiLCJ0eXBlIjoiYXJyYXkiLCJkZXNjcmlwdGlvbiI6IkVudmlyb25tZW50IHZhcmlhYmxlcyB0byBzZXQgZHVyaW5nIF9idWlsZC10aW1lXy4iLCJkZWZhdWx0IjpbXX0seyJuYW1lIjoiUFJPQ0VTU19UWVBFIiwidHlwZSI6InN0cmluZyIsImRlc2NyaXB0aW9uIjoiVGhlIGRlZmF1bHQgcHJvY2VzcyB0eXBlIHRvIHNldCBvbiB0aGUgaW1hZ2UuIiwiZGVmYXVsdCI6IndlYiJ9LHsibmFtZSI6IlJVTl9JTUFHRSIsInR5cGUiOiJzdHJpbmciLCJkZXNjcmlwdGlvbiI6IlRoZSBuYW1lIG9mIHRoZSBydW4gaW1hZ2UgdG8gdXNlIChkZWZhdWx0cyB0byBpbWFnZSBzcGVjaWZpZWQgaW4gYnVpbGRlcikuIiwiZGVmYXVsdCI6IiJ9LHsibmFtZSI6IkNBQ0hFX0lNQUdFIiwidHlwZSI6InN0cmluZyIsImRlc2NyaXB0aW9uIjoiVGhlIG5hbWUgb2YgdGhlIHBlcnNpc3RlbnQgY2FjaGUgaW1hZ2UuIiwiZGVmYXVsdCI6IiJ9LHsibmFtZSI6IlVTRVJfSUQiLCJ0eXBlIjoic3RyaW5nIiwiZGVzY3JpcHRpb24iOiJUaGUgdXNlciBJRCBvZiB0aGUgYnVpbGRlciBpbWFnZSB1c2VyLiIsImRlZmF1bHQiOiIxMDAwIn0seyJuYW1lIjoiR1JPVVBfSUQiLCJ0eXBlIjoic3RyaW5nIiwiZGVzY3JpcHRpb24iOiJUaGUgZ3JvdXAgSUQgb2YgdGhlIGJ1aWxkZXIgaW1hZ2UgdXNlci4iLCJkZWZhdWx0IjoiMTAwMCJ9XSwid29ya3NwYWNlcyI6W3sibmFtZSI6InNvdXJjZS13cyIsImRlc2NyaXB0aW9uIjoiTG9jYXRpb24gd2hlcmUgc291cmNlIGlzIHN0b3JlZC4ifSx7Im5hbWUiOiJjYWNoZS13cyIsImRlc2NyaXB0aW9uIjoiTG9jYXRpb24gd2hlcmUgY2FjaGUgaXMgc3RvcmVkIGlmIENBQ0hFX0lNQUdFIGlzIG5vdCBwcm92aWRlZC4iLCJvcHRpb25hbCI6dHJ1ZX0seyJuYW1lIjoiZ2l0LWNyZWRlbnRpYWxzIiwiZGVzY3JpcHRpb24iOiJNeSBnaXRodWIgc3NoIGNyZWRlbnRpYWxzIiwib3B0aW9uYWwiOnRydWV9LHsibmFtZSI6ImRvY2tlci1jcmVkZW50aWFscyIsImRlc2NyaXB0aW9uIjoiTXkgZG9ja2VyIGNvbmZpZyBjcmVkZW50aWFscyIsIm9wdGlvbmFsIjp0cnVlfV19LCJza2lwcGVkVGFza3MiOlt7Im5hbWUiOiJidWlsZC11bnRydXN0ZWQiLCJyZWFzb24iOiJXaGVuIEV4cHJlc3Npb25zIGV2YWx1YXRlZCB0byBmYWxzZSIsIndoZW5FeHByZXNzaW9ucyI6W3siaW5wdXQiOiJ0cnVlIiwib3BlcmF0b3IiOiJub3RpbiIsInZhbHVlcyI6WyJ0cnVlIiwieWVzIiwiVFJVRSIsIlRydWUiXX1dfV0sImNoaWxkUmVmZXJlbmNlcyI6W3siYXBpVmVyc2lvbiI6InRla3Rvbi5kZXYvdjFiZXRhMSIsImtpbmQiOiJUYXNrUnVuIiwibmFtZSI6ImJ1aWxkcGFja3MtcGlwZWxpbmVydW4tc3B2ajYtZmV0Y2gtZnJvbS1naXQiLCJwaXBlbGluZVRhc2tOYW1lIjoiZmV0Y2gtZnJvbS1naXQifSx7ImFwaVZlcnNpb24iOiJ0ZWt0b24uZGV2L3YxYmV0YTEiLCJraW5kIjoiVGFza1J1biIsIm5hbWUiOiJidWlsZHBhY2tzLXBpcGVsaW5lcnVuLXNwdmo2LWJ1aWxkLXRydXN0ZWQiLCJwaXBlbGluZVRhc2tOYW1lIjoiYnVpbGQtdHJ1c3RlZCIsIndoZW5FeHByZXNzaW9ucyI6W3siaW5wdXQiOiJ0cnVlIiwib3BlcmF0b3IiOiJpbiIsInZhbHVlcyI6WyJ0cnVlIiwieWVzIiwiVFJVRSIsIlRydWUiXX1dfV0sInByb3ZlbmFuY2UiOnt9fQ==
 chains.tekton.dev/signature-pipelinerun-7c1b8ea6-126a-4987-bada-d0f751e293cf=MEYCIQDtNNzKZaJJzcFM9aml8RTRVOSKaee+LnHgZwHzECYb1wIhAKRlwY4uctarKiK+jJmYUPqK2S4Dhsfya/Z5ZGRkck/W
 chains.tekton.dev/signed=true
 chains.tekton.dev/transparency=https://rekor.sigstore.dev/api/v1/log/entries?logIndex=24288163
 tekton.dev/categories=Image Build
 tekton.dev/displayName=Buildpacks
 tekton.dev/pipelines.minVersion=0.17.0
 tekton.dev/platforms=linux/amd64
 tekton.dev/tags=image-build

Status

STARTED         DURATION   STATUS
6 minutes ago   46s        Succeeded(Completed)

Timeouts
 Pipeline:   1h0m0s

Params

 NAME            VALUE
 BUILDER_IMAGE   docker.io/cnbs/sample-builder:bionic@sha256:6c03dd604503b59820fd15adbc65c0a077a47e31d404a3dcad190f3179e920b5
 TRUST_BUILDER   true
 APP_IMAGE       ttl.sh/tekton-test:1h
 SOURCE_URL      https://github.com/PoisWu/docker-source-code

Workspaces

 NAME        SUB PATH   WORKSPACE BINDING
 source-ws   source     PersistentVolumeClaim (claimName=buildpacks-ws-pvc-1)
 cache-ws    cache      PersistentVolumeClaim (claimName=buildpacks-ws-pvc-1)

Taskruns

 NAME                                          TASK NAME        STARTED         DURATION   STATUS
 buildpacks-pipelinerun-spvj6-build-trusted    build-trusted    6 minutes ago   25s        Succeeded
 buildpacks-pipelinerun-spvj6-fetch-from-git   fetch-from-git   6 minutes ago   21s        Succeeded

Skipped Tasks

 NAME
 build-untrusted
```

RM: The `buildpacks-pipeline` pipeline going to clone the source code from
`SOURCE_URL` with `git-clone` Task and build it with `buildpacks` Task and push
the artifact to `APP_IMAGE` . The detail of `buildpacks-pipeline` is written in
`pipeline-buildpacks.yaml` 

RM1: The provenance is the content after `=` of the line
`chains.tekton.dev/payload-pipelinerun` which is encoded in base64.

RM2: The name of `PersistentVolumeClaim` in `run-buildpacks.yaml` has to be
changed for each execution. I don't know how to makes it more convenient. 


### Verification
Verifying the signature:
```bash
$ cosign verify --key k8s://tekton-chains/signing-secrets tt l.sh/tekton-test:1h
```

```console
Verification for ttl.sh/tekton-test:1h --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - The claims were present in the transparency log
  - The signatures were integrated into the transparency log when the certificate was valid
  - The signatures were verified against the specified public key
...
```


Verifying the attestation:
```bash
$ cosign verify-attestation --key k8s://tekton-chains/signing-secrets \
--type slsaprovenance ttl.sh/tekton-test:1h
```
``` console
Verification for ttl.sh/tekton-test:1h --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - The claims were present in the transparency log
  - The signatures were integrated into the transparency log when the certificate was valid
  - The signatures were verified against the specified public key
```

The following command will show the content of provenance. 
```bash
$ cosign verify-attestation --key k8s://tekton-chains/signing-secrets \
                  --type slsaprovenance ttl.sh/tekton-test:1h | \
                  jq '.payload'   | tr -d '"' | base64 -d  | jq .
```
