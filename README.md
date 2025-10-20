# Cloudflare Dynamic DNS Manager (cfddns)



`cfddns` is a lightweight, pure Bash script designed to automatically update your A/AAAA records on Cloudflare whenever your server's public IP address changes. It runs as a Cron job on your Linux server (Ubuntu/Debian) and uses the Cloudflare API to ensure your domain always points to the correct IP.

---

## ✨ Features

* **Pure Bash:** No heavy dependencies beyond `curl`, `jq`, and standard Linux utilities.
* **Interactive Menu (CLI):** Easy configuration, manual checks, and settings management via a simple command-line interface.
* **Cron Job Integration:** Automatically schedules the update check at a user-defined interval (default: 5 minutes).
* **Secure:** Uses modern Cloudflare API Tokens for authentication.
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
| **3** | **Change Settings:** Enter the configuration menu to update API details, IDs, and the update interval. |
| **4** | **Uninstall Script:** Permanently removes all files, config, and the Cron job. |
| **5** | **Exit:** Closes the interactive menu. |

### Configuration (Option 3)

You need to provide the following essential Cloudflare information in the settings menu:

1.  **CF Email** (Your Cloudflare Account Email)
2.  **CF API Key/Token** (A **Token** with `Zone:DNS:Edit` permission is highly recommended).
3.  **CF Zone ID** (The unique ID for your domain/zone).
4.  **CF Record ID** (The unique ID for the specific A or AAAA record you want to update, e.g., `ddns.example.com`).
5.  **CF Record Name** (The full domain/subdomain, e.g., `ddns.example.com`).

---

## 📝 Troubleshooting & Logging
The script logs all successful updates, IP change detections, and API errors to:
`/var/log/cfddns.log`

If the script fails to update, check this log file first for common API errors:

| Cloudflare Error Code | Description | Solution |
| :---: | :---: | :--- |
| **10001** | **Authentication Failed.** The API Key/Token is invalid, revoked, or lacks the necessary permissions (Zone:DNS:Edit). | Solution: Create a new API Token in the Cloudflare dashboard with the correct Zone:DNS:Edit permissions and update Option 2 in the settings menu. |
| **7003** | **Invalid Object Identifier.** The API request could not be routed, usually because the Zone ID or Record ID is incorrect or mistyped in the configuration. | Double-check Option 3 (Zone ID) and Option 4 (Record ID) against your Cloudflare dashboard and ensure they are correct. |


## 🗑️ Uninstallation

To completely remove the script and all associated files (including the Cron job and configuration), select **Option 4** from the main menu or run:

```bash
cfddns
# Select 4


