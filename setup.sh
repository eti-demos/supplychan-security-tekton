#! /bin/sh 

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function console_log (){
    echo  "${GREEN}===$1====${NC}"
}

function create_k8s_cluster(){ 
    # arg: str, name of the k8s cluster
    kind create cluster --config ./kind/kind_basic_config.yaml --name $1
}

function install_istio(){
    console_log "install istioctl"
    curl -sL https://istio.io/downloadIstioctl | sh -
    export PATH=$HOME/.istioctl/bin:$PATH
    console_log "install istio service mesh"
    istioctl install --set profile=demo
}

function wait_pod_ns(){
    # arg: str, in which namepace that waiting for pod
    kubectl wait pod --all --for=condition=Ready --namespace=$1
}

function newline(){
    echo ""
}

# create_k8s_cluster "tekton"

# Deploying Tekton Pipeline
console_log "Deploying latest version of Tekton Pipeline"
kubectl apply --filename https://storage.googleapis.com/tekton-releases/pipeline/latest/release.yaml
console_log "Waiting Pods ready in tekton-pipelines namespace"
wait_pod_ns "tekton-pipelines"
newline

# Deploying Tekton Chain
console_log "Deploying latest version of Tekton chain"
kubectl apply --filename https://storage.googleapis.com/tekton-releases/chains/latest/release.yaml
console_log "Waiting Pods ready in tekton-chains namespace"
wait_pod_ns "tekton-chains"
newline

# Patch configuration of Tekton chain
# config doc https://github.com/tektoncd/chains/blob/main/docs/config.md
console_log "Patch configuration of Tekton chain"
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"artifacts.taskrun.format": "in-toto"}}'
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"artifacts.taskrun.storage": "oci, tekton"}}'
newline

# Deploying  CI/CD pipeline - Buildpacks
console_log "Deploying  CI/CD pipeline - Buildpacks"
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/git-clone/0.9/raw
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/buildpacks/0.6/raw
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/buildpacks-phases/0.2/raw
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/pipeline/buildpacks/0.2/raw
newline


# Deploying Tekton Dashboard
console_log "Deploying Tekton dashboard"
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
console_log "Waiting Pods ready for Tekton dashboard"
wait_pod_ns "tekton-pipelines"
newline

# Installing cosign command
# TODO install different version based on the OS
# https://docs.sigstore.dev/system_config/installation/
console_log "Installing cosign command"
brew install cosign
newline

# Create siging key with `cosign`
console_log "Creating a singing key with 'cosign'"
cosign generate-key-pair k8s://tekton-chains/signing-secrets
newline


# The final info words
console_log "[INFO]"
echo "The signing key is store as a secret object ${GREEN}'signing-secrets'${NC} in namespace tekton chains in k8s cluster"
echo "The related public is written to local file called ${GREEN}'cosign.pub'${NC}"
newline
echo "The deploymenet is finished, you can now access to the dashboard of Tekton after exposing the tekton daseboard endpoint via the follong command"
newline
echo "\t kubectl port-forward -n tekton-pipelines service/tekton-dashboard 9097:9097"
newline


