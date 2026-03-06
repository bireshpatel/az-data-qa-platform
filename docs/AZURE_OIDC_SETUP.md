# Azure OIDC Setup & Troubleshooting

This guide helps you fix the error:

```text
AADSTS70025: The client '***'(gh-actions-data-qa) has no configured federated identity credentials.
```

It means the Azure AD app registration used by GitHub Actions has **no federated identity credential**. You need to add one so Azure trusts the OIDC token from GitHub.

---

## Step 1: Open the app registration

1. Sign in to [Azure Portal](https://portal.azure.com).
2. Search for **Microsoft Entra ID** (or **Azure Active Directory**) and open it.
3. Go to **Applications** → **App registrations**.
4. Find and open the app **gh-actions-data-qa** (the one whose **Application (client) ID** is in your `AZURE_CLIENT_ID` secret).

---

## Step 2: Add a federated credential

1. In the app’s left menu, select **Certificates & secrets**.
2. Open the **Federated credentials** tab.
3. Click **Add credential**.

---

## Step 3: Choose “GitHub Actions deploying Azure resources”

1. **Federated credential scenario**: select **GitHub Actions deploying Azure resources**.
2. Fill in the fields as below (use your actual org/repo if different).

| Field | Value |
|-------|--------|
| **Organization** | `bireshpatel` |
| **Repository** | `az-data-qa-platform` |
| **Entity type** | **Branch** |
| **GitHub branch name** | `main` |
| **Name** | e.g. `main-branch` (any friendly name) |

3. Click **Add**.

If your workflow uses a **GitHub Environment** instead of branch, choose **Entity type: Environment** and enter the environment name.

---

## Step 4: Match the subject claim (alternative / advanced)

Your error showed the exact token claims. If the template above doesn’t match, add a **custom** federated credential and set:

| Field | Value |
|-------|--------|
| **Issuer** | `https://token.actions.githubusercontent.com` |
| **Subject** | `repo:bireshpatel/az-data-qa-platform:ref:refs/heads/main` |
| **Audience** | `api://AzureADTokenExchange` |
| **Name** | e.g. `main-branch-custom` |

- **Subject** must match what GitHub sends. For branch: `repo:<org>/<repo>:ref:refs/heads/<branch>`.
- For a specific workflow file you can use:  
  `repo:bireshpatel/az-data-qa-platform:job_workflow_ref:bireshpatel/az-data-qa-platform/.github/workflows/deploy.yml@refs/heads/main`

---

## Step 5: Confirm required permissions

The app needs permission to deploy resources in your subscription:

1. In the app registration, go to **API permissions**.
2. Ensure you have at least:
   - **Microsoft Graph** → **Application permissions** → **User.Read** (if required by Azure CLI), and
   - **Azure Service Management** or the specific RBAC roles needed for Terraform (e.g. **Contributor** on the subscription or resource group).
3. In **Subscriptions** → your subscription → **Access control (IAM)**:
   - Add role assignment: **Contributor** (or a custom role) for the app **gh-actions-data-qa** (service principal).

---

## Step 6: Check GitHub secrets

In the repo: **Settings** → **Secrets and variables** → **Actions**:

| Secret | Description |
|--------|-------------|
| `AZURE_CLIENT_ID` | Application (client) ID of **gh-actions-data-qa** |
| `AZURE_TENANT_ID` | Directory (tenant) ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription ID where you deploy |

Optional for Terraform remote state:

- `TF_STATE_RG`, `TF_STATE_SA`, `TF_STATE_CONTAINER`, `TF_STATE_KEY`

---

## Step 7: Re-run the workflow

1. Commit and push any changes (or use **Actions** → select the workflow → **Re-run all jobs**).
2. The **Azure Login (OIDC)** step should succeed once the federated credential is in place and matches the token’s **subject** and **issuer**.

---

## Quick checklist

- [ ] Federated credential added under **App registration** → **Certificates & secrets** → **Federated credentials**.
- [ ] Subject matches: `repo:bireshpatel/az-data-qa-platform:ref:refs/heads/main` (or your branch).
- [ ] Issuer: `https://token.actions.githubusercontent.com`, Audience: `api://AzureADTokenExchange`.
- [ ] Service principal has **Contributor** (or needed role) on the subscription/resource group.
- [ ] GitHub secrets `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` are set and correct.

---

## Using Azure CLI instead of the portal

```bash
# Replace with your app (client) ID, tenant ID, and resource group for the app registration
APP_ID="<your-application-client-id>"
TENANT_ID="<your-tenant-id>"
RESOURCE_GROUP="<resource-group-containing-the-app>"  # or use --subscription

az ad app federated-credential create \
  --id "$APP_ID" \
  --parameters '{
    "name": "github-actions-main",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:bireshpatel/az-data-qa-platform:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"],
    "description": "Federated credential for GitHub Actions main branch"
  }'
```

After adding the federated credential, re-run the workflow; the `AADSTS70025` error should be resolved.
