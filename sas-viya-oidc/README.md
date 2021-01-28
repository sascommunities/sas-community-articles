# viyaoidc

Identity server 4 sample code

After executing the IdS.csproj in Visual Studio, it's going to create an identity server 4 for you. Be aware Visual Studio is going to ask to you install some libraries before executing the code. Just accept all and execute with IIS Express using port 44397 (or any port you want) by editing properties/launchSettings.json on line 6 and 7.

In case you need to generate your own certificate (beyond localhost, default on IIS Express), you can generate your self signed certificate to IIS Express using power shell (just change "localhost" to the name you want to inside the code):
https://gist.github.com/camieleggermont/5b2971a96e80a658863106b21c479988

After created and exported your self-signed .pfx certificate from windows (for IIS Express), you can convert them if needed to configure CAS TLS to use our custom certificate using this command:
- openssl pkcs12 -in sefaz.pfx -nocerts -out certnamedois.pem -nodes
- openssl pkcs12 -in sefaz.pfx -nokeys -out certnamedois.crt -nodes
- openssl pkcs12 -in /home/azureuser/sefaz.pfx -nocerts -out /home/azureuser/certname.key


This code wasn't written by me, only changed and configured to work with sas viya. If you want to see the source, it's here:
https://github.com/kevinrjones/SettingUpIdentityServer

