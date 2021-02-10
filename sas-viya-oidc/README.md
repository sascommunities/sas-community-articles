# sas-viya-oidc

## IdentityServer4 sample code

After executing the IdS.csproj in Visual Studio, it's going to create an identity server 4 for you. Be aware Visual Studio is going to ask to you install some libraries before executing the code. Just accept all and execute with IIS Express using port 44397 (or any port you want) by editing properties/launchSettings.json on line 7 and 8.

In case you need to generate your own certificate (beyond localhost, default on IIS Express), you can generate your self signed certificate to IIS Express using power shell (just change "localhost" to the name you want to inside the code):
https://gist.github.com/camieleggermont/5b2971a96e80a658863106b21c479988

After creating the self-signed .pfx certificate in Windows, export the file to your desktop following [these instructions](https://support.globalsign.com/ssl/ssl-certificates-installation/import-and-export-certificate-microsoft-windows). 

Next, you need to convert the certificate to configure CAS TLS to use our custom certificate. I used the following commands from my Linux server:
- openssl pkcs12 -in sefaz.pfx -nocerts -out certname.pem -nodes
- openssl pkcs12 -in sefaz.pfx -nokeys -out certname.crt -nodes
- openssl pkcs12 -in /home/azureuser/sefaz.pfx -nocerts -out /home/azureuser/certname.key


This code wasn't written by me, only changed and configured to work with SAS Viya. If you want to see the source, follow [this link](https://github.com/kevinrjones/SettingUpIdentityServer).

