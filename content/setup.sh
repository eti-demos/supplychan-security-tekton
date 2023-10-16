#! /bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

function console_log (){
    echo -e "${GREEN}===$1====${NC}"
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
console_log "Patch configuration of Tekton chain"
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"artifacts.taskrun.format": "in-toto"}}'
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"artifacts.taskrun.storage": "oci, tekton"}}'
kubectl patch configmap chains-config -n tekton-chains -p='{"data":{"transparency.enabled": "true"}}'
newline

# Deploying  CI/CD pipeline - Buildpacks
console_log "Deploying  CI/CD pipeline - Buildpacks"
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/git-clone/0.9/raw
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/buildpacks/0.5/raw
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/task/buildpacks-phases/0.2/raw
kubectl apply -f https://api.hub.tekton.dev/v1/resource/tekton/pipeline/buildpacks/0.2/raw
newline


# Deploying Tekton Dashboard
console_log "Deploying Tekton dashboard"
kubectl apply --filename https://storage.googleapis.com/tekton-releases/dashboard/latest/release.yaml
console_log "Waiting Pods ready for Tekton dashboard"
wait_pod_ns "tekton-pipelines"
newline

# Installing cosign, crane command
console_log "Installing cosign command"
if [[ $(uname) == "Darwin" ]]; then
    brew install cosign
elif [[ $(uname) == "Linux" ]]; then
    curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
    sudo mv cosign-linux-amd64 /usr/local/bin/cosign
    sudo chmod +x /usr/local/bin/cosign
fi
newline

# Install crane
console_log "Installing crane command"
if [[ $(uname) == "Darwin" ]]; then
    brew install crane
elif [[ $(uname) == "Linux" ]]; then
    curl -OL "https://github.com/google/go-containerregistry/releases/download/v0.16.1/go-containerregistry_Linux_arm64.tar.gz" 
    sudo tar -zxvf go-containerregistry_Linux_arm64.tar.gz -C /usr/local/bin/ crane
fi
newline

# Install tkn
console_log "Installing tkn command"
if [[ $(uname) == "Darwin" ]]; then
    brew install tektoncd-cli
elif [[ $(uname) == "Linux" ]]; then
    curl -LO https://github.com/tektoncd/cli/releases/download/v0.32.0/tektoncd-cli-0.32.0_Linux-64bit.deb
    sudo dpkg -i ./tektoncd-cli-0.32.0_Linux-64bit.deb
fi
newline

# Create siging key with `cosign`
console_log "Creating a singing key with 'cosign'"
cosign generate-key-pair k8s://tekton-chains/signing-secrets
newline


# The final info words
console_log "[INFO]"
echo -e "The signing key is store as a secret object ${GREEN}'signing-secrets'${NC} in namespace tekton chains in k8s cluster"
echo -e "The related public is written to local file called ${GREEN}'cosign.pub'${NC}"
newline
echo "The deploymenet is finished, you can now access to the dashboard of Tekton after exposing the tekton daseboard endpoint via the follong command"
newline
echo -e "\t kubectl port-forward -n tekton-pipelines service/tekton-dashboard 9097:9097"
newline
