using IdentityServer4.Models;
using System.Collections.Generic;
using System.Security.Claims;
using System.Text.Json;
using IdentityModel;
using IdentityServer4;
using IdentityServer4.Test;

namespace Ids
{
  public static class Config
  {
    public static List<TestUser> Users
    {
      get
      {
        var address = new
        {
          street_address = "One Hacker Way",
          locality = "Heidelberg",
          postal_code = 69118,
          country = "Germany"
        };

        return new List<TestUser>
        {
          new TestUser
          {
            SubjectId = "818727",
            Username = "alice",
            Password = "alice",
            Claims =
            {
              new Claim(JwtClaimTypes.Name, "Alice Smith"),
              new Claim(JwtClaimTypes.GivenName, "Alice"),
              new Claim(JwtClaimTypes.FamilyName, "Smith"),
              new Claim(JwtClaimTypes.Email, "AliceSmith@email.com"),
              new Claim(JwtClaimTypes.EmailVerified, "true", ClaimValueTypes.Boolean),
              new Claim(JwtClaimTypes.Role, "admin"),
              new Claim(JwtClaimTypes.WebSite, "http://alice.com"),
              new Claim(JwtClaimTypes.Address, JsonSerializer.Serialize(address),
                IdentityServerConstants.ClaimValueTypes.Json)
            }
          },
           new TestUser
          {
            SubjectId = "818755",
            Username = "sas",
            Password = "sas",
            Claims =
            {
              new Claim(JwtClaimTypes.Name, "Sas Viya"),
              new Claim(JwtClaimTypes.GivenName, "sas"),
              new Claim(JwtClaimTypes.FamilyName, "sas"),
              new Claim(JwtClaimTypes.Email, "sas@email.com"),
              new Claim(JwtClaimTypes.EmailVerified, "true", ClaimValueTypes.Boolean),
              new Claim(JwtClaimTypes.Role, "admin"),
              new Claim(JwtClaimTypes.WebSite, "http://sas.com"),
              new Claim(JwtClaimTypes.Address, JsonSerializer.Serialize(address),
                IdentityServerConstants.ClaimValueTypes.Json)
            }
          },
           new TestUser
          {
            SubjectId = "sasdemo01",
            Username = "sasdemo01",
            Password = "sasdemo01",
            Claims =
            {
              new Claim(JwtClaimTypes.Name, "sas"),
              new Claim(JwtClaimTypes.GivenName, "demo"),
              new Claim(JwtClaimTypes.FamilyName, "sasdemo01"),
              new Claim(JwtClaimTypes.Email, "sasdemo01@email.com"),
              new Claim(JwtClaimTypes.EmailVerified, "true", ClaimValueTypes.Boolean),
              new Claim(JwtClaimTypes.Role, "admin"),
              new Claim(JwtClaimTypes.WebSite, "http://sasdemo.com"),
              new Claim(JwtClaimTypes.Address, JsonSerializer.Serialize(address),
                IdentityServerConstants.ClaimValueTypes.Json)
            }
          },
          new TestUser
          {
            SubjectId = "88421113",
            Username = "bob",
            Password = "bob",
            Claims =
            {
              new Claim(JwtClaimTypes.Name, "Bob Smith"),
              new Claim(JwtClaimTypes.GivenName, "Bob"),
              new Claim(JwtClaimTypes.FamilyName, "Smith"),
              new Claim(JwtClaimTypes.Email, "BobSmith@email.com"),
              new Claim(JwtClaimTypes.EmailVerified, "true", ClaimValueTypes.Boolean),
              new Claim(JwtClaimTypes.Role, "user"),
              new Claim(JwtClaimTypes.WebSite, "http://bob.com"),
              new Claim(JwtClaimTypes.Address, JsonSerializer.Serialize(address),
                IdentityServerConstants.ClaimValueTypes.Json)
            }
          }
        };
      }
    }

    public static IEnumerable<IdentityResource> IdentityResources =>
      new []
      {
        new IdentityResources.OpenId(),
        new IdentityResources.Profile(),
        new IdentityResource
        {
          Name = "role",
          UserClaims = new List<string> {"role"}
        }
      };

    public static IEnumerable<ApiScope> ApiScopes =>
      new []
      {
        new ApiScope("weatherapi.read"),
        new ApiScope("weatherapi.write"),
      };
    public static IEnumerable<ApiResource> ApiResources => new[]
    {
      new ApiResource("weatherapi")
      {
        Scopes = new List<string> {"weatherapi.read", "weatherapi.write"},
        ApiSecrets = new List<Secret> {new Secret("ScopeSecret".Sha256())},
        UserClaims = new List<string> {"role"}
      }
    };

    public static IEnumerable<Client> Clients =>
      new[]
      {
        // m2m client credentials flow client
        new Client
        {
          ClientId = "m2m.client",
          ClientName = "Client Credentials Client",
          ClientSecrets = {new Secret("SuperSecretPassword".Sha256())},
          AllowedGrantTypes = GrantTypes.ClientCredentials,
          AllowedScopes = {"openid", "weatherapi.read", "weatherapi.write"},

        },

        // interactive client using code flow + pkce
        new Client
        {
          ClientId = "interactive",
          ClientSecrets = {new Secret("SuperSecretPassword".Sha256())},

          AllowedGrantTypes = GrantTypes.Code,
          RedirectUris = {"https://10.0.0.19/SASLogon/login/callback/external_oauth"},
          FrontChannelLogoutUri = "https://10.0.0.19/SASLogon",
          PostLogoutRedirectUris = {"https://10.0.0.19/SASLogon"},

          AllowOfflineAccess = true,
          AllowedScopes = {"openid", "profile", "weatherapi.read"},
          RequirePkce = false,
          RequireConsent = true,
          AllowPlainTextPkce = false
        },
      };
  }
}