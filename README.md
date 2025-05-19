# IAP Terraform Sample for Cloud Run

This sample deploys a [Cloud Run](https://cloud.run/) service with VPC
[ingress controls] that only allows traffic from Cloud HTTPS load balancer that
has [IAP (Identity Aware Proxy)][iap] enabled.

[iap]: https://cloud.google.com/iap
[ingress controls]: https://cloud.google.com/run/docs/securing/ingress

IAP authenticates users with a Google account (or other external IdP) and
checks if the user is allowed to access the deployed service.

## Prerequisites
You must have a domain name registered, for which you can modify certain DNS settings. You can use a subdomain as well.

## Deploy

### Create a project
Create a new project, if you don't want to re-use an existing project. For example:
```sh
gcloud projects create cloud-run-iap-terraform-demo-1 --name="IAP Cloud Run Demo" --set-as-default
```

If this project isn't set as your current default project, use:
```sh
gcloud config set project cloud-run-iap-terraform-demo-1
```

### Enable billing
Enable billing, if you haven't done this yet, for the project. First get your billing account ID:
```sh
gcloud beta billing accounts list
```

This returns something like:
```sh
ACCOUNT_ID            NAME                OPEN  MASTER_ACCOUNT_ID
0X0X0X-0X0X0X-0X0X0X  My Billing Account  True
```

Now enable billing for your new project:
```sh
gcloud beta billing projects link cloud-run-iap-terraform-demo-1 --billing-account 0X0X0X-0X0X0X-0X0X0X
```

### Create an OAuth2 web application
Create OAuth2 web application (and note its client_id and client_secret)
from https://console.cloud.google.com/apis/credentials.

If it asks you to Configure a consent screen first, then do so:
- Choose 'External' for *User Type*
- Fill in 'App name', e.g. `IAP Cloud Run Demo`
- Select your email address from the dropdown, for 'User support email'
- You can leave the 'App domain' section blank
- Fill in your email address at the 'Developer contact information'
- Click on 'save and continue' on the next screens and then the 'Credentials' menu link in the left menu bar

### Execute Terraform
First initialize the Terraform:

```sh
terraform init
```

Create a tfvars file
```
cat > iap.auto.tfvars << EOF

project_id        = "<GCP_PROJECT_ID>"
region            = "<GCP_REGION>"
domain            = "<IAP_DOMAIN>"
app_name          = "<APP_name>"
iap_client_id     = "<IAP_CLIENT_ID>"
iap_client_secret = "<IAP_CLIENT_SECRET>"
iap_group         = "<IAP_CLIENT_SECRET>"

EOF

```

(Optional) preview what resources will be created:
```sh
terraform plan
```

Deploy using Terraform, this will take several minutes to complete:

```sh
terraform apply -auto-approve
```

Grants the IAP service account the ability to **run a specific Cloud Run service**
```sh
gcloud run services add-iam-policy-binding <APP_NAME> \
--member='serviceAccount:service-<PROJECT_NUMBER>@gcp-sa-iap.iam.gserviceaccount.com'  \
--role='roles/run.invoker'  \
--region=<GCP_REGION>
```

(Optional) Grants the IAP service account the ability to **run all Cloud Run services in a specific project**
```sh
gcloud projects add-iam-policy-binding <PROJECT_ID> \
--member='serviceAccount:service-<PROJECT_NUMBER>@gcp-sa-iap.iam.gserviceaccount.com'  \
--role='roles/run.invoker'
```

In this command fill in:
- project-id: the project id, e.g. `cloud-run-iap-terraform-demo-1`
- region: the region, this is optional, will default to `us-central1`
- domain: the domain name you want to use, e.g. `corpapp.ahmet.dev`
- app_name: name for the load balancer, this is optional, will default to `iap-lb`
- iap_client_id: the client id for the oAuth client you created earlier
- iap_client_secret: the client secret for the oAuth client you created earlier. You can view it by editing the oAuth client.

#### Troubleshooting errors
Note: if you get an error saying `Output refers to sensitive values`, add `sensitive = true` to `backend_services`
in `.terraform/modules/lb-http/modules/serverless_negs/outputs.tf`.

If you get an error like `Error: Error creating Connector: googleapi: Error 403: The caller does not have permission`,
it means the account which is used to execute the terraform, does not have enough permissions. You can fix this by running:
```sh
gcloud auth application-default login
```

If that still doesn't solve the issue, you can view the service account of your project in the GCP console under
`IAM & Admin` -> 'Service Accounts' named e.g. `Default compute service account`. From there you can troubleshoot which
permissions might be missing.

### Post-deployment steps
After the deployment is complete:

1. Configure DNS records of the used domain name with the given IP address. In other words, add a record named `www` or
   your subdomain name, of type `A` pointing to your ipv4 IP address, which was the output of your terraform command.
   **It will take 10-30 minutes until the load balancer starts functioning.**
1. Go back to Credentials page and add a the `oauth2_redirect_uri` output to the
   Authorized Redirect URIs of the web application you created here.

Now, you should be able to authenticate to your web application based on
the users/group specified in [`main.tf`](./main.tf) by visiting your domain.

## Cleanup

:warning: Do not lose the `.tfstate` file created in this directory.

Run the previous `terraform apply` command as `terraform destroy` to clean up
the created resources.

## Infrastructure
The following diagram shows the infrastructure created.
![diagram](./diagrams/Infrastructure.png)

### Cloud Run Service
The [Cloud Run Service][cloud run] is a compute service which actually runs your website.
In this example a simple hello world Docker container.

### Serverless Network Endpoint Group
The [Serverless Network Endpoint Group][serverless neg] is the connection between your Load Balancer and your
Cloud Run service. It allows requests to the load balancer, to be routed to the serverless app backend.

### HTTP/S Load Balancer
The [HTTP/S Load Balancer][load balancer] listens to incoming traffic on an IP address and directs this to a backend
service. A [terraform module][tf lb] is used which creates several resources, such as:
- Global Address
- HTTP Proxy
- Forwarding rules
- Managed SSL certificate
- Serverless NEG as backend

In this case the load balancer doesn't act traditionally, where the load is balanced between a group of backend
services, rather, all load is forwarded to the configured backend.

### IAM Policy
The [IAM Policy][iam policy] defines which members will be granted the role `iap.httpsResourceAccessor`. With it, you
manage who will have access to your website and who doesn't.

### IAM Policy for Identity-Aware Proxy WebBackendService
The [IAM Policy for Identity-Aware Proxy WebBackendService][iap] configures the [Identity-Aware Proxy][iap], and binds the
IAM Policy you defined to the Load Balancer. From here you can select the HTTPS resource, click on the info panel and
add or remove members from the `IAP-secured Web App User` role.

[serverless vpc access]: https://console.cloud.google.com/networking/connectors
[cloud run]: https://console.cloud.google.com/run
[serverless neg]: https://console.cloud.google.com/compute/networkendpointgroups/list
[load balancer]: https://console.cloud.google.com/net-services/loadbalancing/loadBalancers/list
[tf lb]: https://github.com/terraform-google-modules/terraform-google-lb-http
[iam policy]: https://console.cloud.google.com/iam-admin/roles/details/roles%3Ciap.httpsResourceAccessor
[iap]: https://console.cloud.google.com/security/iap

## External resources
- [Cloud OnAir video](https://www.youtube.com/watch?v=68LmhtvSNZY)

------

This is not an official tutorial and can go out of date. Please read the
documentation for more up-to-date info.
