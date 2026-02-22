# Simple script to keep DNS up to date as cloud IPs change. 

k3s variant of dynDNS, for use on a local cluster

# Installation instructions

1. Rename conf.example -> conf
2. Update variables in conf with your desired DNS record and cloud project & zone parameters
3. Update crontab -e with 
0,15,30,60 * * * * /install/path/dynDNS.sh

# Default gCloud prep

## 1 Create service account
```
# Set project
GC_PROJECT_ID="PROJECTNAME"
gcloud config set project "$GC_PROJECT_ID"
# Verify current project
gcloud config get-value project

# Create dyndns service account
GC_SA_NAME="dyndns-sa"
gcloud iam service-accounts create "$GC_SA_NAME" \
  --display-name="DynDNS Service Account"

# This should create a service account like: dyndns-sa@project_id.iam.gserviceaccount.com
GC_SA_EMAIL="$GC_SA_NAME@$GC_PROJECT_ID.iam.gserviceaccount.com"

# Grant DNS Role to Service Account
gcloud projects add-iam-policy-binding "$GC_PROJECT_ID" \
  --member="serviceAccount:$GC_SA_EMAIL" \
  --role="roles/dns.editor"

# You *could* set roles/dns.admin, but *yikes*
```

## 2 Store as secret in the kube
```
# Generate key
GC_KEY_FILE="./dyndns-key.json"
gcloud iam service-accounts keys create "$GC_KEY_FILE" \
  --iam-account="$GC_SA_EMAIL"

## Store secret in kubernetes
kubectl create secret generic gcp-dns-key \
  --from-file=key.json="$GC_KEY_FILE"
```


# AWS prep

## 1 Create service account
```
# Verify account & region
aws sts get-caller-identity && aws configure get region
# Verify if needed: aws configure set default.region us-east-1
# Test you can talk to r53: aws route53 list-hosted-zones

# Set default output (option, but I had to)
aws configure set default.output json

# Set AWS environment variables
export AWS_ACCESS_KEY_ID="AKIAEXAMPLE"
export AWS_SECRET_ACCESS_KEY="EXAMPLESECRET"
export AWS_DEFAULT_REGION="us-west-1"

# Create AIM user
AWS_USER_NAME="dynDNS-user"
aws iam create-user --user-name "$AWS_USER_NAME"
```

## 2 Store as secret in the kube
```
kubectl create secret generic aws-route53-creds \
  --from-literal=AWS_ACCESS_KEY_ID=YOUR_KEY \
  --from-literal=AWS_SECRET_ACCESS_KEY=YOUR_SECRET \
  --from-literal=AWS_DEFAULT_REGION=us-east-1
```
