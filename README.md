# Cloudflare Dynamic DNS Manager (cfddns)



`cfddns` is a lightweight, pure Bash script designed to automatically update your A/AAAA records on Cloudflare whenever your server's public IP address changes. It runs as a Cron job on your Linux server (Ubuntu/Debian) and uses the Cloudflare API to ensure your domain always points to the correct IP.

---

## ✨ Features

* **Pure Bash:** No heavy dependencies beyond `curl`, `jq`, and standard Linux utilities.
* **Interactive Menu (CLI):** Easy configuration, manual checks, and settings management via a simple command-line interface.
* **Self-Update:** Includes an option to check for and apply the latest script version directly from GitHub.
* **Proxy Management:** Allows explicit setting or keeping the current **Cloudflare Proxy Status** (Orange/Gray Cloud).
* **Cron Job Integration:** Automatically schedules the update check at a user-defined interval (default: 5 minutes).
* **Secure:** Uses modern Cloudflare **API Tokens** for authentication.
* **Clean Logging:** Logs all updates and errors to `/var/log/cfddns.log`.

---

## 🚀 Installation

The installation is quick and automated.

1.  **Run the installation command:**

    ```bash
    curl -sL https://raw.githubusercontent.com/nimabbz/cfddns/main/install.sh | sudo bash
    ```

    *This script will automatically install necessary dependencies (`jq`, `dos2unix`) and place the main script files in `/usr/local/bin` and configuration files in `/etc/cfddns`.*

2.  **Start Configuration:** After the installation finishes, you must run the following command to enter your Cloudflare details:

    ```bash
    cfddns
    ```

---

## ⚙️ Usage & Configuration

Once installed, use the main command to manage the application.

### Main Menu (`cfddns`)

Run `cfddns` without any arguments to access the interactive menu:

| Option | Description |
| :---: | :--- |
| **1** | **Run Check Manually (Test):** Immediately runs the IP check script. Useful for testing settings. |
| **2** | **View Log File:** Displays the last 20 lines of `/var/log/cfddns.log`. |
| **3** | **Change Settings:** Enter the configuration menu to update API details, IDs, interval, and **Proxy Status**. |
| **4** | **Check/Run Update (From GitHub):** Checks for a new script version and automatically downloads and replaces local files. |
| **5** | **Uninstall Script:** Permanently removes all files, config, and the Cron job. |
| **6** | **Exit:** Closes the interactive menu. |

### Configuration Menu (Option 3)

The configuration menu now includes a crucial option to manage the Cloudflare Proxy status.

| Setting | Description |
| :---: | :--- |
| **1-7** | Standard API Keys, IDs, Domain Name, and Cron Toggle. |
| **8** | **Set Proxy Status:** Set to `true` (Orange Cloud), `false` (Gray Cloud), or `keep` (to preserve the existing Cloudflare setting). |

---

## 🔑 How to Find Your Cloudflare Configuration IDs

To successfully configure `cfddns`, you need specific keys and IDs from your Cloudflare account. Here is exactly where to find them:

**1. CF Email**
This is simply the email address you use to log into your Cloudflare account.

**2. CF API Key / Token**
* Go to the Cloudflare Dashboard and click on the **My Profile** icon (top right) -> **API Tokens**.
* Click **Create Token** -> **Create Custom Token**.
* Assign the permission: **Zone** > **DNS** > **Edit**.
* Generate and copy the token. 

**3. CF Zone ID**
* Go to the Cloudflare Dashboard and click on your specific domain.
* On the main **Overview** page, scroll down.
* Look at the right sidebar under the **API** section. You will see your **Zone ID**.
* Click **Click to copy**. 
> **⚠️ Important:** The Zone ID is exactly **32 characters** long. Make sure no extra spaces or words are copied.

**4. CF Record ID**
Cloudflare does not display the Record ID in the web dashboard. To find it, you must use the Cloudflare API. 
* First, ensure you have manually created the A or AAAA record (e.g., `ddns.yourdomain.com`) in the Cloudflare DNS tab.
* Next, run this command in your Linux terminal. Replace `YOUR_ZONE_ID`, `YOUR_DOMAIN_NAME`, and `YOUR_API_TOKEN` with your actual details:

```bash
curl -s -X GET "[https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records?name=YOUR_DOMAIN_NAME](https://api.cloudflare.com/client/v4/zones/YOUR_ZONE_ID/dns_records?name=YOUR_DOMAIN_NAME)" \
     -H "Authorization: Bearer YOUR_API_TOKEN" \
     -H "Content-Type: application/json" | grep -o '"id":"[^"]*"' | head -n 1

     The output will look something like this: "id":"1234567.....abcde"
     Copy the 32-character string inside the quotes. That is your Record ID!
## 📝 Troubleshooting & Logging
The script logs all successful updates, IP change detections, and API errors to:
`/var/log/cfddns.log`

If the script fails to update, check this log file first for common API errors:

| Cloudflare Error Code | Description | Solution |
| :---: | :---: | :--- |
| **10001** | **Authentication Failed.** The API Key/Token is invalid, revoked, or lacks the necessary permissions (Zone:DNS:Edit). | Solution: Create a new API Token in the Cloudflare dashboard with the correct Zone:DNS:Edit permissions and update Option 2 in the settings menu. |
| **7003** | **Invalid Object Identifier.** The API request could not be routed, usually because the Zone ID or Record ID is incorrect or mistyped in the configuration. | Double-check Option 3 (Zone ID) and Option 4 (Record ID) against your Cloudflare dashboard and ensure they are correct. |


## 🗑️ Uninstallation

To completely remove the script and all associated files (including the Cron job and configuration), select **Option 5** from the main menu or run:

```bash
cfddns
# Select 5


